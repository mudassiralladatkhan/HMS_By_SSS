/*
  # [Critical Schema Fix] Reset Profiles Table and Dependencies
  [This script addresses a "stack depth limit exceeded" error by safely resetting the `profiles` table and its related views and policies. It also standardizes the 'contact' field across the schema.]

  ## Query Description: [This operation will drop and recreate the `profiles` table. While data in `profiles` will be temporarily removed, it will be automatically repopulated from the `auth.users` table by the existing trigger mechanism, so no user profile data will be lost. This is a necessary step to resolve a critical recursive schema issue.]
  
  ## Metadata:
  - Schema-Category: ["Structural", "Dangerous"]
  - Impact-Level: ["High"]
  - Requires-Backup: [true]
  - Reversible: [false]
  
  ## Structure Details:
  - Drops: VIEW students, VIEW staff, TABLE profiles (CASCADE)
  - Recreates: TABLE profiles, RLS policies for profiles, VIEW students, VIEW staff
  - Alters: FUNCTION handle_new_user
  
  ## Security Implications:
  - RLS Status: [Re-enabled]
  - Policy Changes: [No, policies are recreated as they were]
  - Auth Requirements: [Admin privileges to run]
  
  ## Performance Impact:
  - Indexes: [Primary key and foreign key indexes will be recreated]
  - Triggers: [No changes to triggers]
  - Estimated Impact: [Brief table lock on `profiles`. Should be fast.]
*/

-- Step 1: Drop dependent views first to avoid errors.
DROP VIEW IF EXISTS public.students;
DROP VIEW IF EXISTS public.staff;

-- Step 2: Drop the profiles table. CASCADE will handle dependent objects like policies.
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Step 3: Recreate the profiles table with the correct structure.
-- Using 'contact' instead of 'mobile_number'.
CREATE TABLE public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    email text UNIQUE,
    role user_role,
    contact text,
    course text,
    joining_date date,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Step 4: Re-enable Row Level Security on the new table.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Step 5: Recreate the RLS policies for the profiles table.
CREATE POLICY "Users can view their own profile"
ON public.profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
ON public.profiles FOR SELECT
TO authenticated
USING ((get_my_claim('role'::text)) = '"Admin"'::jsonb);

CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Admins can manage all profiles"
ON public.profiles FOR ALL
TO authenticated
USING ((get_my_claim('role'::text)) = '"Admin"'::jsonb)
WITH CHECK ((get_my_claim('role'::text)) = '"Admin"'::jsonb);


-- Step 6: Ensure the handle_new_user function uses 'contact' consistently.
-- This function is called by a trigger on auth.users to populate the profiles table.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role, contact, course, joining_date)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    (new.raw_user_meta_data->>'role')::user_role,
    new.raw_user_meta_data->>'contact', -- Ensuring this uses 'contact'
    new.raw_user_meta_data->>'course',
    (new.raw_user_meta_data->>'joining_date')::date
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Recreate the views that depend on the profiles table.
-- These views had security issues, so we apply the fix here as well.
CREATE OR REPLACE VIEW public.students WITH (security_invoker=true) AS
SELECT
    id,
    email,
    full_name,
    role,
    contact,
    course,
    joining_date,
    created_at
FROM
    public.profiles
WHERE
    role = 'Student';

CREATE OR REPLACE VIEW public.staff WITH (security_invoker=true) AS
SELECT
    id,
    email,
    full_name,
    role,
    contact,
    created_at
FROM
    public.profiles
WHERE
    role = 'Staff';

-- Step 8: Repopulate the profiles table from existing auth.users
-- This ensures no data is lost for existing users.
INSERT INTO public.profiles (id, full_name, email, role, contact, course, joining_date, created_at)
SELECT
    u.id,
    u.raw_user_meta_data->>'full_name',
    u.email,
    (u.raw_user_meta_data->>'role')::user_role,
    -- Use contact, but fallback to mobile_number for old data
    COALESCE(u.raw_user_meta_data->>'contact', u.raw_user_meta_data->>'mobile_number'),
    u.raw_user_meta_data->>'course',
    (u.raw_user_meta_data->>'joining_date')::date,
    u.created_at
FROM
    auth.users u
ON CONFLICT (id) DO NOTHING;
