/*
# [Fix] Correct Enum Casing in Functions
This migration updates database functions to use the correct capitalized casing for the `room_status` enum ('Occupied', 'Vacant') as defined in the initial schema. This resolves inconsistencies that could cause errors during room allocation and status updates.

## Query Description: This operation modifies two functions: `allocate_room` and `update_room_occupancy`. It ensures that when these functions update the `status` column in the `rooms` table, they use the capitalized enum values ('Occupied' and 'Vacant'). This change is low-risk as it only affects function logic and does not alter table structure or data. It aligns the function definitions with the `room_status` enum type, preventing "invalid input value for enum" errors.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Functions modified:
  - `public.allocate_room(p_student_id uuid, p_room_id uuid)`
  - `public.update_room_occupancy(p_room_id uuid)`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. Function logic is slightly altered, but performance will not be affected.
*/

create or replace function public.allocate_room(p_student_id uuid, p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  room_capacity int;
  current_occupants int;
begin
  -- Check room capacity
  select occupants into room_capacity from public.rooms where id = p_room_id;
  select count(*) into current_occupants from public.room_allocations where room_id = p_room_id and is_active = true;

  if current_occupants >= room_capacity then
    raise exception 'Room is already full';
  end if;

  -- Deactivate any previous active allocation for the student
  update public.room_allocations
  set is_active = false, end_date = now()
  where student_id = p_student_id and is_active = true;

  -- Create new allocation
  insert into public.room_allocations (student_id, room_id, start_date, is_active)
  values (p_student_id, p_room_id, now(), true);

  -- Update the room status to 'Occupied'
  update public.rooms
  set status = 'Occupied'
  where id = p_room_id;
end;
$$;


create or replace function public.update_room_occupancy(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  active_occupants int;
  room_capacity int;
  current_status public.room_status;
begin
  -- Get the current status of the room
  select status into current_status from public.rooms where id = p_room_id;

  -- If the room is under maintenance, do not change its status
  if current_status = 'Maintenance' then
    return;
  end if;
  
  -- Count active occupants and get room capacity
  select count(*), max(r.occupants)
  into active_occupants, room_capacity
  from public.room_allocations ra
  join public.rooms r on ra.room_id = r.id
  where ra.room_id = p_room_id and ra.is_active = true;

  -- Update room status based on occupancy
  if active_occupants = 0 then
    update public.rooms set status = 'Vacant' where id = p_room_id;
  else
    update public.rooms set status = 'Occupied' where id = p_room_id;
  end if;
end;
$$;
