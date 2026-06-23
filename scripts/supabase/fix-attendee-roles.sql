-- Ensure attendee@owanbe.dev has client role for public /auth sign-in.
-- Run in Supabase SQL Editor if you see "missing the Attendee role".

UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object(
    'tenant_id', '11111111-1111-4111-8111-111111111111',
    'roles', jsonb_build_array('client', 'organizer', 'vendor')
  )
WHERE email = 'attendee@owanbe.dev';

SELECT email, raw_app_meta_data->'roles' AS roles
FROM auth.users
WHERE email = 'attendee@owanbe.dev';
