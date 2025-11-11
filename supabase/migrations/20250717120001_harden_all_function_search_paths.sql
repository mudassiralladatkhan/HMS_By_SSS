/*
# [SECURITY] Harden Function Search Paths
This migration hardens the security of several database functions by explicitly setting their `search_path`. This prevents potential hijacking attacks where a malicious user could create objects (like tables or functions) in a schema that is searched before the intended one, causing the function to execute unintended code.

## Query Description:
This operation updates the configuration for six existing functions to lock down their search path to `public` and `extensions`. This is a non-destructive security enhancement and does not alter the logic or data of the functions themselves.

- `allocate_room`
- `update_room_occupancy`
- `get_or_create_session`
- `process_fee_payment`
- `universal_search`
- `get_monthly_attendance_for_student`

There is no risk to existing data. This is a safe and recommended security practice.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by unsetting the search_path)

## Structure Details:
- Modifies configuration of 6 functions in the `public` schema.

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates: Function search path hijacking vulnerabilities.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. May slightly improve performance by reducing schema search overhead.
*/

ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid)
SET search_path = public, extensions;

ALTER FUNCTION public.update_room_occupancy(p_room_id uuid)
SET search_path = public, extensions;

ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type public.session_type_enum)
SET search_path = public, extensions;

ALTER FUNCTION public.process_fee_payment(p_fee_id uuid)
SET search_path = public, extensions;

ALTER FUNCTION public.universal_search(p_search_term text)
SET search_path = public, extensions;

-- The get_monthly_attendance_for_student function was identified as having a mutable search path.
-- This ALTER statement hardens its security. The function signature is based on its usage in the application code.
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer)
SET search_path = public, extensions;
