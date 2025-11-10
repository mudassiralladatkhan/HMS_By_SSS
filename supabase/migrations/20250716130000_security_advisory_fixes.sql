/*
# [Security Advisory Fixes]
This migration script addresses security advisories identified in the project. It modifies existing views to use `SECURITY INVOKER` and sets a fixed `search_path` for all functions to mitigate potential security risks.

## Query Description:
This operation updates database objects to enhance security.
- **Views**: All views are altered to run with the permissions of the user querying them (`SECURITY INVOKER`), which is crucial for enforcing Row Level Security (RLS) correctly. This fixes the "Security Definer View" error.
- **Functions**: All functions are updated to have a fixed `search_path`. This prevents malicious users from manipulating the function's behavior by altering the search path. This addresses the "Function Search Path Mutable" warnings.
There is no risk of data loss.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- **Views Altered**: students, rooms, fees, payments, maintenance_requests, visitors, room_allocations, attendance_records, attendance_sessions, notices.
- **Functions Altered**: handle_new_user, update_room_occupancy, update_room_occupancy_for_room, get_unallocated_students, allocate_room, get_or_create_session, universal_search, process_fee_payment.

## Security Implications:
- RLS Status: This change is critical for correctly enforcing RLS policies.
- Policy Changes: No
- Auth Requirements: None

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible performance impact. These changes are primarily for security hardening.
*/

-- Step 1: Alter Views to use SECURITY INVOKER
-- This ensures that RLS policies of the calling user are enforced.

ALTER VIEW public.students SET (security_invoker = true);
ALTER VIEW public.rooms SET (security_invoker = true);
ALTER VIEW public.fees SET (security_invoker = true);
ALTER VIEW public.payments SET (security_invoker = true);
ALTER VIEW public.maintenance_requests SET (security_invoker = true);
ALTER VIEW public.visitors SET (security_invoker = true);
ALTER VIEW public.room_allocations SET (security_invoker = true);
ALTER VIEW public.attendance_records SET (security_invoker = true);
ALTER VIEW public.attendance_sessions SET (security_invoker = true);
ALTER VIEW public.notices SET (security_invoker = true);

-- Step 2: Recreate Functions with a fixed search_path
-- This mitigates risks associated with a mutable search_path.

-- Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, mobile_number, course, joining_date)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'role',
    new.raw_user_meta_data->>'mobile_number',
    new.raw_user_meta_data->>'course',
    (new.raw_user_meta_data->>'joining_date')::date
  );

  -- Handle pre-allocated room number if provided
  IF new.raw_user_meta_data->>'room_number' IS NOT NULL AND new.raw_user_meta_data->>'room_number' != '' THEN
    DECLARE
      v_room_id UUID;
    BEGIN
      SELECT id INTO v_room_id FROM public.rooms WHERE room_number = new.raw_user_meta_data->>'room_number' LIMIT 1;
      IF v_room_id IS NOT NULL THEN
        INSERT INTO public.room_allocations (room_id, student_id, start_date)
        VALUES (v_room_id, new.id, CURRENT_DATE);
      END IF;
    END;
  END IF;

  RETURN new;
END;
$$;

-- Function to update room occupancy for a specific room
CREATE OR REPLACE FUNCTION public.update_room_occupancy_for_room(p_room_id UUID)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    current_occupants INT;
BEGIN
    SELECT COUNT(*) INTO current_occupants
    FROM public.room_allocations
    WHERE room_id = p_room_id AND is_active = TRUE;

    UPDATE public.rooms
    SET status = CASE
        WHEN current_occupants >= occupants THEN 'Occupied'
        ELSE 'Vacant'
    END
    WHERE id = p_room_id AND status <> 'Maintenance';
END;
$$;

