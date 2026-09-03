-- ============================================================================
-- Owanbe identity repair — invify638@gmail.com ONLY
-- Creates/repairs Auth + public identity with all 3 roles GRANTED (activated)
-- but onboarding INCOMPLETE (Hub status = in_progress → Continue Setup).
-- Idempotent. One transaction. Stops with a precise error instead of guessing.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

BEGIN;

-- ---------------------------------------------------------------------------
-- Temp helpers (session-scoped)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.has_rel(p_name text)
RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT to_regclass(p_name) IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION pg_temp.has_col(p_schema text, p_table text, p_col text)
RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = p_schema
      AND table_name = p_table
      AND column_name = p_col
  );
$$;

CREATE OR REPLACE FUNCTION pg_temp.has_unique(p_table text, VARIADIC p_cols text[])
RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = p_table::regclass
      AND c.contype IN ('u', 'p')
      AND (
        SELECT array_agg(att.attname::text ORDER BY u.ord)
        FROM unnest(c.conkey) WITH ORDINALITY AS u(attnum, ord)
        JOIN pg_attribute att
          ON att.attrelid = c.conrelid
         AND att.attnum = u.attnum
      ) = p_cols
  );
$$;

CREATE OR REPLACE FUNCTION pg_temp.insert_filtered(p_schema text, p_table text, p_assignments jsonb)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  cols text;
  vals text;
  missing text;
BEGIN
  SELECT string_agg(quote_ident(e.key), ', ' ORDER BY e.key),
         string_agg(e.value, ', ' ORDER BY e.key)
    INTO cols, vals
  FROM jsonb_each_text(p_assignments) e
  JOIN information_schema.columns c
    ON c.table_schema = p_schema
   AND c.table_name = p_table
   AND c.column_name = e.key
   AND c.is_generated <> 'ALWAYS';

  IF cols IS NULL THEN
    RAISE EXCEPTION 'No insertable columns matched for %.%', p_schema, p_table;
  END IF;

  SELECT string_agg(c.column_name, ', ' ORDER BY c.column_name)
    INTO missing
  FROM information_schema.columns c
  WHERE c.table_schema = p_schema
    AND c.table_name = p_table
    AND c.is_nullable = 'NO'
    AND c.column_default IS NULL
    AND c.is_generated <> 'ALWAYS'
    AND COALESCE(c.is_identity, 'NO') = 'NO'
    AND c.column_name NOT IN (SELECT jsonb_object_keys(p_assignments));

  IF missing IS NOT NULL THEN
    RAISE EXCEPTION
      'Refusing to INSERT %.%: NOT NULL columns have no mapped value and no default: %',
      p_schema, p_table, missing;
  END IF;

  EXECUTE format('INSERT INTO %I.%I (%s) VALUES (%s)', p_schema, p_table, cols, vals);
END;
$$;

-- ---------------------------------------------------------------------------
-- 0) Refuse to run unless canonical BASE identity tables exist.
--    Missing 045–052 objects are created below from the repo migrations.
--    Missing core tables are NOT invented here.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  missing text := '';
BEGIN
  IF NOT pg_temp.has_rel('public.tenants') THEN missing := missing || ' tenants'; END IF;
  IF NOT pg_temp.has_rel('public.users') THEN missing := missing || ' users'; END IF;
  IF NOT pg_temp.has_rel('public.roles') THEN missing := missing || ' roles'; END IF;
  IF NOT pg_temp.has_rel('public.user_roles') THEN missing := missing || ' user_roles'; END IF;
  IF NOT pg_temp.has_rel('public.organizers') THEN missing := missing || ' organizers'; END IF;
  IF NOT pg_temp.has_rel('public.vendors') THEN missing := missing || ' vendors'; END IF;

  IF missing <> '' THEN
    RAISE EXCEPTION
      'This database is missing required Owanbe core identity tables (%). Apply infra/db/owanbe_core.sql and 016_phase5_ticket_commerce_foundation.sql first. Refusing to invent them.',
      missing;
  END IF;

  IF NOT pg_temp.has_col('public', 'users', 'tenant_id')
     OR NOT pg_temp.has_col('public', 'users', 'email')
     OR NOT pg_temp.has_col('public', 'vendors', 'owner_user_id')
     OR NOT pg_temp.has_col('public', 'vendors', 'country_code')
     OR NOT pg_temp.has_col('public', 'organizers', 'owner_user_id')
     OR NOT pg_temp.has_col('public', 'organizers', 'slug') THEN
    RAISE EXCEPTION 'Core identity columns are not the Owanbe schema. Refusing to continue.';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1) Canonical identity DDL (verbatim from 045, 047, 046, 049, 050, 051, 052)
