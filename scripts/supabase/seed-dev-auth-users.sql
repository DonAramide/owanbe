-- Owanbe v1.0.1 — dedicated dev accounts (Supabase Dashboard → SQL Editor ONLY).
-- Default password for all: 123456
--
-- Run order if login fails with HTTP 500:
--   1. repair-auth-null-columns.sql
--   2. this file (safe to re-run)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Dedicated user IDs (must match infra/db/029_identity_dev_seed.sql)
-- attendee   22222222-2222-4222-8222-222222222222
-- organizer  33333333-3333-4333-8333-333333333331
-- vendor     55555555-5555-4555-8555-555555555555
-- admin      77777777-7777-4777-8777-777777777777
-- superadmin 88888888-8888-4888-8888-888888888888

DELETE FROM auth.identities
WHERE user_id IN (
  '22222222-2222-4222-8222-222222222222',
  '33333333-3333-4333-8333-333333333331',
  '55555555-5555-4555-8555-555555555555',
  '77777777-7777-4777-8777-777777777777',
  '88888888-8888-4888-8888-888888888888'
);

DELETE FROM auth.users
WHERE id IN (
  '22222222-2222-4222-8222-222222222222',
  '33333333-3333-4333-8333-333333333331',
  '55555555-5555-4555-8555-555555555555',
  '77777777-7777-4777-8777-777777777777',
  '88888888-8888-4888-8888-888888888888'
);

CREATE OR REPLACE FUNCTION _owanbe_seed_auth_user(
  p_id UUID,
  p_email TEXT,
  p_password TEXT,
  p_tenant UUID,
  p_roles JSONB,
  p_display_name TEXT,
  p_phone TEXT DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, phone, phone_confirmed_at,
    confirmation_token, recovery_token,
    email_change, email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token,
    raw_app_meta_data, raw_user_meta_data,
    is_sso_user, is_anonymous, created_at, updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    p_id, 'authenticated', 'authenticated',
    p_email, crypt(p_password, gen_salt('bf')),
    now(), p_phone, CASE WHEN p_phone IS NOT NULL THEN now() ELSE NULL END,
    '', '', '', '', '', '', '', '',
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email'),
      'tenant_id', p_tenant::text,
      'roles', p_roles
    ),
    jsonb_build_object('display_name', p_display_name),
    false, false, now(), now()
  );

  INSERT INTO auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  VALUES (
    p_id::text, p_id,
    jsonb_build_object(
      'sub', p_id::text,
      'email', p_email,
      'email_verified', true,
      'phone_verified', p_phone IS NOT NULL
    ),
    'email', now(), now(), now()
  );
END;
$$;

DO $$
DECLARE
  dev_password TEXT := '123456';
  dev_tenant UUID := '11111111-1111-4111-8111-111111111111';
BEGIN
  PERFORM _owanbe_seed_auth_user(
    '22222222-2222-4222-8222-222222222222',
    'attendee@owanbe.dev', dev_password, dev_tenant,
    jsonb_build_array('client'), 'Ada Attendee', '+2348010000001'
  );
  PERFORM _owanbe_seed_auth_user(
    '33333333-3333-4333-8333-333333333331',
    'organizer@owanbe.dev', dev_password, dev_tenant,
    jsonb_build_array('organizer'), 'Lagos Events Co', '+2348010000002'
  );
  PERFORM _owanbe_seed_auth_user(
    '55555555-5555-4555-8555-555555555555',
    'vendor@owanbe.dev', dev_password, dev_tenant,
    jsonb_build_array('vendor'), 'Golden Pot Catering', '+2348010000003'
  );
  PERFORM _owanbe_seed_auth_user(
    '77777777-7777-4777-8777-777777777777',
    'admin@owanbe.dev', dev_password, dev_tenant,
    jsonb_build_array('admin_super'), 'Platform Admin', NULL
  );
  PERFORM _owanbe_seed_auth_user(
    '88888888-8888-4888-8888-888888888888',
    'superadmin@owanbe.dev', dev_password, dev_tenant,
    jsonb_build_array('super_admin'), 'Owanbe Control Tower', NULL
  );
END $$;

DROP FUNCTION _owanbe_seed_auth_user(UUID, TEXT, TEXT, UUID, JSONB, TEXT, TEXT);

SELECT id, email, raw_app_meta_data->'roles' AS roles, email_confirmed_at IS NOT NULL AS confirmed
FROM auth.users
WHERE email IN (
  'attendee@owanbe.dev',
  'organizer@owanbe.dev',
  'vendor@owanbe.dev',
  'admin@owanbe.dev',
  'superadmin@owanbe.dev'
)
ORDER BY email;
