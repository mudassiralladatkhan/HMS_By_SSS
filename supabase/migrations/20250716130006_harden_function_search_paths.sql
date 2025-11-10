/*
# [SECURITY] Harden Function Search Paths
This migration hardens the security of several database functions by setting a non-mutable search_path. This mitigates the risk of search path hijacking attacks, as recommended by Supabase security advisories.

## Query Description:
This operation alters existing functions to explicitly set their `search_path` to `public`. It is a non-destructive, safe operation that enhances security without changing function logic or impacting data.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by unsetting the search_path)

## Structure Details:
- Functions affected:
  - allocate_room(uuid, uuid)
  - get_monthly_attendance_for_student(uuid, integer, integer)
  - get_or_create_session(date, text)
  - handle_new_user()
  - process_fee_payment(uuid)
  - universal_search(text)
  - update_room_occupancy(uuid)

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates: Search path hijacking vulnerabilities for the listed functions.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. May provide a minor performance improvement due to a more direct schema resolution path.
*/

-- Set secure search path for the allocate_room function
ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid)
SET search_path = public;

-- Set secure search path for the get_monthly_attendance_for_student function
-- This function may be deprecated but is altered for security.
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer)
SET search_path = public;

-- Set secure search path for the get_or_create_session function
ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type text)
SET search_path = public;

-- Set secure search path for the handle_new_user trigger function
ALTER FUNCTION public.handle_new_user()
SET search_path = public;

-- Set secure search path for the process_fee_payment function
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid)
SET search_path = public;

-- Set secure search path for the universal_search function
ALTER FUNCTION public.universal_search(p_search_term text)
SET search_path = public;

-- Set secure search path for the update_room_occupancy function
ALTER FUNCTION public.update_room_occupancy(p_room_id uuid)
SET search_path = public;
