-- Rebuild schema for Hostel Management System (Supabase/Postgres)
-- WARNING: This migration DROPS existing objects in public schema (except auth.*)
-- Apply on a fresh database or with caution.

begin;

-- Drop dependent views first
drop view if exists public.students cascade;

-- Drop tables (order matters due to FKs)
drop table if exists public.attendance_records cascade;
drop table if exists public.attendance_sessions cascade;
drop table if exists public.payments cascade;
drop table if exists public.fees cascade;
drop table if exists public.room_allocations cascade;
drop table if exists public.visitors cascade;
drop table if exists public.maintenance_requests cascade;
drop table if exists public.notices cascade;
drop table if exists public.rooms cascade;
drop table if exists public.profiles cascade;

-- Drop helper functions if they already exist
drop function if exists public.get_or_create_session(date, text) cascade;
drop function if exists public.update_room_occupancy(uuid) cascade;
drop function if exists public.get_unallocated_students() cascade;
drop function if exists public.allocate_room(uuid, uuid, date) cascade;
drop function if exists public.universal_search(text) cascade;
drop function if exists public.is_admin_or_staff() cascade;

-- Enum types
do $$
begin
	if not exists (select 1 from pg_type where typname = 'role_type') then
		create type public.role_type as enum ('Admin','Staff','Student');
	end if;
	if not exists (select 1 from pg_type where typname = 'attendance_session_type') then
		create type public.attendance_session_type as enum ('Morning','Evening');
	end if;
	if not exists (select 1 from pg_type where typname = 'attendance_status') then
		create type public.attendance_status as enum ('Present','Absent','Leave','Holiday');
	end if;
	if not exists (select 1 from pg_type where typname = 'notice_audience') then
		create type public.notice_audience as enum ('all','students','staff','admins');
	end if;
	if not exists (select 1 from pg_type where typname = 'room_status') then
		create type public.room_status as enum ('Available','Occupied','Maintenance');
	end if;
	if not exists (select 1 from pg_type where typname = 'fee_status') then
		create type public.fee_status as enum ('Due','Paid','Overdue');
	end if;
	if not exists (select 1 from pg_type where typname = 'visitor_status') then
		create type public.visitor_status as enum ('In','Out');
	end if;
	if not exists (select 1 from pg_type where typname = 'maintenance_status') then
		create type public.maintenance_status as enum ('Pending','In Progress','Resolved');
	end if;
end $$;

