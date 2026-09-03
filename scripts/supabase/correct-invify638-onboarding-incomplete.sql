-- Corrective: invify638@gmail.com — activated (roles) but onboarding INCOMPLETE
-- Affects ONLY this email. Idempotent. Safe to re-run.
-- Paste into Supabase SQL Editor AND/OR run against the API database.

BEGIN;

DO $$
DECLARE
  v_email       TEXT := 'invify638@gmail.com';
  v_user_id     UUID;
  v_tenant      UUID;
  v_org_id      UUID;
  v_vendor_id   UUID;
  v_placeholder TEXT := 'invify638'; -- matches activateWorkspace email-local placeholder
  v_roles       TEXT[];
  v_org_count   INT;
  v_vendor_count INT;
BEGIN
  SELECT id, tenant_id INTO v_user_id, v_tenant
  FROM users
  WHERE lower(trim(email)) = lower(v_email)
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'public.users row not found for %. Run repair-invify638-identity.sql first.', v_email;
  END IF;

  -- users: incomplete onboarding flag only
  UPDATE users
  SET
    onboarding_complete = false,
    last_active_workspace = NULL,
    updated_at = now()
  WHERE id = v_user_id
    AND lower(trim(email)) = lower(v_email);

  -- Auth metadata: keep roles; force onboarding_complete false if column/key present
  IF to_regclass('auth.users') IS NOT NULL THEN
    UPDATE auth.users
    SET
      raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
        || jsonb_build_object(
          'tenant_id', v_tenant::text,
          'roles', jsonb_build_array('client', 'organizer', 'vendor'),
          'onboarding_complete', false
        ),
      updated_at = now()
    WHERE id = v_user_id
      AND lower(email) = lower(v_email);
  END IF;

  -- Attendee: retain row; post-activate incomplete state
  UPDATE attendee_profiles
  SET
    onboarding_step = 'in_progress',
    activated_at = NULL,
    preferred_display_name = NULL,
    onboarding_draft = '{}'::jsonb,
    updated_at = now()
  WHERE user_id = v_user_id AND tenant_id = v_tenant;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'attendee_profiles missing for % — refusing to invent a new identity chain', v_email;
  END IF;

  -- Organizer profile: retain organizer_id; incomplete
  SELECT organizer_id INTO v_org_id
  FROM organizer_profiles
  WHERE user_id = v_user_id AND tenant_id = v_tenant;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'organizer_profiles missing or organizer_id NULL for %', v_email;
  END IF;

  UPDATE organizer_profiles
  SET
    onboarding_step = 'profile',
    profile_completion_pct = 0,
    activated_at = NULL,
    display_name = v_placeholder,
    organization_name = '',
    onboarding_draft = '{}'::jsonb,
    updated_at = now()
  WHERE user_id = v_user_id AND tenant_id = v_tenant;

  -- Soften organizer entity display to activation placeholder (same row, no recreate)
  UPDATE organizers
  SET
    display_name = v_placeholder,
    updated_at = now()
  WHERE id = v_org_id AND owner_user_id = v_user_id;

  -- Vendor profile: retain vendor_id; incomplete
  SELECT vendor_id INTO v_vendor_id
  FROM vendor_profiles
  WHERE user_id = v_user_id AND tenant_id = v_tenant;

  IF v_vendor_id IS NULL THEN
    RAISE EXCEPTION 'vendor_profiles missing or vendor_id NULL for %', v_email;
  END IF;

  IF v_vendor_id = v_user_id THEN
    RAISE EXCEPTION 'Refusing to proceed: vendor_id equals user_id for %', v_email;
  END IF;

  UPDATE vendor_profiles
  SET
    onboarding_step = 'personal',
    profile_completion_pct = 0,
    activated_at = NULL,
    business_name = v_placeholder,
    onboarding_draft = '{}'::jsonb,
    updated_at = now()
  WHERE user_id = v_user_id AND tenant_id = v_tenant;

  UPDATE vendors
  SET
    business_name = v_placeholder,
    updated_at = now()
  WHERE id = v_vendor_id AND owner_user_id = v_user_id;

  -- Roles must remain
  SELECT array_agg(r.code ORDER BY r.code)
    INTO v_roles
  FROM user_roles ur
  JOIN roles r ON r.id = ur.role_id
  WHERE ur.user_id = v_user_id
    AND r.code IN ('client', 'organizer', 'vendor');

  IF v_roles IS DISTINCT FROM ARRAY['client', 'organizer', 'vendor']::text[] THEN
    RAISE EXCEPTION 'Roles changed unexpectedly for %: %', v_email, v_roles;
  END IF;

  SELECT count(*) INTO v_org_count
  FROM organizers WHERE owner_user_id = v_user_id AND tenant_id = v_tenant;
  SELECT count(*) INTO v_vendor_count
  FROM vendors WHERE owner_user_id = v_user_id AND tenant_id = v_tenant;

  IF v_org_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly 1 organizer entity for %, found %', v_email, v_org_count;
  END IF;
  IF v_vendor_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly 1 vendor entity for %, found %', v_email, v_vendor_count;
  END IF;

  -- In-progress state checks
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = v_user_id AND onboarding_complete = false AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'users.onboarding_complete must be false';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM attendee_profiles
    WHERE user_id = v_user_id AND onboarding_step = 'in_progress' AND activated_at IS NULL
  ) THEN
    RAISE EXCEPTION 'attendee_profiles not in in_progress state';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM organizer_profiles
    WHERE user_id = v_user_id
      AND organizer_id = v_org_id
      AND onboarding_step = 'profile'
      AND profile_completion_pct = 0
      AND activated_at IS NULL
  ) THEN
    RAISE EXCEPTION 'organizer_profiles not in profile/in-progress state';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM vendor_profiles
    WHERE user_id = v_user_id
      AND vendor_id = v_vendor_id
      AND vendor_id <> v_user_id
      AND onboarding_step = 'personal'
      AND profile_completion_pct = 0
      AND activated_at IS NULL
  ) THEN
    RAISE EXCEPTION 'vendor_profiles not in personal/in-progress state';
  END IF;

  RAISE NOTICE 'Corrected % user_id=% organizer_id=% vendor_id=% (onboarding incomplete)',
    v_email, v_user_id, v_org_id, v_vendor_id;
