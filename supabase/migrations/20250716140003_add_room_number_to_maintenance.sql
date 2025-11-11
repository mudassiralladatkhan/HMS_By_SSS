/*
  # [Schema Modification] Add room_number to maintenance_requests

  ## Query Description:
  This migration adds a new `room_number` column to the `public.maintenance_requests` table. This column is required by the `recent_activities` view and the application's maintenance feature to associate a maintenance request with a specific room. This is a non-destructive operation and will add the column with NULL values for existing rows.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (The column can be dropped)

  ## Structure Details:
  - Table: `public.maintenance_requests`
  - Column Added: `room_number` (type: `text`)

  ## Security Implications:
  - RLS Status: Unchanged
  - Policy Changes: No
  - Auth Requirements: None

  ## Performance Impact:
  - Indexes: None added
  - Triggers: None added
  - Estimated Impact: Negligible. A metadata lock will be taken on the table briefly.
*/

ALTER TABLE public.maintenance_requests
ADD COLUMN IF NOT EXISTS room_number TEXT;
