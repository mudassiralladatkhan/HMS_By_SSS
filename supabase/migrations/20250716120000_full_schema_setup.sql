/*
          # [Full Schema Setup]
          This script sets up the entire database schema for the Hostel Management System.
          It creates tables, views, functions, triggers, and Row Level Security (RLS) policies.

          ## Query Description: [This is a foundational script that creates the entire database structure from scratch. It is safe to run on a new, empty project.
          WARNING: Running this on a database with existing tables of the same name will cause errors or data loss. Ensure your database is empty or backed up before execution.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "High"
          - Requires-Backup: true
          - Reversible: false
          
          ## Structure Details:
          - Tables Created: profiles, rooms, room_allocations, fees, payments, maintenance_requests, notices, visitors, attendance_sessions, attendance_records.
          - Views Created: students.
          - Functions Created: handle_new_user, get_unallocated_students, allocate_room, update_room_occupancy, universal_search, get_or_create_session, process_fee_payment, get_monthly_attendance_for_student.
          - Triggers Created: on_auth_user_created.
          
          ## Security Implications:
          - RLS Status: Enabled on all tables.
          - Policy Changes: Yes, policies are created for all tables to restrict access based on user roles (Admin, Staff, Student).
          - Auth Requirements: Policies rely on `auth.uid()` and a custom `get_my_role()` function.
          
          ## Performance Impact:
          - Indexes: Primary keys and foreign keys are indexed automatically. Additional indexes are added on frequently queried columns.
          - Triggers: A trigger is added to `auth.users` to automate profile creation.
          - Estimated Impact: Low impact on a new database. Establishes the baseline performance characteristics.
          */

-- 1. PROFILES TABLE
-- Stores user profile information, linked to auth.users.
CREATE TABLE public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    email text UNIQUE,
    contact text,
    course text,
    role text NOT NULL DEFAULT 'Student'::text,
    joining_date timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.profiles IS 'Stores user profile information, linked to auth.users.';

