/*
# [Fix] Correct `recent_activities` View Definition
This migration corrects a type casting error in the `recent_activities` view that caused the previous migration to fail.

## Query Description: [This operation fixes a bug in the database view definition. It drops the existing (and possibly broken) view and recreates it with the correct data types. This is a safe, non-destructive operation that only affects a database view and does not touch any underlying data.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [true]

## Structure Details:
- Drops view: `public.recent_activities`
- Creates view: `public.recent_activities`

## Security Implications:
- RLS Status: [N/A]
- Policy Changes: [No]
- Auth Requirements: [None]

## Performance Impact:
- Indexes: [N/A]
- Triggers: [N/A]
- Estimated Impact: [None. View performance will be as intended.]
*/

DROP VIEW IF EXISTS public.recent_activities;

CREATE OR REPLACE VIEW public.recent_activities AS
 SELECT p.id AS activity_id,
    p.created_at AS activity_timestamp,
    'student_joined'::text AS activity_type,
    p.full_name AS primary_subject,
    'Joined the hostel'::text AS details,
    p.id AS reference_id,
    'student'::text AS reference_type
   FROM public.profiles p
  WHERE (p.role = 'Student'::public.role_type)
UNION ALL
 SELECT ra.id AS activity_id,
    ra.start_date AS activity_timestamp,
    'room_allocated'::text AS activity_type,
    p.full_name AS primary_subject,
    ('Allocated to Room '::text || r.room_number) AS details,
    ra.id AS reference_id,
    'allocation'::text AS reference_type
   FROM ((public.room_allocations ra
     JOIN public.profiles p ON ((ra.student_id = p.id)))
     JOIN public.rooms r ON ((ra.room_id = r.id)))
  WHERE (ra.is_active = true)
UNION ALL
 SELECT pay.id AS activity_id,
    pay.paid_on AS activity_timestamp,
    'fee_paid'::text AS activity_type,
    p.full_name AS primary_subject,
    ('Paid $'::text || pay.amount::text) AS details,
    pay.id AS reference_id,
    'payment'::text AS reference_type
   FROM ((public.payments pay
     JOIN public.fees f ON ((pay.fee_id = f.id)))
     JOIN public.profiles p ON ((f.student_id = p.id)))
UNION ALL
 SELECT mr.id AS activity_id,
    mr.created_at AS activity_timestamp,
    'maintenance_requested'::text AS activity_type,
    p.full_name AS primary_subject,
    ((('Requested maintenance for Room '::text || mr.room_number) || ': '::text) || mr.issue) AS details,
    mr.id AS reference_id,
    'maintenance'::text AS reference_type
   FROM (public.maintenance_requests mr
     JOIN public.profiles p ON ((mr.reported_by_id = p.id)))
  ORDER BY 2 DESC
 LIMIT 50;
