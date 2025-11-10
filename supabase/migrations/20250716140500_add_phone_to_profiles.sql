/*
# [Add Phone Column to Profiles]
This migration adds a `phone` column to the `public.profiles` table to store user contact numbers, which is required by the application but currently missing from the database schema.

## Query Description: [This operation adds a new `phone` column of type TEXT to the `profiles` table. It is non-destructive and will not affect existing data. Existing rows will have a NULL value for this new column until updated.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [true]

## Structure Details:
- Table: `public.profiles`
- Column Added: `phone` (TEXT, NULLABLE)

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No]
- Auth Requirements: [The `profiles` table is protected by RLS. The existing policies should allow users to view and update their own phone number.]

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: [Negligible. Adding a nullable column is a fast metadata-only change.]
*/

ALTER TABLE public.profiles
ADD COLUMN phone TEXT;