--    All statements are IF NOT EXISTS / guarded. Safe on a fully migrated DB.
-- ---------------------------------------------------------------------------

-- 028 organizer_profiles (CREATE IF NOT EXISTS — no-op when 028 already applied)
CREATE TABLE IF NOT EXISTS organizer_profiles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  user_id         UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  organizer_id    UUID REFERENCES organizers (id) ON DELETE SET NULL,
  display_name    TEXT NOT NULL DEFAULT '',
  organization_name TEXT NOT NULL DEFAULT '',
  phone_e164      TEXT,
  email_verified_at TIMESTAMPTZ,
  phone_verified_at TIMESTAMPTZ,
  onboarding_step TEXT NOT NULL DEFAULT 'profile',
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT organizer_profiles_user_unique UNIQUE (tenant_id, user_id)
);

CREATE INDEX IF NOT EXISTS organizer_profiles_organizer_idx
  ON organizer_profiles (organizer_id);

-- 045_portal_signup.sql + 047_deprecate_signup_portal.sql (canonical end state)
DO $$
BEGIN
  ALTER TABLE users
    ADD COLUMN IF NOT EXISTS onboarding_complete BOOLEAN NOT NULL DEFAULT false;

  -- Reach 047 end state without leaving a stray signup_portal column on re-run.
  IF pg_temp.has_col('public', 'users', 'signup_portal')
     AND NOT pg_temp.has_col('public', 'users', 'signup_portal_deprecated') THEN
    ALTER TABLE users RENAME COLUMN signup_portal TO signup_portal_deprecated;
  ELSIF NOT pg_temp.has_col('public', 'users', 'signup_portal')
     AND NOT pg_temp.has_col('public', 'users', 'signup_portal_deprecated') THEN
    ALTER TABLE users ADD COLUMN signup_portal_deprecated TEXT;
  END IF;

  ALTER TABLE users DROP CONSTRAINT IF EXISTS users_signup_portal_check;
  ALTER TABLE users DROP CONSTRAINT IF EXISTS users_signup_portal_deprecated_check;
  ALTER TABLE users ADD CONSTRAINT users_signup_portal_deprecated_check
    CHECK (signup_portal_deprecated IS NULL OR signup_portal_deprecated IN ('client', 'organizer', 'vendor', 'admin'));

  DROP INDEX IF EXISTS users_signup_portal_lookup_idx;
  CREATE INDEX IF NOT EXISTS users_signup_portal_deprecated_lookup_idx
    ON users (tenant_id, email_normalized)
    WHERE signup_portal_deprecated IS NOT NULL;
END $$;

-- 046_unified_identity.sql
CREATE TABLE IF NOT EXISTS attendee_profiles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  user_id         UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  phone_e164      TEXT,
  country         TEXT,
  state           TEXT,
  city            TEXT,
  interests       JSONB NOT NULL DEFAULT '[]'::JSONB,
  notification_prefs JSONB NOT NULL DEFAULT '{}'::JSONB,
  onboarding_step TEXT NOT NULL DEFAULT 'not_started',
  onboarding_draft JSONB NOT NULL DEFAULT '{}'::JSONB,
  activated_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT attendee_profiles_user_unique UNIQUE (tenant_id, user_id)
);

CREATE INDEX IF NOT EXISTS attendee_profiles_user_idx ON attendee_profiles (user_id);

CREATE TABLE IF NOT EXISTS vendor_profiles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  user_id         UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  vendor_id       UUID REFERENCES vendors (id) ON DELETE SET NULL,
  business_name   TEXT NOT NULL DEFAULT '',
  category        TEXT NOT NULL DEFAULT '',
  country         TEXT,
  state           TEXT,
  city            TEXT,
  bio             TEXT,
  social_links    JSONB NOT NULL DEFAULT '{}'::JSONB,
  onboarding_step TEXT NOT NULL DEFAULT 'not_started',
  onboarding_draft JSONB NOT NULL DEFAULT '{}'::JSONB,
  profile_completion_pct INT NOT NULL DEFAULT 0,
  activated_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendor_profiles_user_unique UNIQUE (tenant_id, user_id)
);

