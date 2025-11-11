/*
# [Security Hardening] Set All Function Search Paths
This migration hardens the security of all remaining custom database functions by explicitly setting their `search_path` to 'public'. This mitigates a security vulnerability where a malicious user could potentially create objects in other schemas to hijack function execution.

## Query Description:
This operation is safe and non-destructive. It redefines existing functions to include a security best practice, ensuring they only look for database objects within the 'public' schema. This has no impact on existing data and resolves the "Function Search Path Mutable" security advisory for all functions.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by redefining the functions without the search path)

## Structure Details:
- Functions being modified:
  - allocate_room(uuid, uuid)
  - deallocate_room_by_student(uuid)
  - get_or_create_session(date, public.session_type_enum)
  - process_fee_payment(uuid)
  - update_room_occupancy(uuid)

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: Admin privileges to alter functions.
- Fixes: Addresses all remaining "Function Search Path Mutable" security advisories.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. May offer a micro-optimization by restricting schema searching.
*/

-- Redefine allocate_room function
CREATE OR REPLACE FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $function$
BEGIN
  -- Create a new active allocation record
  INSERT INTO public.room_allocations (student_id, room_id, start_date, is_active)
  VALUES (p_student_id, p_room_id, now(), true);

  -- Update the room's status to 'Occupied'
  PERFORM public.update_room_occupancy(p_room_id);
END;
$function$;

-- Redefine deallocate_room_by_student function
CREATE OR REPLACE FUNCTION public.deallocate_room_by_student(p_student_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $function$
DECLARE
    v_room_id UUID;
BEGIN
    -- Find the active room for the student
    SELECT room_id INTO v_room_id
    FROM public.room_allocations
    WHERE student_id = p_student_id AND is_active = true;

    -- Deactivate the allocation
    UPDATE public.room_allocations
    SET is_active = false, end_date = now()
    WHERE student_id = p_student_id AND is_active = true;

    -- Update the room's occupancy status
    IF v_room_id IS NOT NULL THEN
        PERFORM public.update_room_occupancy(v_room_id);
    END IF;
END;
$function$;

-- Redefine get_or_create_session function
CREATE OR REPLACE FUNCTION public.get_or_create_session(p_date date, p_session_type public.session_type_enum)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path = 'public'
AS $function$
DECLARE
    session_uuid UUID;
BEGIN
    -- Try to find an existing session
    SELECT id INTO session_uuid
    FROM public.attendance_sessions
    WHERE date = p_date AND session_type = p_session_type;

    -- If not found, create a new one
    IF session_uuid IS NULL THEN
        INSERT INTO public.attendance_sessions (date, session_type)
        VALUES (p_date, p_session_type)
        RETURNING id INTO session_uuid;
    END IF;

    RETURN session_uuid;
END;
$function$;


-- Redefine process_fee_payment function
CREATE OR REPLACE FUNCTION public.process_fee_payment(p_fee_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $function$
DECLARE
    v_amount NUMERIC;
BEGIN
    -- Get the fee amount
    SELECT amount INTO v_amount
    FROM public.fees
    WHERE id = p_fee_id AND status <> 'Paid';

    IF v_amount IS NULL THEN
        RAISE EXCEPTION 'Fee not found or already paid.';
    END IF;

    -- Update the fee status
    UPDATE public.fees
    SET status = 'Paid', payment_date = now()
    WHERE id = p_fee_id;

    -- Insert into payments table
    INSERT INTO public.payments (fee_id, amount, paid_on)
    VALUES (p_fee_id, v_amount, now());
END;
$function$;

-- Redefine update_room_occupancy function
CREATE OR REPLACE FUNCTION public.update_room_occupancy(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $function$
DECLARE
    active_occupants INT;
BEGIN
    -- Count active occupants for the room
    SELECT count(*)
    INTO active_occupants
    FROM public.room_allocations
    WHERE room_id = p_room_id AND is_active = true;

    -- Update room status based on count
    IF active_occupants > 0 THEN
        UPDATE public.rooms
        SET status = 'Occupied'
        WHERE id = p_room_id;
    ELSE
        UPDATE public.rooms
        SET status = 'Vacant'
        WHERE id = p_room_id AND status <> 'Maintenance';
    END IF;
END;
$function$;
