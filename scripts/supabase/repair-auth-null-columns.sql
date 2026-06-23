-- Fix "Database error querying schema" on login (HTTP 500).
-- GoTrue cannot read NULL in these columns — they must be empty strings.
-- Run in Supabase Dashboard → SQL Editor.

UPDATE auth.users
SET
  confirmation_token = COALESCE(confirmation_token, ''),
  recovery_token = COALESCE(recovery_token, ''),
  email_change = COALESCE(email_change, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  phone_change = COALESCE(phone_change, ''),
  phone_change_token = COALESCE(phone_change_token, ''),
  reauthentication_token = COALESCE(reauthentication_token, '')
WHERE confirmation_token IS NULL
   OR recovery_token IS NULL
   OR email_change IS NULL
   OR email_change_token_new IS NULL
   OR email_change_token_current IS NULL
   OR phone_change IS NULL
   OR phone_change_token IS NULL
   OR reauthentication_token IS NULL;

-- Show any dev users still missing identities (login will fail without these)
SELECT u.email, u.id, i.provider
FROM auth.users u
LEFT JOIN auth.identities i ON i.user_id = u.id
WHERE u.email IN (
  'attendee@owanbe.dev',
  'admin@owanbe.dev',
  'superadmin@owanbe.dev'
)
ORDER BY u.email, i.provider;
