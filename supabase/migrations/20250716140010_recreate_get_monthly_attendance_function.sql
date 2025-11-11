/*
          # [Recreate get_monthly_attendance_for_student Function]
          This migration recreates the `get_monthly_attendance_for_student` function, which was missing and causing other migrations to fail. The function is used to fetch a student's attendance for a specific month and year.

          ## Query Description: [This operation is safe and non-destructive. It defines a new database function required for the attendance feature. It checks for a student's attendance records for a given month and year, aggregates them by day, and returns a JSON object mapping each day to the final attendance status. It will not alter any existing data.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          - Function: `public.get_monthly_attendance_for_student(uuid, integer, integer)`
          
          ## Security Implications:
          - RLS Status: [Not Applicable]
          - Policy Changes: [No]
          - Auth Requirements: [The function uses SECURITY DEFINER to read attendance data based on the provided student ID.]
          
          ## Performance Impact:
          - Indexes: [No changes]
          - Triggers: [No changes]
          - Estimated Impact: [Low. The function performs indexed lookups and should be efficient for fetching monthly data.]
          */

CREATE OR REPLACE FUNCTION public.get_monthly_attendance_for_student(
    p_student_id uuid,
    p_month integer,
    p_year integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result jsonb;
BEGIN
    -- This function constructs a JSON object mapping each day of the specified month
    -- to the attendance status of the given student. It prioritizes statuses
    -- (e.g., 'Holiday' > 'Absent' > 'Leave' > 'Present') if multiple records exist for a single day.
    -- It is designed to be called from the application to display a student's monthly attendance calendar.

    WITH monthly_sessions AS (
        SELECT id, date
        FROM attendance_sessions
        WHERE
            EXTRACT(MONTH FROM date) = p_month
            AND EXTRACT(YEAR FROM date) = p_year
    ),
    student_records AS (
        SELECT
            ar.status,
            ms.date
        FROM attendance_records ar
        JOIN monthly_sessions ms ON ar.session_id = ms.id
        WHERE ar.student_id = p_student_id
    ),
    daily_status AS (
        SELECT
            EXTRACT(DAY FROM date) as day,
            -- Assign priority to statuses to handle cases with multiple entries on the same day (e.g., morning/evening)
            -- The status with the highest priority will be chosen for that day.
            CASE
                WHEN 'Holiday' = ANY(array_agg(status)) THEN 'Holiday'
                WHEN 'Absent' = ANY(array_agg(status)) THEN 'Absent'
                WHEN 'Leave' = ANY(array_agg(status)) THEN 'Leave'
                WHEN 'Present' = ANY(array_agg(status)) THEN 'Present'
                ELSE NULL
            END as final_status
        FROM student_records
        GROUP BY date
    )
    SELECT jsonb_object_agg(day, final_status)
    INTO result
    FROM daily_status;

    RETURN COALESCE(result, '{}'::jsonb);
END;
$$;
