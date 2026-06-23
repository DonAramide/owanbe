-- Owanbe dev Supabase Auth users (Supabase Dashboard → SQL Editor ONLY).
-- Default password: 123456
--
-- Run order if login fails with HTTP 500:
--   1. repair-auth-null-columns.sql
--   2. this file (safe to re-run)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Remove broken partial rows (identities first)
DELETE FROM auth.identities
WHERE user_id IN (
  '22222222-2222-4222-8222-222222222222',
  '77777777-7777-4777-8777-777777777777',
  '88888888-8888-4888-8888-888888888888'
);

DELETE FROM auth.users
WHERE id IN (
  '22222222-2222-4222-8222-222222222222',
  '77777777-7777-4777-8777-777777777777',
  '88888888-8888-4888-8888-888888888888'
);

DO $$
DECLARE
  dev_password TEXT := '123456';
  dev_tenant UUID := '11111111-1111-4111-8111-111111111111';
BEGIN
  -- attendee@owanbe.dev
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at,
    confirmation_token, recovery_token,
    email_change, email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token,
    raw_app_meta_data, raw_user_meta_data,
    is_sso_user, is_anonymous,
    created_at, updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-4222-8222-222222222222',
    'authenticated', 'authenticated',
    'attendee@owanbe.dev',
    crypt(dev_password, gen_salt('bf')),
    now(),
    '', '', '', '', '', '', '', '',
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email'),
      'tenant_id', dev_tenant::text,
      'roles', jsonb_build_array('client', 'organizer', 'vendor')
    ),
    jsonb_build_object('display_name', 'Dev Attendee'),
    false, false,
    now(), now()
  );

  INSERT INTO auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  VALUES (
    '22222222-2222-4222-8222-222222222222',
    '22222222-2222-4222-8222-222222222222',
    jsonb_build_object(
      'sub', '22222222-2222-4222-8222-222222222222',
      'email', 'attendee@owanbe.dev',
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    now(), now(), now()
  );

  -- admin@owanbe.dev
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at,
    confirmation_token, recovery_token,
    email_change, email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token,
    raw_app_meta_data, raw_user_meta_data,
    is_sso_user, is_anonymous,
    created_at, updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    '77777777-7777-4777-8777-777777777777',
    'authenticated', 'authenticated',
    'admin@owanbe.dev',
    crypt(dev_password, gen_salt('bf')),
    now(),
    '', '', '', '', '', '', '', '',
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email'),
      'tenant_id', dev_tenant::text,
      'roles', jsonb_build_array('admin_super')
    ),
    jsonb_build_object('display_name', 'Platform Admin'),
    false, false,
    now(), now()
  );

  INSERT INTO auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  VALUES (
    '77777777-7777-4777-8777-777777777777',
    '77777777-7777-4777-8777-777777777777',
    jsonb_build_object(
      'sub', '77777777-7777-4777-8777-777777777777',
      'email', 'admin@owanbe.dev',
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    now(), now(), now()
  );

  -- superadmin@owanbe.dev
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at,
    confirmation_token, recovery_token,
    email_change, email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token,
    raw_app_meta_data, raw_user_meta_data,
    is_sso_user, is_anonymous,
    created_at, updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    '88888888-8888-4888-8888-888888888888',
    'authenticated', 'authenticated',
    'superadmin@owanbe.dev',
    crypt(dev_password, gen_salt('bf')),
    now(),
    '', '', '', '', '', '', '', '',
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email'),
      'tenant_id', dev_tenant::text,
      'roles', jsonb_build_array('super_admin')
    ),
    jsonb_build_object('display_name', 'Owanbe Control Tower'),
    false, false,
    now(), now()
  );

  INSERT INTO auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  VALUES (
    '88888888-8888-4888-8888-888888888888',
    '88888888-8888-4888-8888-888888888888',
    jsonb_build_object(
      'sub', '88888888-8888-4888-8888-888888888888',
      'email', 'superadmin@owanbe.dev',
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    now(), now(), now()
  );
END $$;

SELECT id, email, email_confirmed_at IS NOT NULL AS confirmed
FROM auth.users
WHERE email IN (
  'attendee@owanbe.dev',
  'admin@owanbe.dev',
  'superadmin@owanbe.dev'
)
ORDER BY email;
