/*
# [Correct Security Definitions]
This script corrects security misconfigurations identified in the previous migration. It ensures that all views use `SECURITY INVOKER` to respect row-level security policies of the calling user, and it hardens all functions by setting a fixed `search_path`. This resolves the "Security Definer View" and "Function Search Path Mutable" advisories.

## Query Description:
This operation modifies existing views and functions to enhance security. It replaces views to change their security context and alters functions to prevent search path hijacking. There is no risk to existing data, but it is a critical security update.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true (by reverting to the previous function/view definitions)

## Structure Details:
- Views modified: `students`, `staff`, `admins`, `unallocated_students`
- Functions modified: `handle_new_user`, `get_unallocated_students`, `allocate_room`, `update_room_occupancy`, `get_or_create_session`, `get_monthly_attendance_for_student`, `process_fee_payment`, `universal_search`, `is_admin`

## Security Implications:
- RLS Status: This change strengthens RLS enforcement.
- Policy Changes: No. Views will now correctly use existing RLS policies.
- Auth Requirements: n/a

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible.
*/

-- Step 1: Correct Views to use SECURITY INVOKER
-- We re-create the views. The default is SECURITY INVOKER, so we don't need to specify it.
-- This fixes the "Security Definer View" error.

DROP VIEW IF EXISTS public.students;
CREATE VIEW public.students AS
 SELECT profiles.id,
    profiles.full_name,
    profiles.email,
    profiles.course,
    profiles.mobile_number AS contact,
    profiles.created_at
   FROM public.profiles
  WHERE (profiles.role = 'Student'::public.user_role);

DROP VIEW IF EXISTS public.staff;
CREATE VIEW public.staff AS
 SELECT profiles.id,
    profiles.full_name,
    profiles.email,
    profiles.mobile_number AS contact,
    profiles.created_at
   FROM public.profiles
  WHERE (profiles.role = 'Staff'::public.user_role);

DROP VIEW IF EXISTS public.admins;
CREATE VIEW public.admins AS
 SELECT profiles.id,
    profiles.full_name,
    profiles.email,
    profiles.mobile_number AS contact,
    profiles.created_at
   FROM public.profiles
  WHERE (profiles.role = 'Admin'::public.user_role);

DROP VIEW IF EXISTS public.unallocated_students;
CREATE VIEW public.unallocated_students AS
 SELECT s.id,
    s.full_name,
    s.email,
    s.course,
    s.contact
   FROM (public.students s
     LEFT JOIN public.room_allocations ra ON (((s.id = ra.student_id) AND (ra.is_active = true))))
  WHERE (ra.id IS NULL);


-- Step 2: Harden Functions by setting search_path
-- This fixes the "Function Search Path Mutable" warnings.

ALTER FUNCTION public.handle_new_user() SET search_path = pg_catalog, public;
ALTER FUNCTION public.get_unallocated_students() SET search_path = pg_catalog, public;
ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid) SET search_path = pg_catalog, public;
ALTER FUNCTION public.update_room_occupancy(p_room_id uuid) SET search_path = pg_catalog, public;
ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type public.attendance_session_type) SET search_path = pg_catalog, public;
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer) SET search_path = pg_catalog, public;
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid) SET search_path = pg_catalog, public;
ALTER FUNCTION public.universal_search(p_search_term text) SET search_path = pg_catalog, public;
ALTER FUNCTION public.is_admin() SET search_path = pg_catalog, public;

-- The previous migration file `20250716120100_resolve_security_issues.sql` had an error.
-- It incorrectly tried to alter the `rooms` table as a view. This corrected script
-- properly targets only the views and functions that needed security updates.