-- 2. ROOMS TABLE
-- Stores information about each room in the hostel.
CREATE TABLE public.rooms (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    room_number text NOT NULL UNIQUE,
    type text NOT NULL,
    occupants integer NOT NULL,
    status text NOT NULL DEFAULT 'Vacant'::text,
    created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.rooms IS 'Stores information about each room in the hostel.';

-- 3. ROOM ALLOCATIONS TABLE
-- Manages the allocation of rooms to students.
CREATE TABLE public.room_allocations (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    start_date timestamptz DEFAULT now(),
    end_date timestamptz,
    is_active boolean GENERATED ALWAYS AS (end_date IS NULL) STORED,
    created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.room_allocations IS 'Manages the allocation of rooms to students.';
CREATE INDEX idx_room_allocations_student_id ON public.room_allocations(student_id);
CREATE INDEX idx_room_allocations_room_id ON public.room_allocations(room_id);

-- 4. FEES TABLE
-- Tracks fee records for each student.
CREATE TABLE public.fees (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    due_date date NOT NULL,
    status text NOT NULL DEFAULT 'Due'::text,
    payment_date date,
    created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.fees IS 'Tracks fee records for each student.';
CREATE INDEX idx_fees_student_id ON public.fees(student_id);

-- 5. PAYMENTS TABLE
-- Logs all payments made by students.
CREATE TABLE public.payments (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_id uuid NOT NULL REFERENCES public.fees(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    paid_on timestamptz DEFAULT now(),
    payment_method text DEFAULT 'Card'::text
);
COMMENT ON TABLE public.payments IS 'Logs all payments made by students.';
CREATE INDEX idx_payments_fee_id ON public.payments(fee_id);

-- 6. MAINTENANCE REQUESTS TABLE
-- Tracks maintenance requests from users.
CREATE TABLE public.maintenance_requests (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    reported_by_id uuid NOT NULL REFERENCES public.profiles(id),
    room_number text NOT NULL,
    issue text NOT NULL,
    status text NOT NULL DEFAULT 'Pending'::text,
    created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.maintenance_requests IS 'Tracks maintenance requests from users.';

-- 7. NOTICES TABLE
-- Stores announcements for different audiences.
CREATE TABLE public.notices (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by uuid REFERENCES public.profiles(id),
    title text NOT NULL,
    message text NOT NULL,
    audience text NOT NULL DEFAULT 'all'::text,
    created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.notices IS 'Stores announcements for different audiences.';

-- 8. VISITORS TABLE
-- Logs visitor entries and exits.
CREATE TABLE public.visitors (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    visitor_name text NOT NULL,
    check_in_time timestamptz DEFAULT now(),
    check_out_time timestamptz,
    status text NOT NULL DEFAULT 'In'::text
);
COMMENT ON TABLE public.visitors IS 'Logs visitor entries and exits.';
CREATE INDEX idx_visitors_student_id ON public.visitors(student_id);

-- 9. ATTENDANCE SESSIONS TABLE
-- Defines attendance sessions (e.g., Morning/Evening for a specific date).
CREATE TABLE public.attendance_sessions (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    date date NOT NULL,
    session_type text NOT NULL,
    UNIQUE(date, session_type)
);
COMMENT ON TABLE public.attendance_sessions IS 'Defines attendance sessions (e.g., Morning/Evening for a specific date).';

-- 10. ATTENDANCE RECORDS TABLE
-- Records the attendance status for each student in a session.
CREATE TABLE public.attendance_records (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id uuid NOT NULL REFERENCES public.attendance_sessions(id) ON DELETE CASCADE,
    student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'Present'::text,
    UNIQUE(session_id, student_id)
);
COMMENT ON TABLE public.attendance_records IS 'Records the attendance status for each student in a session.';
CREATE INDEX idx_attendance_records_student_id ON public.attendance_records(student_id);

-- VIEWS
-- Create a view for easier querying of students.
CREATE OR REPLACE VIEW public.students AS
SELECT id, full_name, email, contact, course, joining_date, created_at
FROM public.profiles
WHERE role = 'Student';
COMMENT ON VIEW public.students IS 'A view of the profiles table, filtered to only show users with the Student role.';

-- FUNCTIONS & TRIGGERS
-- Function to create a profile for a new user.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role, contact, course, joining_date)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'role',
    new.raw_user_meta_data->>'mobile_number',
    new.raw_user_meta_data->>'course',
    (new.raw_user_meta_data->>'joining_date')::timestamptz
  );
  RETURN new;
END;
$$;
COMMENT ON FUNCTION public.handle_new_user() IS 'Trigger function to automatically create a profile when a new user signs up.';

-- Trigger to call the function on new user creation.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Helper function to get user role
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;
COMMENT ON FUNCTION public.get_my_role() IS 'Returns the role of the currently authenticated user.';

-- ROW LEVEL SECURITY (RLS)
-- Enable RLS for all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

-- RLS POLICIES
-- Profiles
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Admins and Staff can view all profiles" ON public.profiles FOR SELECT USING (get_my_role() IN ('Admin', 'Staff'));

-- Rooms
CREATE POLICY "Authenticated users can view all rooms" ON public.rooms FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins and Staff can manage rooms" ON public.rooms FOR ALL USING (get_my_role() IN ('Admin', 'Staff'));

-- Room Allocations
CREATE POLICY "Students can view their own allocation" ON public.room_allocations FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Admins and Staff can manage all allocations" ON public.room_allocations FOR ALL USING (get_my_role() IN ('Admin', 'Staff'));

-- Fees
CREATE POLICY "Students can view their own fees" ON public.fees FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Admins and Staff can manage all fees" ON public.fees FOR ALL USING (get_my_role() IN ('Admin', 'Staff'));

-- Payments
CREATE POLICY "Students can view their own payments" ON public.payments FOR SELECT USING (EXISTS (SELECT 1 FROM fees WHERE fees.id = payments.fee_id AND fees.student_id = auth.uid()));
CREATE POLICY "Admins and Staff can view all payments" ON public.payments FOR SELECT USING (get_my_role() IN ('Admin', 'Staff'));

-- Maintenance Requests
CREATE POLICY "Users can manage their own maintenance requests" ON public.maintenance_requests FOR ALL USING (auth.uid() = reported_by_id);
CREATE POLICY "Admins and Staff can view all maintenance requests" ON public.maintenance_requests FOR SELECT USING (get_my_role() IN ('Admin', 'Staff'));
CREATE POLICY "Admins and Staff can update all maintenance requests" ON public.maintenance_requests FOR UPDATE USING (get_my_role() IN ('Admin', 'Staff'));

-- Notices
CREATE POLICY "Authenticated users can view notices" ON public.notices FOR SELECT USING (
    auth.role() = 'authenticated' AND (
        audience = 'all' OR
        (audience = 'students' AND get_my_role() = 'Student') OR
        (audience = 'staff' AND get_my_role() IN ('Admin', 'Staff'))
    )
);
CREATE POLICY "Admins and Staff can manage notices" ON public.notices FOR ALL USING (get_my_role() IN ('Admin', 'Staff'));

-- Visitors
CREATE POLICY "Students can view their own visitors" ON public.visitors FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Admins and Staff can manage all visitors" ON public.visitors FOR ALL USING (get_my_role() IN ('Admin', 'Staff'));

-- Attendance Sessions
CREATE POLICY "Authenticated users can view attendance sessions" ON public.attendance_sessions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins and Staff can manage attendance sessions" ON public.attendance_sessions FOR ALL USING (get_my_role() IN ('Admin', 'Staff'));

-- Attendance Records
CREATE POLICY "Students can view and create their own attendance" ON public.attendance_records FOR ALL USING (auth.uid() = student_id);
CREATE POLICY "Admins and Staff can manage all attendance records" ON public.attendance_records FOR ALL USING (get_my_role() IN ('Admin', 'Staff'));


-- RPC FUNCTIONS
-- Function to get unallocated students
CREATE OR REPLACE FUNCTION public.get_unallocated_students()
RETURNS TABLE(id uuid, full_name text, email text, course text, contact text)
LANGUAGE sql
AS $$
  SELECT p.id, p.full_name, p.email, p.course, p.contact
  FROM public.profiles p
  WHERE p.role = 'Student' AND NOT EXISTS (
    SELECT 1 FROM public.room_allocations ra WHERE ra.student_id = p.id AND ra.is_active = true
  )
  ORDER BY p.full_name;
$$;
COMMENT ON FUNCTION public.get_unallocated_students() IS 'Returns a list of students who are not currently allocated to any room.';

-- Function to update room occupancy and status
CREATE OR REPLACE FUNCTION public.update_room_occupancy(p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  current_occupancy integer;
  room_capacity integer;
BEGIN
  SELECT count(*) INTO current_occupancy FROM public.room_allocations WHERE room_id = p_room_id AND is_active = true;
  SELECT occupants INTO room_capacity FROM public.rooms WHERE id = p_room_id;

  UPDATE public.rooms
  SET status = CASE
    WHEN current_occupancy >= room_capacity THEN 'Occupied'
    ELSE 'Vacant'
  END
  WHERE id = p_room_id AND status != 'Maintenance';
END;
$$;
COMMENT ON FUNCTION public.update_room_occupancy(uuid) IS 'Updates the status of a room based on its current occupancy.';

-- Function to allocate a room to a student
CREATE OR REPLACE FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Deactivate any previous active allocation for the student
  UPDATE public.room_allocations SET end_date = now() WHERE student_id = p_student_id AND is_active = true;
  
  -- Create new allocation
  INSERT INTO public.room_allocations (student_id, room_id) VALUES (p_student_id, p_room_id);
  
  -- Update room status
  PERFORM public.update_room_occupancy(p_room_id);
END;
$$;
COMMENT ON FUNCTION public.allocate_room(uuid, uuid) IS 'Allocates a student to a room, deactivating any previous allocation and updating room status.';

-- Function for universal search
CREATE OR REPLACE FUNCTION public.universal_search(p_search_term text)
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
  students_json json;
  rooms_json json;
BEGIN
  SELECT json_agg(json_build_object('id', id, 'label', full_name, 'path', '/students/' || id))
  INTO students_json
  FROM public.students
  WHERE full_name ILIKE '%' || p_search_term || '%';

  SELECT json_agg(json_build_object('id', id, 'label', 'Room ' || room_number, 'path', '/rooms/' || id))
  INTO rooms_json
  FROM public.rooms
  WHERE room_number ILIKE '%' || p_search_term || '%';

  RETURN json_build_object(
    'students', COALESCE(students_json, '[]'::json),
    'rooms', COALESCE(rooms_json, '[]'::json)
  );
END;
$$;
COMMENT ON FUNCTION public.universal_search(text) IS 'Performs a global search across students and rooms, returning results as JSON.';

-- Function to get or create an attendance session
CREATE OR REPLACE FUNCTION public.get_or_create_session(p_date date, p_session_type text)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  session_id uuid;
BEGIN
  SELECT id INTO session_id FROM public.attendance_sessions WHERE date = p_date AND session_type = p_session_type;
  
  IF session_id IS NULL THEN
    INSERT INTO public.attendance_sessions (date, session_type) VALUES (p_date, p_session_type) RETURNING id INTO session_id;
  END IF;
  
  RETURN session_id;
END;
$$;
COMMENT ON FUNCTION public.get_or_create_session(date, text) IS 'Returns the ID of an existing attendance session or creates a new one if it does not exist.';

-- Function to process a fee payment
CREATE OR REPLACE FUNCTION public.process_fee_payment(p_fee_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_amount numeric;
BEGIN
  -- Update fee status and payment date
  UPDATE public.fees
  SET status = 'Paid', payment_date = current_date
  WHERE id = p_fee_id
  RETURNING amount INTO v_amount;
  
  -- Create a payment record
  IF v_amount IS NOT NULL THEN
    INSERT INTO public.payments (fee_id, amount) VALUES (p_fee_id, v_amount);
  END IF;
END;
$$;
COMMENT ON FUNCTION public.process_fee_payment(uuid) IS 'Marks a fee as paid and creates a corresponding payment record. SECURITY DEFINER is used to bypass RLS for this specific transaction.';

-- Function to get monthly attendance for a student (server-side fix)
CREATE OR REPLACE FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_year integer, p_month integer)
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
    result_json json;
BEGIN
    SELECT json_object_agg(
        EXTRACT(DAY FROM s.date),
        r.status
    )
    INTO result_json
    FROM public.attendance_sessions s
    JOIN public.attendance_records r ON s.id = r.session_id
    WHERE r.student_id = p_student_id
      AND EXTRACT(YEAR FROM s.date) = p_year
      AND EXTRACT(MONTH FROM s.date) = p_month;

    RETURN COALESCE(result_json, '{}'::json);
END;
$$;
COMMENT ON FUNCTION public.get_monthly_attendance_for_student(uuid, integer, integer) IS 'Fetches the attendance status for a given student for each day of a specific month and year.';