CREATE INDEX IF NOT EXISTS vendor_profiles_user_idx ON vendor_profiles (user_id);

ALTER TABLE organizer_profiles
  ADD COLUMN IF NOT EXISTS onboarding_draft JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS profile_completion_pct INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS activated_at TIMESTAMPTZ;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_active_workspace TEXT;

-- 049_global_user_profile.sql
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS first_name TEXT,
  ADD COLUMN IF NOT EXISTS last_name TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS occupation TEXT,
  ADD COLUMN IF NOT EXISTS company TEXT,
  ADD COLUMN IF NOT EXISTS interests JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS social_links JSONB NOT NULL DEFAULT '{}'::JSONB;

-- 050_attendee_workspace_profile.sql
ALTER TABLE attendee_profiles
  ADD COLUMN IF NOT EXISTS preferred_display_name TEXT,
  ADD COLUMN IF NOT EXISTS preferred_event_categories JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS accessibility_requirements TEXT,
  ADD COLUMN IF NOT EXISTS dietary_preferences TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_name TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_relationship TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS notify_email BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_sms BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS notify_push BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS privacy_show_to_organizers BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS privacy_show_to_attendees BOOLEAN NOT NULL DEFAULT false;

-- 051_organizer_workspace_profile.sql
ALTER TABLE organizer_profiles
  ADD COLUMN IF NOT EXISTS business_type TEXT,
  ADD COLUMN IF NOT EXISTS years_of_experience INT,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS support_email TEXT,
  ADD COLUMN IF NOT EXISTS support_phone TEXT,
  ADD COLUMN IF NOT EXISTS website TEXT,
  ADD COLUMN IF NOT EXISTS social_links JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS business_address TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS country TEXT,
  ADD COLUMN IF NOT EXISTS registration_number TEXT,
  ADD COLUMN IF NOT EXISTS registration_authority TEXT,
  ADD COLUMN IF NOT EXISTS registration_country TEXT,
  ADD COLUMN IF NOT EXISTS tax_id TEXT,
  ADD COLUMN IF NOT EXISTS tax_authority TEXT,
  ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS verification_documents JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

-- 052_vendor_workspace_profile.sql
ALTER TABLE vendor_profiles
  ADD COLUMN IF NOT EXISTS subcategory TEXT,
  ADD COLUMN IF NOT EXISTS years_of_experience INT,
  ADD COLUMN IF NOT EXISTS services_offered JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS service_areas JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS portfolio_images JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS portfolio_videos JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS portfolio_website TEXT,
  ADD COLUMN IF NOT EXISTS starting_price TEXT,
  ADD COLUMN IF NOT EXISTS price_range TEXT,
  ADD COLUMN IF NOT EXISTS team_size INT,
  ADD COLUMN IF NOT EXISTS max_event_capacity INT,
  ADD COLUMN IF NOT EXISTS available_for_bookings BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS advance_booking_notice TEXT,
  ADD COLUMN IF NOT EXISTS business_address TEXT,
  ADD COLUMN IF NOT EXISTS contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS contact_email TEXT,
  ADD COLUMN IF NOT EXISTS verification_documents JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS business_registration_number TEXT,
  ADD COLUMN IF NOT EXISTS tax_id TEXT,
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

-- Unique constraints required by ON CONFLICT (only add if missing)
DO $$
BEGIN
  IF NOT pg_temp.has_unique('organizer_profiles', 'tenant_id', 'user_id') THEN
    ALTER TABLE organizer_profiles
      ADD CONSTRAINT organizer_profiles_user_unique UNIQUE (tenant_id, user_id);
  END IF;
  IF NOT pg_temp.has_unique('attendee_profiles', 'tenant_id', 'user_id') THEN
    ALTER TABLE attendee_profiles
      ADD CONSTRAINT attendee_profiles_user_unique UNIQUE (tenant_id, user_id);
  END IF;
  IF NOT pg_temp.has_unique('vendor_profiles', 'tenant_id', 'user_id') THEN
    ALTER TABLE vendor_profiles
      ADD CONSTRAINT vendor_profiles_user_unique UNIQUE (tenant_id, user_id);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2) Create / repair ONLY invify638@gmail.com
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_email        TEXT := 'invify638@gmail.com';
  v_password     TEXT := '123456';
  v_display      TEXT := 'Invify';
  -- Activation-flow placeholders (email local-part). NOT completed business names.
  v_placeholder  TEXT := 'invify638';
  v_tenant       UUID := '11111111-1111-4111-8111-111111111111';
  v_stable_id    UUID := '63863863-8638-4638-8638-638638638638';
  v_user_id      UUID;
  v_auth_id      UUID;
  v_public_id    UUID;
  v_org_id       UUID;
  v_vendor_id    UUID;
  v_org_slug     TEXT;
  v_vendor_slug  TEXT;
  v_suffix       TEXT;
  v_roles        TEXT[];
  v_pwd_ok       BOOLEAN;
  v_auth_count   INT;
  v_ident_count  INT;
  v_assignments  jsonb;
  v_protected    TEXT[] := ARRAY[
    'vendor@owanbe.dev',
    'attendee@owanbe.dev',
    'organizer@owanbe.dev',
    'admin@owanbe.dev',
    'superadmin@owanbe.dev'
  ];
