/*
          # [Combined Migration] Create View and Harden Security
          This migration creates the `recent_activities` view required for the admin dashboard and hardens the security of several database functions by setting a fixed search path.

          ## Query Description: [This operation creates a new database view and modifies existing functions. It is considered safe and should not impact existing data. The view combines data from multiple tables to create an activity feed. The function alterations are a security best practice.]

          ## Metadata:
          - Schema-Category: ["Structural", "Safe"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]

          ## Structure Details:
          - Creates View: `public.recent_activities`
          - Alters Functions: `allocate_room`, `get_monthly_attendance_for_student`, `process_fee_payment`, `update_room_occupancy`, `universal_search`

          ## Security Implications:
          - RLS Status: [Unaffected]
          - Policy Changes: [No]
          - Auth Requirements: [None]
          - Improves security by setting function search paths.

          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [None]
          - Estimated Impact: [Low. View performance depends on underlying table sizes.]
          */

-- Drop the view if it exists to ensure a clean creation
DROP VIEW IF EXISTS public.recent_activities;

-- Create the recent_activities view
CREATE OR REPLACE VIEW public.recent_activities AS
 SELECT
    p.id,
    p.created_at,
    'new_student'::text AS type,
    (p.full_name || ' registered as a new student.'::text) AS details,
    p.id AS related_id
   FROM public.profiles p
  WHERE (p.role = 'Student'::public.role_type)
UNION ALL
 SELECT
    ra.id,
    ra.start_date AS created_at,
    'allocation'::text AS type,
    ((p.full_name || ' was allocated to Room '::text) || r.room_number) AS details,
    ra.room_id AS related_id
   FROM ((public.room_allocations ra
     JOIN public.profiles p ON ((ra.student_id = p.id)))
     JOIN public.rooms r ON ((ra.room_id = r.id)))
  WHERE (ra.is_active = true)
UNION ALL
 SELECT
    f.id,
    f.created_at,
    'fee_due'::text AS type,
    (((('Fee of $'::text || f.amount) || ' is due for '::text) || p.full_name) || '.'::text) AS details,
    f.id AS related_id
   FROM (public.fees f
     JOIN public.profiles p ON ((f.student_id = p.id)))
  WHERE (f.status = 'Due'::public.fee_status)
UNION ALL
 SELECT
    v.id,
    v.check_in_time AS created_at,
    'visitor'::text AS type,
    (((v.visitor_name || ' checked in to visit '::text) || p.full_name) || '.'::text) AS details,
    v.id AS related_id
   FROM (public.visitors v
     JOIN public.profiles p ON ((v.student_id = p.id)))
  WHERE (v.status = 'In'::public.visitor_status)
UNION ALL
 SELECT
    mr.id,
    mr.created_at,
    'maintenance'::text AS type,
    ('Maintenance requested for Room ' || mr.room_number || ': ' || mr.issue) AS details,
    mr.id AS related_id
   FROM public.maintenance_requests mr
  WHERE (mr.status = 'Pending'::public.maintenance_status);

-- Harden function security
ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid) SET search_path = 'public';
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer) SET search_path = 'public';
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid) SET search_path = 'public';
ALTER FUNCTION public.update_room_occupancy(p_room_id uuid) SET search_path = 'public';
ALTER FUNCTION public.universal_search(p_search_term text) SET search_path = 'public';
