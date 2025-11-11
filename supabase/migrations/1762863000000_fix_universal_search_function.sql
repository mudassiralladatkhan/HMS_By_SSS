/*
  # [Fix] Recreate universal_search function
  This migration fixes an error caused by an attempt to change the return type of an existing function without dropping it first.
  This script will safely drop the `universal_search` function and then recreate it with the correct definition and a hardened search path.

  ## Query Description:
  - This operation drops the `universal_search` function and immediately recreates it.
  - There is no risk of data loss, but the search feature will be briefly unavailable if called during the migration.
  - This change is necessary to align the function's definition with recent updates.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: false (but the old function can be restored from previous migrations)

  ## Structure Details:
  - Drops function: `public.universal_search(text)`
  - Creates function: `public.universal_search(p_search_term text)`

  ## Security Implications:
  - RLS Status: Not applicable
  - Policy Changes: No
  - Auth Requirements: None
  - Hardens the function's `search_path` to `public`, which is a security best practice.

  ## Performance Impact:
  - Indexes: None
  - Triggers: None
  - Estimated Impact: Negligible.
*/

-- Drop the existing function to allow for recreation with a different return type
DROP FUNCTION IF EXISTS public.universal_search(text);

-- Recreate the function with the correct JSON return type and security settings
CREATE OR REPLACE FUNCTION public.universal_search(p_search_term text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_students json;
  v_rooms json;
BEGIN
  -- Search for students
  SELECT json_agg(
    json_build_object(
      'id', p.id,
      'label', p.full_name || ' (' || p.course || ')',
      'path', '/students/' || p.id::text
    )
  )
  INTO v_students
  FROM public.profiles p
  WHERE p.role = 'Student'
    AND (
      p.full_name ILIKE '%' || p_search_term || '%' OR
      p.email ILIKE '%' || p_search_term || '%' OR
      p.course ILIKE '%' || p_search_term || '%'
    );

  -- Search for rooms
  SELECT json_agg(
    json_build_object(
      'id', r.id,
      'label', 'Room ' || r.room_number || ' (' || r.type || ')',
      'path', '/rooms/' || r.id::text
    )
  )
  INTO v_rooms
  FROM public.rooms r
  WHERE r.room_number ILIKE '%' || p_search_term || '%';

  -- Combine results into a single JSON object
  RETURN json_build_object(
    'students', COALESCE(v_students, '[]'::json),
    'rooms', COALESCE(v_rooms, '[]'::json)
  );
END;
$$;
