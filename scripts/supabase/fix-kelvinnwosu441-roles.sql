-- Fix JWT_ROLE_MISMATCH for kelvinnwosu441@gmail.com
-- Error: JWT claims role "client" which is not granted in database
-- Run in Supabase SQL Editor, then retry sign-in (hot restart app if needed).

BEGIN;

DO $$
DECLARE
  v_email   TEXT := 'kelvinnwosu441@gmail.com';
  v_tenant  UUID := '11111111-1111-4111-8111-111111111111';
  v_user_id UUID;
  v_display TEXT := 'Kelvin Nwosu';
BEGIN
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE lower(email) = lower(v_email)
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Auth user not found for %. Run provisioning SQL first.', v_email;
  END IF;

  -- Ensure canonical role codes exist
  INSERT INTO roles (code, description) VALUES
    ('client', 'Event host / payer'),
    ('organizer', 'Event organizer operator'),
    ('vendor', 'Service provider')
  ON CONFLICT (code) DO NOTHING;

  -- Align public.users to the same tenant the mobile app uses
  INSERT INTO users (id, tenant_id, email, display_name, status)
  VALUES (v_user_id, v_tenant, v_email, v_display, 'active')
  ON CONFLICT (id) DO UPDATE SET
    tenant_id = EXCLUDED.tenant_id,
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    status = 'active',
    updated_at = now();

  -- Grant all 3 workspace roles in DB (authoritative for API)
  INSERT INTO user_roles (user_id, role_id)
  SELECT v_user_id, r.id
  FROM roles r
  WHERE r.code IN ('client', 'organizer', 'vendor')
  ON CONFLICT (user_id, role_id) DO NOTHING;

  -- Keep JWT app_metadata in sync (must be subset of DB roles)
  UPDATE auth.users
  SET
    raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object(
        'tenant_id', v_tenant::text,
        'roles', jsonb_build_array('client', 'organizer', 'vendor')
      ),
    email_confirmed_at = COALESCE(email_confirmed_at, now()),
    updated_at = now()
  WHERE id = v_user_id;

  RAISE NOTICE 'Fixed roles for % (user_id=%)', v_email, v_user_id;
END $$;

COMMIT;

-- Verify: db_roles must include client, organizer, vendor
SELECT
  au.email,
  au.raw_app_meta_data->>'tenant_id' AS jwt_tenant,
  u.tenant_id AS db_tenant,
  u.status,
  (
    SELECT array_agg(r.code ORDER BY r.code)
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = au.id
  ) AS db_roles,
  au.raw_app_meta_data->'roles' AS jwt_roles
FROM auth.users au
LEFT JOIN users u ON u.id = au.id
WHERE lower(au.email) = 'kelvinnwosu441@gmail.com';
