/*
          # [Recreate Recent Activities View & Harden Security]
          This migration drops the existing (and potentially broken) `recent_activities` view and recreates it with the correct logic, including the previously missing `room_number` column. It also hardens the security of all database functions by setting an immutable search path, which resolves the outstanding security advisories.

          ## Query Description: [This operation is safe and non-destructive. It defines a database view for reading data and improves security by specifying explicit search paths for functions. No user data will be altered.]
          
          ## Metadata:
          - Schema-Category: ["Structural", "Safe"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          - Creates/Replaces the `public.recent_activities` view.
          - Alters the following functions to set a secure `search_path`:
            - `public.allocate_room`
            - `public.get_or_create_session`
            - `public.process_fee_payment`
            - `public.update_room_occupancy`
            - `public.universal_search`
            - `public.get_monthly_attendance_for_student`
          
          ## Security Implications:
          - RLS Status: [Not Applicable for View/Function definitions]
          - Policy Changes: [No]
          - Auth Requirements: [None]
          
          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [None]
          - Estimated Impact: [Negligible. Improves security, which can prevent performance issues from malicious queries.]
          */

-- Drop the view if it exists to ensure a clean recreation
DROP VIEW IF EXISTS public.recent_activities;

-- Recreate the recent_activities view with the correct logic
CREATE OR REPLACE VIEW public.recent_activities AS
-- Student Registrations
SELECT
    p.id AS activity_id,
    'new_student' AS type,
    p.full_name AS primary_subject,
    ('New student ' || p.full_name || ' registered.') AS details,
    p.created_at,
    p.id AS related_profile_id,
    NULL::uuid AS related_room_id
FROM
    public.profiles p
WHERE
    p.role = 'Student'::public.role_type

UNION ALL

-- Room Allocations
SELECT
    ra.id AS activity_id,
    'allocation' AS type,
    p.full_name AS primary_subject,
    (p.full_name || ' was allocated to Room ' || r.room_number) AS details,
    ra.start_date AS created_at,
    ra.student_id AS related_profile_id,
    ra.room_id AS related_room_id
FROM
    public.room_allocations ra
JOIN
    public.profiles p ON ra.student_id = p.id
JOIN
    public.rooms r ON ra.room_id = r.id
WHERE
    ra.is_active = true

UNION ALL

-- Fee Payments
SELECT
    py.id AS activity_id,
    'payment' AS type,
    p.full_name AS primary_subject,
    ('Payment of $' || py.amount || ' received from ' || p.full_name) AS details,
    py.paid_on AS created_at,
    f.student_id AS related_profile_id,
    NULL::uuid AS related_room_id
FROM
    public.payments py
JOIN
    public.fees f ON py.fee_id = f.id
JOIN
    public.profiles p ON f.student_id = p.id

UNION ALL

-- Maintenance Requests
SELECT
    mr.id AS activity_id,
    'maintenance' AS type,
    ('Room ' || mr.room_number) AS primary_subject,
    ('Maintenance requested for Room ' || mr.room_number || ': ' || mr.issue) AS details,
    mr.created_at,
    mr.reported_by_id AS related_profile_id,
    NULL::uuid AS related_room_id
FROM
    public.maintenance_requests mr

UNION ALL

-- Visitor Check-ins
SELECT
    v.id AS activity_id,
    'visitor' AS type,
    v.visitor_name AS primary_subject,
    (v.visitor_name || ' checked in to visit ' || p.full_name) AS details,
    v.check_in_time AS created_at,
    v.student_id AS related_profile_id,
    NULL::uuid AS related_room_id
FROM
    public.visitors v
JOIN
    public.profiles p ON v.student_id = p.id
WHERE
    v.status = 'In';


-- Security Hardening: Set secure search paths for all functions
ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid) SET search_path = public;
ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type public.session_type_enum) SET search_path = public;
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid) SET search_path = public;
ALTER FUNCTION public.update_room_occupancy(p_room_id uuid) SET search_path = public;
ALTER FUNCTION public.universal_search(p_search_term text) SET search_path = public;
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer) SET search_path = public;
