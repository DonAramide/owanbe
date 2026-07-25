-- Owanbe 2.0 — Unified identity & workspace activation
-- Multi-role support: one user, many workspace profiles.

BEGIN;

-- Attendee workspace profile (lightweight activation)
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

-- Vendor workspace profile (extends vendors table linkage)
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

-- Draft/resume columns on organizer profiles
ALTER TABLE organizer_profiles
  ADD COLUMN IF NOT EXISTS onboarding_draft JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS profile_completion_pct INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS activated_at TIMESTAMPTZ;

-- Track last active workspace per user (optional server-side context)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_active_workspace TEXT;

COMMENT ON TABLE attendee_profiles IS 'Owanbe 2.0 attendee workspace activation profile';
COMMENT ON TABLE vendor_profiles IS 'Owanbe 2.0 vendor workspace activation profile';
COMMENT ON COLUMN users.last_active_workspace IS 'client | organizer | vendor — last UI workspace context';

COMMIT;
