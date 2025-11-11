/*
# [Security Hardening] Set Function Search Paths
This migration hardens the security of several database functions by explicitly setting their `search_path`. This is a security best practice that mitigates the risk of certain attack vectors by ensuring functions only search for database objects in approved schemas.

## Query Description:
This operation alters existing database functions to set a fixed `search_path`. It is a non-destructive metadata change and does not affect the function's logic or data. This is a safe operation recommended by Supabase security advisories.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by unsetting the search_path)

## Structure Details:
- Functions being modified:
  - `get_monthly_attendance_for_student`
  - `get_or_create_session`
  - `process_fee_payment`
  - `update_room_occupancy`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- This change resolves "Function Search Path Mutable" security warnings.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. This is a metadata change.
*/

-- Harden get_monthly_attendance_for_student function
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer) SET search_path = public;

-- Harden get_or_create_session function
ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type public.session_type_enum) SET search_path = public;

-- Harden process_fee_payment function
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid) SET search_path = public;

-- Harden update_room_occupancy trigger function
ALTER FUNCTION public.update_room_occupancy() SET search_path = public;
