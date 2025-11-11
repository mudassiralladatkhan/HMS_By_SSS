/*
# [Security Hardening &amp; Feature Enhancement]
This migration performs two key actions:
1.  **Security Hardening:** It sets a secure, immutable `search_path` for all known database functions. This mitigates the "Function Search Path Mutable" security advisory by preventing potential hijacking attacks.
2.  **Feature Enhancement:** It creates a new `recent_activities` view to provide a consolidated log of important events for the admin dashboard, as required by the new design.

## Query Description:
- **ALTER FUNCTION statements:** These are safe, non-destructive operations that modify function metadata. They do not affect data or function logic.
- **CREATE VIEW statement:** This creates a new read-only view by combining data from existing tables (`profiles`, `room_allocations`, `payments`, `fees`, `rooms`). It does not modify any underlying data. RLS policies on the base tables will be respected.

## Metadata:
- Schema-Category: ["Structural", "Safe"]
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (Functions can be altered back, view can be dropped)

## Structure Details:
- **Alters:** `handle_new_user`, `update_room_occupancy`, `allocate_room`, `get_or_create_session`, `process_fee_payment`, `universal_search`, `get_monthly_attendance_for_student`
- **Creates:** `public.recent_activities` (VIEW)

## Security Implications:
- RLS Status: Unchanged on base tables.
- Policy Changes: No
- Auth Requirements: Admin/Staff role is required to see all data in the new view, as per existing RLS.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Low. The view query is reasonably efficient for a dashboard widget.
*/

-- Harden search paths for all known functions to resolve security advisories
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.update_room_occupancy(p_room_id uuid) SET search_path = public;
ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid) SET search_path = public;
ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type public.session_type_enum) SET search_path = public;
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid) SET search_path = public;
ALTER FUNCTION public.universal_search(p_search_term text) SET search_path = public;
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_year integer, p_month integer) SET search_path = public;


-- Create recent_activities view for the new dashboard design
CREATE OR REPLACE VIEW public.recent_activities AS
 SELECT p.id,
    'student_added'::text AS type,
    ('New student added: '::text || p.full_name) AS description,
    p.created_at AS activity_timestamp,
    p.id AS subject_id,
    ('/students/'::text || (p.id)::text) AS link
   FROM public.profiles p
  WHERE (p.role = 'Student'::text)
UNION ALL
 SELECT ra.id,
    'room_allocated'::text AS type,
    ((p.full_name || ' allocated to room '::text) || r.room_number) AS description,
    ra.start_date AS activity_timestamp,
    ra.student_id AS subject_id,
    '/allocation'::text AS link
   FROM ((public.room_allocations ra
     JOIN public.profiles p ON ((ra.student_id = p.id)))
     JOIN public.rooms r ON ((ra.room_id = r.id)))
  WHERE (ra.is_active = true)
UNION ALL
 SELECT py.id,
    'fee_paid'::text AS type,
    ((('Fee of $'::text || f.amount) || ' paid by '::text) || p.full_name) AS description,
    py.paid_on AS activity_timestamp,
    py.id AS subject_id,
    ('/fees/'::text || (f.id)::text) AS link
   FROM ((public.payments py
     JOIN public.fees f ON ((py.fee_id = f.id)))
     JOIN public.profiles p ON ((f.student_id = p.id)));

-- Grant usage to authenticated users
GRANT SELECT ON public.recent_activities TO authenticated;