BEGIN
  IF lower(v_email) = ANY (SELECT lower(x) FROM unnest(v_protected) AS x) THEN
    RAISE EXCEPTION 'Refusing to modify a protected seed account';
  END IF;

  -- Tenant (canonical dev tenant from 029 / seed scripts)
  IF EXISTS (SELECT 1 FROM tenants WHERE slug = 'owanbe-dev' AND id <> v_tenant) THEN
    RAISE EXCEPTION 'Tenant slug owanbe-dev already exists with a different id. Refusing to conflict with %.', v_tenant;
  END IF;

  INSERT INTO tenants (id, slug, name, status)
  VALUES (v_tenant, 'owanbe-dev', 'Owanbe Dev', 'active')
  ON CONFLICT (id) DO UPDATE
    SET status = 'active',
        updated_at = now();

  IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = v_tenant) THEN
    RAISE EXCEPTION 'Tenant % is missing and could not be created', v_tenant;
  END IF;

  -- Resolve UUID: existing auth, else existing public user, else stable id
  IF to_regclass('auth.users') IS NOT NULL THEN
    SELECT id INTO v_auth_id
    FROM auth.users
    WHERE lower(email) = lower(v_email)
    LIMIT 1;
  END IF;

  SELECT id INTO v_public_id
  FROM users
  WHERE lower(trim(email)) = lower(v_email)
  LIMIT 1;

  IF v_auth_id IS NOT NULL AND v_public_id IS NOT NULL AND v_auth_id <> v_public_id THEN
    RAISE EXCEPTION
      'Refusing to merge split identity for %: auth.users.id=% public.users.id=%. Resolve manually — will not rewrite foreign keys.',
      v_email, v_auth_id, v_public_id;
  END IF;

  v_user_id := COALESCE(v_auth_id, v_public_id, v_stable_id);

  -- Roles (025 added organizer; core has client/vendor)
  INSERT INTO roles (code, description) VALUES
    ('client', 'Event host / payer'),
    ('organizer', 'Event organizer operator'),
    ('vendor', 'Service provider')
  ON CONFLICT (code) DO NOTHING;

  -- Auth user (hosted GoTrue). Skipped when auth schema is absent (local API DB).
  IF to_regclass('auth.users') IS NOT NULL THEN
    v_assignments := jsonb_build_object(
      'instance_id', quote_literal('00000000-0000-0000-0000-000000000000') || '::uuid',
      'id', quote_literal(v_user_id::text) || '::uuid',
      'aud', quote_literal('authenticated'),
      'role', quote_literal('authenticated'),
      'email', quote_literal(v_email),
      'encrypted_password', format('crypt(%L, gen_salt(''bf''))', v_password),
      'email_confirmed_at', 'now()',
      'confirmation_token', quote_literal(''),
      'recovery_token', quote_literal(''),
      'email_change', quote_literal(''),
      'email_change_token_new', quote_literal(''),
      'email_change_token_current', quote_literal(''),
      'email_change_token', quote_literal(''),
      'phone_change', quote_literal(''),
      'phone_change_token', quote_literal(''),
      'reauthentication_token', quote_literal(''),
      'email_change_confirm_status', '0',
      'raw_app_meta_data', quote_literal(jsonb_build_object(
        'provider', 'email',
        'providers', jsonb_build_array('email'),
        'tenant_id', v_tenant::text,
        'roles', jsonb_build_array('client', 'organizer', 'vendor'),
        'onboarding_complete', false
      )::text) || '::jsonb',
      'raw_user_meta_data', quote_literal(jsonb_build_object(
        'display_name', v_display
      )::text) || '::jsonb',
      'is_sso_user', 'false',
      'is_anonymous', 'false',
      'is_super_admin', 'false',
      'created_at', 'now()',
      'updated_at', 'now()'
    );

    IF v_auth_id IS NULL THEN
      PERFORM pg_temp.insert_filtered('auth', 'users', v_assignments);
    ELSE
      UPDATE auth.users
      SET
        encrypted_password = crypt(v_password, gen_salt('bf')),
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
          'provider', 'email',
          'providers', COALESCE(raw_app_meta_data->'providers', jsonb_build_array('email')),
          'tenant_id', v_tenant::text,
          'roles', jsonb_build_array('client', 'organizer', 'vendor'),
          'onboarding_complete', false
        ),
        raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
          'display_name', v_display
        ),
        updated_at = now()
      WHERE id = v_user_id;

      IF pg_temp.has_col('auth', 'users', 'confirmation_token') THEN
        UPDATE auth.users SET confirmation_token = COALESCE(confirmation_token, '') WHERE id = v_user_id;
      END IF;
      IF pg_temp.has_col('auth', 'users', 'recovery_token') THEN
        UPDATE auth.users SET recovery_token = COALESCE(recovery_token, '') WHERE id = v_user_id;
      END IF;
      IF pg_temp.has_col('auth', 'users', 'email_change') THEN
        UPDATE auth.users SET email_change = COALESCE(email_change, '') WHERE id = v_user_id;
      END IF;
      IF pg_temp.has_col('auth', 'users', 'email_change_token_new') THEN
        UPDATE auth.users SET email_change_token_new = COALESCE(email_change_token_new, '') WHERE id = v_user_id;
      END IF;
      IF pg_temp.has_col('auth', 'users', 'email_change_token_current') THEN
        UPDATE auth.users SET email_change_token_current = COALESCE(email_change_token_current, '') WHERE id = v_user_id;
      END IF;
      IF pg_temp.has_col('auth', 'users', 'phone_change') THEN
        UPDATE auth.users SET phone_change = COALESCE(phone_change, '') WHERE id = v_user_id;
      END IF;
      IF pg_temp.has_col('auth', 'users', 'phone_change_token') THEN
        UPDATE auth.users SET phone_change_token = COALESCE(phone_change_token, '') WHERE id = v_user_id;
      END IF;
      IF pg_temp.has_col('auth', 'users', 'reauthentication_token') THEN
        UPDATE auth.users SET reauthentication_token = COALESCE(reauthentication_token, '') WHERE id = v_user_id;
      END IF;
    END IF;

    -- Keep a single email identity for this user. Do not touch other accounts.
    IF to_regclass('auth.identities') IS NOT NULL THEN
      DELETE FROM auth.identities a
      WHERE a.user_id = v_user_id
        AND a.provider = 'email'
        AND a.ctid <> (
          SELECT b.ctid
          FROM auth.identities b
          WHERE b.user_id = v_user_id
            AND b.provider = 'email'
          ORDER BY b.created_at NULLS LAST, b.ctid
          LIMIT 1
        );

      IF EXISTS (
        SELECT 1 FROM auth.identities
        WHERE user_id = v_user_id AND provider = 'email'
      ) THEN
        UPDATE auth.identities
        SET
          identity_data = jsonb_build_object(
            'sub', v_user_id::text,
            'email', v_email,
            'email_verified', true,
            'phone_verified', false
          ),
          last_sign_in_at = now(),
          updated_at = now()
        WHERE user_id = v_user_id
          AND provider = 'email';
      ELSE
        v_assignments := jsonb_build_object(
          'provider_id', quote_literal(v_user_id::text),
          'user_id', quote_literal(v_user_id::text) || '::uuid',
          'identity_data', quote_literal(jsonb_build_object(
            'sub', v_user_id::text,
            'email', v_email,
            'email_verified', true,
            'phone_verified', false
          )::text) || '::jsonb',
          'provider', quote_literal('email'),
          'last_sign_in_at', 'now()',
          'created_at', 'now()',
          'updated_at', 'now()'
        );
        IF pg_temp.has_col('auth', 'identities', 'id') THEN
          IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'auth' AND table_name = 'identities'
              AND column_name = 'id' AND data_type = 'uuid'
          ) THEN
            v_assignments := v_assignments || jsonb_build_object('id', 'gen_random_uuid()');
          ELSE
            v_assignments := v_assignments || jsonb_build_object('id', quote_literal(v_user_id::text));
          END IF;
        END IF;
        PERFORM pg_temp.insert_filtered('auth', 'identities', v_assignments);
      END IF;
    END IF;

    SELECT (encrypted_password = crypt(v_password, encrypted_password))
      INTO v_pwd_ok
    FROM auth.users
    WHERE id = v_user_id;

    IF v_pwd_ok IS NOT TRUE THEN
      RAISE EXCEPTION 'Password hash for % did not verify against 123456', v_email;
    END IF;
  ELSE
    RAISE NOTICE 'auth.users is not present — repaired public identity only (id=%). Run this same script in Supabase SQL Editor so Auth uses the same UUID.', v_user_id;
  END IF;

  -- Application user. Roles granted (= activated); onboarding NOT complete.
  -- email_normalized is GENERATED — never inserted.
  INSERT INTO users (id, tenant_id, email, display_name, status, onboarding_complete, last_active_workspace, first_name)
  VALUES (v_user_id, v_tenant, v_email, v_display, 'active', false, NULL, v_display)
  ON CONFLICT (id) DO UPDATE SET
    tenant_id = EXCLUDED.tenant_id,
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    status = 'active',
    onboarding_complete = false,
    last_active_workspace = NULL,
    first_name = COALESCE(NULLIF(users.first_name, ''), EXCLUDED.first_name),
    updated_at = now();

  INSERT INTO user_roles (user_id, role_id)
  SELECT v_user_id, r.id
  FROM roles r
  WHERE r.code IN ('client', 'organizer', 'vendor')
  ON CONFLICT (user_id, role_id) DO NOTHING;

  -- Organizer entity (not auth.users.id). Reuse existing owner row.
  SELECT id INTO v_org_id
  FROM organizers
  WHERE tenant_id = v_tenant AND owner_user_id = v_user_id
  ORDER BY created_at
  LIMIT 1;

  v_suffix := substr(replace(v_user_id::text, '-', ''), 1, 8);
  v_org_slug := 'invify';

  IF v_org_id IS NULL THEN
    IF EXISTS (SELECT 1 FROM organizers WHERE tenant_id = v_tenant AND slug = v_org_slug) THEN
      v_org_slug := 'invify-' || v_suffix;
    END IF;
    INSERT INTO organizers (tenant_id, owner_user_id, display_name, slug, status)
    VALUES (v_tenant, v_user_id, v_placeholder, v_org_slug, 'active')
    RETURNING id INTO v_org_id;
  ELSE
    UPDATE organizers
    SET display_name = v_placeholder,
        status = 'active',
        updated_at = now()
    WHERE id = v_org_id;
  END IF;

  -- Post-activateWorkspace organizer state (in_progress), NOT complete.
  INSERT INTO organizer_profiles (
    tenant_id, user_id, organizer_id, display_name, organization_name,
    onboarding_step, profile_completion_pct, activated_at, onboarding_draft, updated_at
  )
  VALUES (
    v_tenant, v_user_id, v_org_id, v_placeholder, '',
    'profile', 0, NULL, '{}'::jsonb, now()
  )
  ON CONFLICT (tenant_id, user_id) DO UPDATE SET
    organizer_id = COALESCE(organizer_profiles.organizer_id, EXCLUDED.organizer_id),
    display_name = EXCLUDED.display_name,
    organization_name = EXCLUDED.organization_name,
    onboarding_step = 'profile',
    profile_completion_pct = 0,
    activated_at = NULL,
    onboarding_draft = '{}'::jsonb,
    updated_at = now();

  -- Vendor entity (not auth.users.id). Reuse existing owner row.
  SELECT id INTO v_vendor_id
  FROM vendors
  WHERE tenant_id = v_tenant AND owner_user_id = v_user_id
  ORDER BY created_at
  LIMIT 1;

  v_vendor_slug := 'invify-services';

  IF v_vendor_id IS NULL THEN
    IF EXISTS (SELECT 1 FROM vendors WHERE tenant_id = v_tenant AND slug = v_vendor_slug) THEN
      v_vendor_slug := 'invify-services-' || v_suffix;
    END IF;
    INSERT INTO vendors (tenant_id, owner_user_id, business_name, slug, status, country_code, city)
    VALUES (v_tenant, v_user_id, v_placeholder, v_vendor_slug, 'active', 'NG', '')
    RETURNING id INTO v_vendor_id;
  ELSE
    UPDATE vendors
    SET business_name = v_placeholder,
        status = 'active',
        updated_at = now()
    WHERE id = v_vendor_id;
  END IF;

  IF v_vendor_id = v_user_id THEN
    RAISE EXCEPTION 'Vendor id must not equal user/auth id (canonical User → vendor_profiles → vendors.id)';
  END IF;

  -- Post-activateWorkspace vendor state (in_progress), NOT complete.
  INSERT INTO vendor_profiles (
    tenant_id, user_id, vendor_id, business_name,
    onboarding_step, profile_completion_pct, activated_at, onboarding_draft, updated_at
  )
  VALUES (
    v_tenant, v_user_id, v_vendor_id, v_placeholder,
    'personal', 0, NULL, '{}'::jsonb, now()
  )
  ON CONFLICT (tenant_id, user_id) DO UPDATE SET
    vendor_id = COALESCE(vendor_profiles.vendor_id, EXCLUDED.vendor_id),
    business_name = EXCLUDED.business_name,
    onboarding_step = 'personal',
    profile_completion_pct = 0,
    activated_at = NULL,
    onboarding_draft = '{}'::jsonb,
    updated_at = now();

  -- Post-activateWorkspace attendee state (in_progress), NOT complete.
  INSERT INTO attendee_profiles (
    tenant_id, user_id, onboarding_step, activated_at, preferred_display_name, onboarding_draft, updated_at
  )
  VALUES (v_tenant, v_user_id, 'in_progress', NULL, NULL, '{}'::jsonb, now())
  ON CONFLICT (tenant_id, user_id) DO UPDATE SET
    onboarding_step = 'in_progress',
    activated_at = NULL,
    preferred_display_name = NULL,
    onboarding_draft = '{}'::jsonb,
    updated_at = now();

  -- In-transaction verification: IN_PROGRESS (activated roles, incomplete onboarding)
  SELECT array_agg(r.code ORDER BY r.code)
    INTO v_roles
  FROM user_roles ur
  JOIN roles r ON r.id = ur.role_id
  WHERE ur.user_id = v_user_id
    AND r.code IN ('client', 'organizer', 'vendor');

  IF v_roles IS DISTINCT FROM ARRAY['client', 'organizer', 'vendor']::text[] THEN
    RAISE EXCEPTION 'user_roles incomplete for %: %', v_email, v_roles;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = v_user_id AND onboarding_complete = false AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'users.onboarding_complete must be false for %', v_email;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM attendee_profiles
    WHERE user_id = v_user_id AND tenant_id = v_tenant
      AND onboarding_step = 'in_progress' AND activated_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Attendee profile must be in_progress (incomplete) for %', v_email;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM organizer_profiles op
    JOIN organizers o ON o.id = op.organizer_id
    WHERE op.user_id = v_user_id
      AND op.tenant_id = v_tenant
      AND o.owner_user_id = v_user_id
      AND op.onboarding_step = 'profile'
      AND op.profile_completion_pct = 0
      AND op.activated_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Organizer profile must be step=profile incomplete for %', v_email;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM vendor_profiles vp
    JOIN vendors v ON v.id = vp.vendor_id
    WHERE vp.user_id = v_user_id
      AND vp.tenant_id = v_tenant
      AND v.owner_user_id = v_user_id
      AND v.id <> v_user_id
      AND vp.onboarding_step = 'personal'
      AND vp.profile_completion_pct = 0
      AND vp.activated_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Vendor profile must be step=personal incomplete for %', v_email;
  END IF;

  SELECT count(*) INTO v_auth_count FROM users WHERE lower(trim(email)) = lower(v_email);
  IF v_auth_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly 1 public.users row for %, found %', v_email, v_auth_count;
  END IF;

  IF to_regclass('auth.users') IS NOT NULL THEN
    SELECT count(*) INTO v_auth_count FROM auth.users WHERE lower(email) = lower(v_email);
    IF v_auth_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly 1 auth.users row for %, found %', v_email, v_auth_count;
    END IF;
    SELECT count(*) INTO v_ident_count
    FROM auth.identities
    WHERE user_id = v_user_id AND provider = 'email';
    IF v_ident_count <> 1 THEN
      RAISE EXCEPTION 'Expected exactly 1 email auth.identities row for %, found %', v_email, v_ident_count;
    END IF;
  END IF;

  RAISE NOTICE 'Repaired % as IN_PROGRESS user_id=% organizer_id=% vendor_id=% (onboarding incomplete)',
    v_email, v_user_id, v_org_id, v_vendor_id;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.invify_identity_chain()
