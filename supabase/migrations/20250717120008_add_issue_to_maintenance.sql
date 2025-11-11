/*
# [Structural] Add issue to maintenance_requests
This operation adds an `issue` text column to the `maintenance_requests` table to store the description of the maintenance problem.

## Query Description: This is a non-destructive operation that adds a new column to an existing table. It will not affect any existing data. The new column will be populated with NULL values for existing rows.

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Table: maintenance_requests
- Column Added: issue (text)

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No]
- Auth Requirements: [None]

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: [Low]
*/
ALTER TABLE public.maintenance_requests
ADD COLUMN IF NOT EXISTS issue TEXT;
