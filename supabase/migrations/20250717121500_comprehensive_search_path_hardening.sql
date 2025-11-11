/*
# [SECURITY] Comprehensive Function Search Path Hardening
This migration hardens the security of all known database functions by explicitly setting their `search_path`. This mitigates the risk of search path hijacking attacks and resolves the "Function Search Path Mutable" security warnings.

## Query Description: 
This operation alters existing database functions to set a secure `search_path` to 'public'. It is a non-destructive change that improves security and does not affect existing data or function logic.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by resetting the search_path on each function)

## Structure Details:
- Functions affected:
  - `allocate_room(uuid, uuid)`
  - `update_room_occupancy(uuid)`
  - `get_or_create_session(date, public.session_type_enum)`
  - `process_fee_payment(uuid)`
  - `get_monthly_attendance_for_student(uuid, integer, integer)`
  - `universal_search(text)`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: Admin privileges to alter functions.
- Fixes all outstanding "Function Search Path Mutable" warnings.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. This is a metadata change on function definitions.
*/

-- Set search_path for allocate_room
ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid) SET search_path = 'public';

-- Set search_path for update_room_occupancy
ALTER FUNCTION public.update_room_occupancy(p_room_id uuid) SET search_path = 'public';

-- Set search_path for get_or_create_session
ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type public.session_type_enum) SET search_path = 'public';

-- Set search_path for process_fee_payment
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid) SET search_path = 'public';

-- Set search_path for get_monthly_attendance_for_student
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer) SET search_path = 'public';

-- Set search_path for universal_search
ALTER FUNCTION public.universal_search(p_search_term text) SET search_path = 'public';
