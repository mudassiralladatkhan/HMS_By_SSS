/*
# [Fix RLS Recursion]
This migration fixes a critical "stack depth limit exceeded" error caused by recursive Row Level Security (RLS) policies.

## Query Description:
The helper functions `is_admin`, `is_staff`, and `is_student` are redefined to query the `auth.users` table for role information instead of the `public.profiles` table. This breaks the infinite loop where an RLS policy on `profiles` would call a function that queries `profiles` again. This change is safe and does not affect any stored data.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Modifies function: `public.is_admin(uuid)`
- Modifies function: `public.is_staff(uuid)`
- Modifies function: `public.is_student(uuid)`

## Security Implications:
- RLS Status: Enabled
- Policy Changes: No (Functions used by policies are updated)
- Auth Requirements: None

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Positive. Resolves query failures and removes performance bottleneck from recursion.
*/

-- Redefine is_admin to check auth.users, breaking the RLS recursion.
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE id = p_user_id AND raw_user_meta_data->>'role' = 'Admin'
    );
END;
$$;

-- Redefine is_staff to check auth.users, breaking the RLS recursion.
CREATE OR REPLACE FUNCTION public.is_staff(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE id = p_user_id AND raw_user_meta_data->>'role' = 'Staff'
    );
END;
$$;

-- Redefine is_student to check auth.users, breaking the RLS recursion.
CREATE OR REPLACE FUNCTION public.is_student(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE id = p_user_id AND raw_user_meta_data->>'role' = 'Student'
    );
END;
$$;
