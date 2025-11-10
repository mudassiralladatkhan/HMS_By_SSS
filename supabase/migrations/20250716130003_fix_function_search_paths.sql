/*
  # [SECURITY] Set search_path for allocate_room
  [Sets a fixed, secure search_path for the function to prevent hijacking.]

  ## Query Description: [This operation modifies the `allocate_room` function to explicitly set its `search_path`. This is a security best practice that prevents potential hijacking attacks where a user could create objects (like tables or functions) with the same names in a different schema, causing the function to execute unintended code. This change does not affect existing data and is considered safe.]
  
  ## Metadata:
  - Schema-Category: ["Security"]
  - Impact-Level: ["Low"]
  - Requires-Backup: [false]
  - Reversible: [true]
  
  ## Structure Details:
  - Function: `allocate_room(uuid, uuid)`
  
  ## Security Implications:
  - RLS Status: [N/A]
  - Policy Changes: [No]
  - Auth Requirements: [N/A]
  
  ## Performance Impact:
  - Indexes: [N/A]
  - Triggers: [N/A]
  - Estimated Impact: [None]
*/
ALTER FUNCTION public.allocate_room(p_student_id uuid, p_room_id uuid) SET search_path = 'public';

/*
  # [SECURITY] Set search_path for get_monthly_attendance_for_student
  [Sets a fixed, secure search_path for the function to prevent hijacking.]

  ## Query Description: [This operation modifies the `get_monthly_attendance_for_student` function to explicitly set its `search_path`. This is a security best practice that prevents potential hijacking attacks. This change does not affect existing data and is considered safe.]
  
  ## Metadata:
  - Schema-Category: ["Security"]
  - Impact-Level: ["Low"]
  - Requires-Backup: [false]
  - Reversible: [true]
  
  ## Structure Details:
  - Function: `get_monthly_attendance_for_student(uuid, integer, integer)`
  
  ## Security Implications:
  - RLS Status: [N/A]
  - Policy Changes: [No]
  - Auth Requirements: [N/A]
  
  ## Performance Impact:
  - Indexes: [N/A]
  - Triggers: [N/A]
  - Estimated Impact: [None]
*/
ALTER FUNCTION public.get_monthly_attendance_for_student(p_student_id uuid, p_month integer, p_year integer) SET search_path = 'public';

/*
  # [SECURITY] Set search_path for get_or_create_session
  [Sets a fixed, secure search_path for the function to prevent hijacking.]

  ## Query Description: [This operation modifies the `get_or_create_session` function to explicitly set its `search_path`. This is a security best practice that prevents potential hijacking attacks. This change does not affect existing data and is considered safe.]
  
  ## Metadata:
  - Schema-Category: ["Security"]
  - Impact-Level: ["Low"]
  - Requires-Backup: [false]
  - Reversible: [true]
  
  ## Structure Details:
  - Function: `get_or_create_session(date, text)`
  
  ## Security Implications:
  - RLS Status: [N/A]
  - Policy Changes: [No]
  - Auth Requirements: [N/A]
  
  ## Performance Impact:
  - Indexes: [N/A]
  - Triggers: [N/A]
  - Estimated Impact: [None]
*/
ALTER FUNCTION public.get_or_create_session(p_date date, p_session_type text) SET search_path = 'public';

/*
  # [SECURITY] Set search_path for handle_new_user
  [Sets a fixed, secure search_path for the trigger function to prevent hijacking.]

  ## Query Description: [This operation modifies the `handle_new_user` trigger function to explicitly set its `search_path`. This is a security best practice that prevents potential hijacking attacks. This change does not affect existing data and is considered safe.]
  
  ## Metadata:
  - Schema-Category: ["Security"]
  - Impact-Level: ["Low"]
  - Requires-Backup: [false]
  - Reversible: [true]
  
  ## Structure Details:
  - Function: `handle_new_user()`
  
  ## Security Implications:
  - RLS Status: [N/A]
  - Policy Changes: [No]
  - Auth Requirements: [N/A]
  
  ## Performance Impact:
  - Indexes: [N/A]
  - Triggers: [N/A]
  - Estimated Impact: [None]
*/
ALTER FUNCTION public.handle_new_user() SET search_path = 'public';

/*
  # [SECURITY] Set search_path for process_fee_payment
  [Sets a fixed, secure search_path for the function to prevent hijacking.]

  ## Query Description: [This operation modifies the `process_fee_payment` function to explicitly set its `search_path`. This is a security best practice that prevents potential hijacking attacks. This change does not affect existing data and is considered safe.]
  
  ## Metadata:
  - Schema-Category: ["Security"]
  - Impact-Level: ["Low"]
  - Requires-Backup: [false]
  - Reversible: [true]
  
  ## Structure Details:
  - Function: `process_fee_payment(uuid)`
  
  ## Security Implications:
  - RLS Status: [N/A]
  - Policy Changes: [No]
  - Auth Requirements: [N/A]
  
  ## Performance Impact:
  - Indexes: [N/A]
  - Triggers: [N/A]
  - Estimated Impact: [None]
*/
ALTER FUNCTION public.process_fee_payment(p_fee_id uuid) SET search_path = 'public';

/*
  # [SECURITY] Set search_path for universal_search
  [Sets a fixed, secure search_path for the function to prevent hijacking.]

  ## Query Description: [This operation modifies the `universal_search` function to explicitly set its `search_path`. This is a security best practice that prevents potential hijacking attacks. This change does not affect existing data and is considered safe.]
  
  ## Metadata:
  - Schema-Category: ["Security"]
  - Impact-Level: ["Low"]
  - Requires-Backup: [false]
  - Reversible: [true]
  
  ## Structure Details:
  - Function: `universal_search(text)`
  
  ## Security Implications:
  - RLS Status: [N/A]
  - Policy Changes: [No]
  - Auth Requirements: [N/A]
  
  ## Performance Impact:
  - Indexes: [N/A]
  - Triggers: [N/A]
  - Estimated Impact: [None]
*/
ALTER FUNCTION public.universal_search(p_search_term text) SET search_path = 'public';

/*
  # [SECURITY] Set search_path for update_room_occupancy
  [Sets a fixed, secure search_path for the function to prevent hijacking.]

  ## Query Description: [This operation modifies the `update_room_occupancy` function to explicitly set its `search_path`. This is a security best practice that prevents potential hijacking attacks. This change does not affect existing data and is considered safe.]
  
  ## Metadata:
  - Schema-Category: ["Security"]
  - Impact-Level: ["Low"]
  - Requires-Backup: [false]
  - Reversible: [true]
  
  ## Structure Details:
  - Function: `update_room_occupancy(uuid)`
  
  ## Security Implications:
  - RLS Status: [N/A]
  - Policy Changes: [No]
  - Auth Requirements: [N/A]
  
  ## Performance Impact:
  - Indexes: [N/A]
  - Triggers: [N/A]
  - Estimated Impact: [None]
*/
ALTER FUNCTION public.update_room_occupancy(p_room_id uuid) SET search_path = 'public';