-- Profiles: 1:1 with auth.users
create table public.profiles (
	id uuid primary key references auth.users(id) on delete cascade,
	full_name text not null,
	email text not null,
	role public.role_type not null default 'Student',
	mobile_number text,
	course text,
	joining_date date,
	avatar_url text,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

create index on public.profiles (role);
create unique index if not exists profiles_email_unique on public.profiles (email);

-- Rooms
create table public.rooms (
	id uuid primary key default gen_random_uuid(),
	room_number text not null unique,
	type text, -- e.g., Single/Double
	capacity integer not null default 1 check (capacity > 0),
	status public.room_status not null default 'Available',
	occupants integer not null default 0,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

-- Notices
create table public.notices (
	id uuid primary key default gen_random_uuid(),
	title text not null,
	message text not null,
	audience public.notice_audience not null default 'all',
	created_at timestamptz not null default now(),
	created_by uuid not null references public.profiles(id) on delete set null
);

-- Maintenance Requests
create table public.maintenance_requests (
	id uuid primary key default gen_random_uuid(),
	title text not null,
	description text,
	status public.maintenance_status not null default 'Pending',
	reported_by_id uuid not null references public.profiles(id) on delete set null,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

-- Room Allocations
create table public.room_allocations (
	id uuid primary key default gen_random_uuid(),
	student_id uuid not null references public.profiles(id) on delete cascade,
	room_id uuid not null references public.rooms(id) on delete cascade,
	start_date date not null default now(),
	end_date date,
	is_active boolean not null default true,
	created_at timestamptz not null default now()
);

create index on public.room_allocations (student_id);
create index on public.room_allocations (room_id);
create unique index room_allocations_one_active_per_student
	on public.room_allocations (student_id)
	where is_active is true and end_date is null;

-- Fees
create table public.fees (
	id uuid primary key default gen_random_uuid(),
	student_id uuid not null references public.profiles(id) on delete cascade,
	amount numeric(12,2) not null check (amount >= 0),
	due_date date not null,
	status public.fee_status not null default 'Due',
	payment_date timestamptz,
	description text,
	created_at timestamptz not null default now()
);

create index on public.fees (student_id);
create index on public.fees (status);
create index on public.fees (due_date);

-- Payments
create table public.payments (
	id uuid primary key default gen_random_uuid(),
	fee_id uuid not null references public.fees(id) on delete cascade,
	amount numeric(12,2) not null check (amount >= 0),
	paid_on timestamptz not null default now(),
	method text,
	reference text
);

create index on public.payments (fee_id);
create index on public.payments (paid_on desc);

-- Attendance
create table public.attendance_sessions (
	id uuid primary key default gen_random_uuid(),
	date date not null,
	session_type public.attendance_session_type not null,
	created_at timestamptz not null default now(),
	constraint attendance_sessions_unique unique (date, session_type)
);

create table public.attendance_records (
	id uuid primary key default gen_random_uuid(),
	session_id uuid not null references public.attendance_sessions(id) on delete cascade,
	student_id uuid not null references public.profiles(id) on delete cascade,
	status public.attendance_status not null default 'Present',
	created_at timestamptz not null default now(),
	constraint attendance_records_unique unique (session_id, student_id)
);

create index on public.attendance_records (student_id);
create index on public.attendance_records (session_id);

-- Visitors
create table public.visitors (
	id uuid primary key default gen_random_uuid(),
	visitor_name text not null,
	student_id uuid not null references public.profiles(id) on delete cascade,
	check_in_time timestamptz not null default now(),
	check_out_time timestamptz,
	status public.visitor_status not null default 'In'
);

create index on public.visitors (student_id);
create index on public.visitors (status);

-- View: students (compat layer mapping to profiles with role = 'Student')
create or replace view public.students as
	select
		p.id,
		p.full_name,
		p.email,
		coalesce(p.course, '') as course,
		p.mobile_number as contact,
		p.created_at
	from public.profiles p
	where p.role = 'Student';

-- Helper: determine admin/staff via profiles
create or replace function public.is_admin_or_staff()
returns boolean
language sql
stable
security definer
as $$
	select exists (
		select 1
		from public.profiles pr
		where pr.id = auth.uid() and pr.role in ('Admin','Staff')
	);
$$;

-- RPC: get_or_create_session(date, session_type)
create or replace function public.get_or_create_session(p_date date, p_session_type text)
returns uuid
language plpgsql
as $$
declare
	_session_id uuid;
	_session_type public.attendance_session_type;
begin
	_session_type := p_session_type::public.attendance_session_type;
	select id into _session_id
	from public.attendance_sessions
	where date = p_date and session_type = _session_type;

	if _session_id is null then
		insert into public.attendance_sessions (date, session_type)
		values (p_date, _session_type)
		returning id into _session_id;
	end if;
	return _session_id;
end;
$$;

-- RPC: get_unallocated_students
create or replace function public.get_unallocated_students()
returns setof public.students
language sql
stable
as $$
	select s.*
	from public.students s
	left join public.room_allocations ra
	on ra.student_id = s.id and ra.is_active = true and ra.end_date is null
	where ra.id is null;
$$;

-- RPC: update_room_occupancy(room_id)
create or replace function public.update_room_occupancy(p_room_id uuid)
returns void
language sql
security definer
as $$
	update public.rooms r
	set occupants = coalesce((
		select count(*)::int
		from public.room_allocations ra
		where ra.room_id = r.id and ra.is_active = true and ra.end_date is null
	), 0),
	updated_at = now()
	where r.id = p_room_id;
$$;

-- Trigger to keep room.occupants in sync
create or replace function public.trg_room_allocations_sync()
returns trigger
language plpgsql
as $$
begin
	perform public.update_room_occupancy(coalesce(new.room_id, old.room_id));
	return coalesce(new, old);
end;
$$;

drop trigger if exists room_allocations_sync on public.room_allocations;
create trigger room_allocations_sync
	after insert or update or delete on public.room_allocations
	for each row execute function public.trg_room_allocations_sync();

-- RPC: allocate_room(student_id, room_id, start_date)
create or replace function public.allocate_room(p_student_id uuid, p_room_id uuid, p_start_date date default now())
returns void
language plpgsql
security definer
as $$
begin
	-- end existing active allocations for this student
	update public.room_allocations
	set is_active = false, end_date = p_start_date
	where student_id = p_student_id and is_active = true and end_date is null;

	-- create new allocation
	insert into public.room_allocations (student_id, room_id, start_date, is_active)
	values (p_student_id, p_room_id, p_start_date, true);

	-- update room occupancy
	perform public.update_room_occupancy(p_room_id);
end;
$$;

-- RPC: universal_search(term) - simple example over a few entities
create or replace function public.universal_search(p_search_term text)
returns table(entity text, entity_id uuid, title text, detail text)
language sql
stable
as $$
	with
	q as (select '%' || trim(p_search_term) || '%' as pat)
	select 'student'::text as entity, s.id as entity_id, s.full_name as title, s.email as detail
	from public.students s, q
	where s.full_name ilike q.pat or s.email ilike q.pat
	union all
	select 'room', r.id, r.room_number, r.status::text
	from public.rooms r, q
	where r.room_number ilike q.pat
	union all
	select 'notice', n.id, n.title, n.audience::text
	from public.notices n, q
	where n.title ilike q.pat or n.message ilike q.pat;
$$;

-- RLS policies
alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.notices enable row level security;
alter table public.maintenance_requests enable row level security;
alter table public.room_allocations enable row level security;
alter table public.fees enable row level security;
alter table public.payments enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.visitors enable row level security;

-- Profiles policies
create policy "profiles_self_select" on public.profiles
	for select using (id = auth.uid() or public.is_admin_or_staff());

create policy "profiles_self_update" on public.profiles
	for update using (id = auth.uid())
	with check (id = auth.uid());

create policy "profiles_admin_rw" on public.profiles
	for all using (public.is_admin_or_staff());

-- Rooms: everyone can read, admin/staff manage
create policy "rooms_read_all" on public.rooms
	for select using (true);
create policy "rooms_admin_rw" on public.rooms
	for all using (public.is_admin_or_staff());

-- Notices: read by audience; admin/staff manage
create policy "notices_read_by_audience" on public.notices
	for select using (
		public.is_admin_or_staff()
		or exists (
			select 1
			from public.profiles p
			where p.id = auth.uid()
			and (
				notices.audience = 'all'
				or (p.role = 'Student' and notices.audience in ('all','students'))
				or (p.role in ('Admin','Staff') and notices.audience in ('all','students','staff','admins'))
			)
		)
	);
create policy "notices_admin_rw" on public.notices
	for all using (public.is_admin_or_staff())
	with check (public.is_admin_or_staff());

-- Maintenance: self can insert/select own; admin/staff all
create policy "maintenance_self_crud" on public.maintenance_requests
	for select using (reported_by_id = auth.uid() or public.is_admin_or_staff());
create policy "maintenance_self_insert" on public.maintenance_requests
	for insert with check (reported_by_id = auth.uid() or public.is_admin_or_staff());
create policy "maintenance_admin_update" on public.maintenance_requests
	for update using (public.is_admin_or_staff()) with check (true);
create policy "maintenance_admin_delete" on public.maintenance_requests
	for delete using (public.is_admin_or_staff());

-- Room allocations: student sees own; admin/staff manage
create policy "allocations_self_read" on public.room_allocations
	for select using (student_id = auth.uid() or public.is_admin_or_staff());
create policy "allocations_admin_rw" on public.room_allocations
	for all using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

-- Fees: student reads own; admin/staff manage
create policy "fees_self_read" on public.fees
	for select using (student_id = auth.uid() or public.is_admin_or_staff());
create policy "fees_admin_rw" on public.fees
	for all using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

-- Payments: readable if fee belongs to user; admin/staff manage
create policy "payments_self_read" on public.payments
	for select using (
		public.is_admin_or_staff()
		or exists (select 1 from public.fees f where f.id = payments.fee_id and f.student_id = auth.uid())
	);
create policy "payments_admin_rw" on public.payments
	for all using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

-- Attendance sessions: read all; admin/staff manage
create policy "attendance_sessions_read" on public.attendance_sessions
	for select using (true);
create policy "attendance_sessions_admin_rw" on public.attendance_sessions
	for all using (public.is_admin_or_staff());

-- Attendance records: student reads own; admin/staff manage
create policy "attendance_records_self_read" on public.attendance_records
	for select using (student_id = auth.uid() or public.is_admin_or_staff());
create policy "attendance_records_admin_rw" on public.attendance_records
	for all using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

-- Visitors: student reads own; admin/staff manage
create policy "visitors_self_read" on public.visitors
	for select using (student_id = auth.uid() or public.is_admin_or_staff());
create policy "visitors_admin_rw" on public.visitors
	for all using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

-- Automatically create/update profile from auth.users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
	insert into public.profiles (id, full_name, email, role, mobile_number, course, joining_date, avatar_url)
	values (
		new.id,
		coalesce(new.raw_user_meta_data->>'full_name', new.email),
		new.email,
		coalesce((new.raw_user_meta_data->>'role')::public.role_type, 'Student'),
		new.raw_user_meta_data->>'mobile_number',
		new.raw_user_meta_data->>'course',
		nullif(new.raw_user_meta_data->>'joining_date','')::date,
		new.raw_user_meta_data->>'avatar_url'
	)
	on conflict (id) do update set
		full_name = excluded.full_name,
		email = excluded.email,
		role = excluded.role,
		mobile_number = excluded.mobile_number,
		course = excluded.course,
		joining_date = excluded.joining_date,
		avatar_url = excluded.avatar_url,
		updated_at = now();
	return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
	after insert on auth.users
	for each row execute function public.handle_new_user();

-- Also ensure profile stays in sync on metadata updates (and recreate if deleted)
drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
	after update on auth.users
	for each row execute function public.handle_new_user();

-- RPC: process_fee_payment(fee_id) - marks fee as paid and logs payment
create or replace function public.process_fee_payment(p_fee_id uuid)
returns void
language plpgsql
security definer
as $$
declare
	_fee record;
	_can boolean;
begin
	select f.* into _fee from public.fees f where f.id = p_fee_id;
	if not found then
		raise exception 'Fee not found';
	end if;

	-- permission: owner or admin/staff
	select (_fee.student_id = auth.uid()) or public.is_admin_or_staff() into _can;
	if not _can then
		raise exception 'Not allowed';
	end if;

	-- mark paid if not already
	update public.fees
	set status = 'Paid',
		payment_date = coalesce(payment_date, now())
	where id = p_fee_id;

	-- log payment if not already logged at same timestamp/amount
	insert into public.payments (fee_id, amount, paid_on, method, reference)
	values (_fee.id, _fee.amount, now(), 'manual', null);
end;
$$;

commit;


