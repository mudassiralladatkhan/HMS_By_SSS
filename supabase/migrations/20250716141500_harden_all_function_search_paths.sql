/*
# [SECURITY] Harden All Function Search Paths
This migration explicitly sets the `search_path` for all known custom functions in the database to prevent potential search path hijacking vulnerabilities.

## Query Description:
This is a non-destructive security hardening measure. It ensures that when functions are executed, they only look for tables and other objects in the `public` schema, preventing them from being tricked into using malicious objects from other schemas. This operation has no impact on existing data and is fully reversible.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Modifies the configuration of the following functions:
  - allocate_room(uuid, uuid)
  - get_or_create_session(date, public.session_type_enum)
  - process_fee_payment(uuid)
  - universal_search(text)
  - update_room_occupancy(uuid)

## Security Implications:
- RLS Status: Not Affected
- Policy Changes: No
- Auth Requirements: None
- Mitigates: CVE-2018-1058 (Search Path Hijacking)

## Performance Impact:
- Indexes: Not Affected
- Triggers: Not Affected
- Estimated Impact: Negligible. This is a configuration change.
*/

ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid) SET search_path = 'public';
ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type public.session_type_enum) SET search_path = 'public';
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid) SET search_path = 'public';
ALTER FUNCTION public.universal_search(p_search_term text) SET search_path = 'public';
ALTER FUNCTION public.update_room_occupancy(p_room_id uuid) SET search_path = 'public';
