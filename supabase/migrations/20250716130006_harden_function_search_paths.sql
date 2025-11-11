/*
# [Function Security] Harden Search Paths for All Functions
This migration updates all custom database functions to explicitly set their `search_path`. This is a critical security best practice that prevents "search path hijacking" attacks, where a malicious user could create objects (like functions or tables) in a public schema that get executed with the privileges of the function owner. By setting a fixed `search_path`, we ensure that functions only find and execute code from trusted schemas.

## Query Description:
This script re-defines six existing functions (`allocate_room`, `get_monthly_attendance_for_student`, `get_or_create_session`, `process_fee_payment`, `update_room_occupancy`, `universal_search`) to include `SET search_path = 'public'`. This change is purely for security hardening and does not alter the core logic or functionality of the application. It is a safe, non-destructive operation.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Modifies function: `public.allocate_room`
- Modifies function: `public.get_monthly_attendance_for_student`
- Modifies function: `public.get_or_create_session`
- Modifies function: `public.process_fee_payment`
- Modifies function: `public.update_room_occupancy`
- Modifies function: `public.universal_search`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates: Search path hijacking vulnerability.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. This is a definitional change with no runtime performance cost.
*/

-- Harden allocate_room function
CREATE OR REPLACE FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    -- Insert the new allocation record
    INSERT INTO public.room_allocations (student_id, room_id, start_date, is_active)
    VALUES (p_student_id, p_room_id, NOW(), TRUE);

    -- Update the room's occupancy status
    PERFORM public.update_room_occupancy(p_room_id);
END;
$$;

-- Harden get_monthly_attendance_for_student function
CREATE OR REPLACE FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer)
RETURNS TABLE(day integer, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        EXTRACT(DAY FROM s.date)::integer AS day,
        ar.status
    FROM
        public.attendance_sessions s
    JOIN
        public.attendance_records ar ON s.id = ar.session_id
    WHERE
        ar.student_id = p_student_id AND
        EXTRACT(MONTH FROM s.date) = p_month AND
        EXTRACT(YEAR FROM s.date) = p_year;
END;
$$;

-- Harden get_or_create_session function
CREATE OR REPLACE FUNCTION public.get_or_create_session(p_date date, p_session_type public.session_type_enum)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    session_id uuid;
BEGIN
    -- Try to find an existing session
    SELECT id INTO session_id
    FROM public.attendance_sessions
    WHERE date = p_date AND session_type = p_session_type;

    -- If not found, create a new one
    IF session_id IS NULL THEN
        INSERT INTO public.attendance_sessions (date, session_type)
        VALUES (p_date, p_session_type)
        RETURNING id INTO session_id;
    END IF;

    RETURN session_id;
END;
$$;

-- Harden process_fee_payment function
CREATE OR REPLACE FUNCTION public.process_fee_payment(p_fee_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_fee_amount numeric;
BEGIN
    -- Get the fee amount
    SELECT amount INTO v_fee_amount
    FROM public.fees
    WHERE id = p_fee_id AND status IN ('Due', 'Overdue');

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fee record not found or already paid.';
    END IF;

    -- Update the fee status and payment date
    UPDATE public.fees
    SET status = 'Paid',
        payment_date = NOW()
    WHERE id = p_fee_id;

    -- Insert a record into the payments table
    INSERT INTO public.payments (fee_id, amount, paid_on)
    VALUES (p_fee_id, v_fee_amount, NOW());
END;
$$;

-- Harden update_room_occupancy function
CREATE OR REPLACE FUNCTION public.update_room_occupancy(p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    active_occupants integer;
    room_capacity integer;
BEGIN
    -- Count active occupants for the given room
    SELECT COUNT(*)
    INTO active_occupants
    FROM public.room_allocations
    WHERE room_id = p_room_id AND is_active = TRUE;

    -- Get the room's total capacity
    SELECT occupants
    INTO room_capacity
    FROM public.rooms
    WHERE id = p_room_id;

    -- Update the room status based on occupancy
    IF active_occupants >= room_capacity THEN
        UPDATE public.rooms
        SET status = 'Occupied'
        WHERE id = p_room_id;
    ELSE
        UPDATE public.rooms
        SET status = 'Vacant'
        WHERE id = p_room_id AND status != 'Maintenance';
    END IF;
END;
$$;

-- Harden universal_search function
CREATE OR REPLACE FUNCTION public.universal_search(p_search_term text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    results jsonb;
BEGIN
    SELECT jsonb_build_object(
        'students', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', id,
                'label', full_name || ' (' || course || ')',
                'path', '/students/' || id
            )), '[]'::jsonb)
            FROM public.profiles
            WHERE role = 'Student' AND (
                full_name ILIKE '%' || p_search_term || '%' OR
                email ILIKE '%' || p_search_term || '%' OR
                course ILIKE '%' || p_search_term || '%'
            )
        ),
        'rooms', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', id,
                'label', 'Room ' || room_number || ' (' || type || ')',
                'path', '/rooms/' || id
            )), '[]'::jsonb)
            FROM public.rooms
            WHERE room_number ILIKE '%' || p_search_term || '%'
        )
    )
    INTO results;

    RETURN results;
END;
$$;
