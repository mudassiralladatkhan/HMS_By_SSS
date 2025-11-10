/*
          # [Function] Recreate `allocate_room`

          This script recreates the `allocate_room` function, which is essential for assigning students to rooms. The original function was likely removed during a previous database cleanup. This new version includes robust checks to ensure data integrity during the allocation process.

          ## Query Description: [This operation creates a new database function. It is a safe, non-destructive operation that restores critical application functionality. It checks for room availability and capacity before making an allocation, preventing invalid data states.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          - Creates the function `public.allocate_room(p_student_id uuid, p_room_id uuid)`.
          
          ## Security Implications:
          - RLS Status: [N/A]
          - Policy Changes: [No]
          - Auth Requirements: [The function uses SECURITY DEFINER to modify tables, but its logic is self-contained and safe.]
          
          ## Performance Impact:
          - Indexes: [N/A]
          - Triggers: [N/A]
          - Estimated Impact: [Low. This is a standard transactional function.]
          */
CREATE OR REPLACE FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_room_capacity INT;
    v_current_occupants INT;
    v_room_status TEXT;
BEGIN
    -- Lock the room row to prevent race conditions
    SELECT occupants, status INTO v_room_capacity, v_room_status
    FROM rooms
    WHERE id = p_room_id
    FOR UPDATE;

    -- Check if room exists
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room with ID % not found', p_room_id;
    END IF;

    -- Check if room is available for allocation
    IF v_room_status <> 'Vacant' THEN
        RAISE EXCEPTION 'Room is not vacant. Current status: %', v_room_status;
    END IF;
    
    -- Check if student is already allocated to this room
    PERFORM 1 FROM room_allocations WHERE student_id = p_student_id AND room_id = p_room_id AND is_active = TRUE;
    IF FOUND THEN
        RAISE EXCEPTION 'Student is already allocated to this room.';
    END IF;

    -- Check current occupancy
    SELECT COUNT(*) INTO v_current_occupants
    FROM room_allocations
    WHERE room_id = p_room_id AND is_active = TRUE;

    -- Check if room is full
    IF v_current_occupants >= v_room_capacity THEN
        RAISE EXCEPTION 'Room is already full.';
    END IF;

    -- Deactivate any previous active allocation for the student
    UPDATE room_allocations
    SET is_active = FALSE, end_date = NOW()
    WHERE student_id = p_student_id AND is_active = TRUE;

    -- Insert the new allocation
    INSERT INTO room_allocations (student_id, room_id, start_date, is_active)
    VALUES (p_student_id, p_room_id, NOW(), TRUE);

    -- Update room status to Occupied since it's no longer vacant
    UPDATE rooms
    SET status = 'Occupied'
    WHERE id = p_room_id;

END;
$$;
