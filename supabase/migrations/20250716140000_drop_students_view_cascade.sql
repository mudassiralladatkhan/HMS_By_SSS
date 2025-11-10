/*
# [Operation] Drop Insecure 'students' View and Dependencies

This script removes the 'public.students' view, which was flagged as a security risk. It uses the CASCADE option to also remove any dependent database functions that are now obsolete.

## Query Description:
- **Safety:** This operation is safe and recommended. The application code has already been updated to query the 'profiles' table directly, so this view and its related functions are no longer needed.
- **Impact:** This will remove the 'students' view and the 'get_unallocated_students' function. There is no risk to your data, as views are virtual tables and do not store data themselves.
- **Action:** Removes outdated and insecure database objects.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: false

## Structure Details:
- **Objects being dropped:**
  - VIEW: public.students
  - FUNCTION: public.get_unallocated_students (and any other dependents)

## Security Implications:
- RLS Status: This action resolves a critical security advisory by removing a SECURITY DEFINER view, strengthening your RLS enforcement.
- Policy Changes: No
- Auth Requirements: Admin privileges required to run.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Positive. Removes unnecessary objects and potential query overhead.
*/
DROP VIEW IF EXISTS public.students CASCADE;