END $$;

COMMIT;

-- Verification
SELECT
  u.id AS user_id,
  u.email,
  u.onboarding_complete,
  u.status,
  u.display_name,
  (
    SELECT array_agg(r.code ORDER BY r.code)
    FROM user_roles ur JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = u.id
  ) AS roles,
  ap.onboarding_step AS attendee_step,
  ap.activated_at AS attendee_activated_at,
  op.onboarding_step AS organizer_step,
  op.profile_completion_pct AS organizer_pct,
  op.activated_at AS organizer_activated_at,
  op.organizer_id,
  op.display_name AS organizer_profile_display,
  vp.onboarding_step AS vendor_step,
  vp.profile_completion_pct AS vendor_pct,
  vp.activated_at AS vendor_activated_at,
  vp.vendor_id,
  vp.business_name AS vendor_profile_business,
  (vp.vendor_id IS DISTINCT FROM u.id) AS vendor_id_not_user_id,
  (SELECT count(*) FROM organizers o WHERE o.owner_user_id = u.id) AS organizer_entity_count,
  (SELECT count(*) FROM vendors v WHERE v.owner_user_id = u.id) AS vendor_entity_count
FROM users u
JOIN attendee_profiles ap ON ap.user_id = u.id AND ap.tenant_id = u.tenant_id
JOIN organizer_profiles op ON op.user_id = u.id AND op.tenant_id = u.tenant_id
JOIN vendor_profiles vp ON vp.user_id = u.id AND vp.tenant_id = u.tenant_id
WHERE lower(trim(u.email)) = 'invify638@gmail.com';