RETURNS TABLE (
  app_user_id uuid,
  email text,
  tenant_id uuid,
  display_name text,
  status text,
  onboarding_complete boolean,
  last_active_workspace text,
  auth_user_id uuid,
  auth_email text,
  password_matches_123456 boolean,
  jwt_tenant text,
  jwt_roles jsonb,
  email_identities bigint,
  db_roles text[],
  attendee_profile_id uuid,
  attendee_step text,
  attendee_activated_at timestamptz,
  organizer_profile_id uuid,
  organizer_id uuid,
  organizer_owner_user_id uuid,
  organizer_step text,
  organizer_activated_at timestamptz,
  vendor_profile_id uuid,
  vendor_id uuid,
  vendor_owner_user_id uuid,
  vendor_business_name text,
  vendor_step text,
  vendor_activated_at timestamptz,
  vendor_id_is_not_user_id boolean
)
LANGUAGE plpgsql AS $$
BEGIN
  IF to_regclass('auth.users') IS NULL THEN
    RETURN QUERY
    SELECT
      u.id,
      u.email,
      u.tenant_id,
      u.display_name,
      u.status::text,
      u.onboarding_complete,
      u.last_active_workspace,
      NULL::uuid,
      NULL::text,
      NULL::boolean,
      NULL::text,
      NULL::jsonb,
      NULL::bigint,
      (
        SELECT array_agg(r.code ORDER BY r.code)
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = u.id
      ),
      ap.id,
      ap.onboarding_step,
      ap.activated_at,
      op.id,
      op.organizer_id,
      o.owner_user_id,
      op.onboarding_step,
      op.activated_at,
      vp.id,
      vp.vendor_id,
      v.owner_user_id,
      vp.business_name,
      vp.onboarding_step,
      vp.activated_at,
      (vp.vendor_id IS DISTINCT FROM u.id)
    FROM users u
    LEFT JOIN attendee_profiles ap ON ap.user_id = u.id AND ap.tenant_id = u.tenant_id
    LEFT JOIN organizer_profiles op ON op.user_id = u.id AND op.tenant_id = u.tenant_id
    LEFT JOIN organizers o ON o.id = op.organizer_id
    LEFT JOIN vendor_profiles vp ON vp.user_id = u.id AND vp.tenant_id = u.tenant_id
    LEFT JOIN vendors v ON v.id = vp.vendor_id
    WHERE lower(trim(u.email)) = 'invify638@gmail.com';
  ELSE
    RETURN QUERY
    SELECT
      u.id,
      u.email,
      u.tenant_id,
      u.display_name,
      u.status::text,
      u.onboarding_complete,
      u.last_active_workspace,
      au.id,
      au.email::text,
      (au.encrypted_password = crypt('123456', au.encrypted_password)),
      au.raw_app_meta_data->>'tenant_id',
      au.raw_app_meta_data->'roles',
      (SELECT count(*) FROM auth.identities i WHERE i.user_id = au.id AND i.provider = 'email'),
      (
        SELECT array_agg(r.code ORDER BY r.code)
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = u.id
      ),
      ap.id,
      ap.onboarding_step,
      ap.activated_at,
      op.id,
      op.organizer_id,
      o.owner_user_id,
      op.onboarding_step,
      op.activated_at,
      vp.id,
      vp.vendor_id,
      v.owner_user_id,
      vp.business_name,
      vp.onboarding_step,
      vp.activated_at,
      (vp.vendor_id IS DISTINCT FROM u.id)
    FROM users u
    LEFT JOIN auth.users au ON au.id = u.id
    LEFT JOIN attendee_profiles ap ON ap.user_id = u.id AND ap.tenant_id = u.tenant_id
    LEFT JOIN organizer_profiles op ON op.user_id = u.id AND op.tenant_id = u.tenant_id
    LEFT JOIN organizers o ON o.id = op.organizer_id
    LEFT JOIN vendor_profiles vp ON vp.user_id = u.id AND vp.tenant_id = u.tenant_id
    LEFT JOIN vendors v ON v.id = vp.vendor_id
    WHERE lower(trim(u.email)) = 'invify638@gmail.com';
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT * FROM pg_temp.invify_identity_chain();