-- Trigger function to update room occupancy
CREATE OR REPLACE FUNCTION public.update_room_occupancy()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM update_room_occupancy_for_room(NEW.room_id);
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handles both change of room and deactivation
        PERFORM update_room_occupancy_for_room(OLD.room_id);
        IF NEW.room_id IS NOT NULL AND NEW.room_id <> OLD.room_id THEN
            -- Also update the new room
            PERFORM update_room_occupancy_for_room(NEW.room_id);
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM update_room_occupancy_for_room(OLD.room_id);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Function to get unallocated students
CREATE OR REPLACE FUNCTION public.get_unallocated_students()
RETURNS TABLE(id UUID, full_name TEXT, email TEXT, course TEXT, contact TEXT)
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.full_name,
        u.email,
        p.course,
        p.mobile_number as contact
    FROM
        public.profiles p
    JOIN
        auth.users u ON p.id = u.id
    WHERE
        p.role = 'Student' AND
        p.id NOT IN (
            SELECT ra.student_id
            FROM public.room_allocations ra
            WHERE ra.is_active = TRUE
        )
    ORDER BY
        p.full_name;
END;
$$;

-- Function to allocate a room
CREATE OR REPLACE FUNCTION public.allocate_room(p_student_id UUID, p_room_id UUID)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_room_capacity INT;
    v_current_occupancy INT;
BEGIN
    SELECT occupants INTO v_room_capacity FROM public.rooms WHERE id = p_room_id;
    SELECT COUNT(*) INTO v_current_occupancy FROM public.room_allocations WHERE room_id = p_room_id AND is_active = TRUE;

    IF v_current_occupancy >= v_room_capacity THEN
        RAISE EXCEPTION 'Room is already full.';
    END IF;

    -- Deactivate any previous active allocation for the student
    UPDATE public.room_allocations
    SET end_date = CURRENT_DATE, is_active = FALSE
    WHERE student_id = p_student_id AND is_active = TRUE;

    -- Insert new allocation
    INSERT INTO public.room_allocations (student_id, room_id, start_date)
    VALUES (p_student_id, p_room_id, CURRENT_DATE);
END;
$$;


-- Function to get or create an attendance session
CREATE OR REPLACE FUNCTION public.get_or_create_session(p_date DATE, p_session_type public.attendance_session_type)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_session_id UUID;
BEGIN
    SELECT id INTO v_session_id FROM public.attendance_sessions
    WHERE date = p_date AND session_type = p_session_type;

    IF v_session_id IS NULL THEN
        INSERT INTO public.attendance_sessions (date, session_type)
        VALUES (p_date, p_session_type)
        RETURNING id INTO v_session_id;
    END IF;

    RETURN v_session_id;
END;
$$;

-- Function for universal search
CREATE OR REPLACE FUNCTION public.universal_search(p_search_term TEXT)
RETURNS JSON
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    students_json JSON;
    rooms_json JSON;
BEGIN
    SELECT json_agg(json_build_object(
        'id', p.id,
        'label', p.full_name || ' (' || p.course || ')',
        'path', '/students/' || p.id
    ))
    INTO students_json
    FROM public.profiles p
    WHERE p.role = 'Student'
      AND (
        p.full_name ILIKE '%' || p_search_term || '%' OR
        p.email ILIKE '%' || p_search_term || '%' OR
        p.course ILIKE '%' || p_search_term || '%'
      );

    SELECT json_agg(json_build_object(
        'id', r.id,
        'label', 'Room ' || r.room_number || ' (' || r.type || ')',
        'path', '/rooms/' || r.id
    ))
    INTO rooms_json
    FROM public.rooms r
    WHERE r.room_number ILIKE '%' || p_search_term || '%';

    RETURN json_build_object(
        'students', COALESCE(students_json, '[]'::json),
        'rooms', COALESCE(rooms_json, '[]'::json)
    );
END;
$$;


-- Function to process a fee payment
CREATE OR REPLACE FUNCTION public.process_fee_payment(p_fee_id UUID)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_fee_amount NUMERIC;
    v_student_id UUID;
BEGIN
    -- Get fee details
    SELECT amount, student_id INTO v_fee_amount, v_student_id
    FROM public.fees
    WHERE id = p_fee_id AND status <> 'Paid';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fee record not found or already paid.';
    END IF;

    -- Update fee status
    UPDATE public.fees
    SET status = 'Paid', payment_date = CURRENT_TIMESTAMP
    WHERE id = p_fee_id;

    -- Create a payment record
    INSERT INTO public.payments (fee_id, amount, paid_on)
    VALUES (p_fee_id, v_fee_amount, CURRENT_TIMESTAMP);
END;
$$;
