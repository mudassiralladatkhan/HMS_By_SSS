/*
# [Create Missing Enum Type: session_type_enum]
This migration creates the `session_type_enum` type required for the attendance functionality. An earlier migration failed because it tried to use this type before it was defined. This script safely creates the type if it does not already exist.

## Query Description: [This operation adds a new data type to the database. It is a safe, non-destructive operation that is necessary to fix a migration error. It has no impact on existing data.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [false]

## Structure Details:
- Adds ENUM type `public.session_type_enum` with values ('Morning', 'Evening').

## Security Implications:
- RLS Status: [Not Applicable]
- Policy Changes: [No]
- Auth Requirements: [None]

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: [None]
*/

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'session_type_enum' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) THEN
        CREATE TYPE public.session_type_enum AS ENUM ('Morning', 'Evening');
    END IF;
END$$;
