-- Phase 3 — immutable portal signup (one email = one portal role)
BEGIN;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS signup_portal TEXT,
  ADD COLUMN IF NOT EXISTS onboarding_complete BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_signup_portal_check;
ALTER TABLE users ADD CONSTRAINT users_signup_portal_check
  CHECK (signup_portal IS NULL OR signup_portal IN ('client', 'organizer', 'vendor', 'admin'));

CREATE INDEX IF NOT EXISTS users_signup_portal_lookup_idx
  ON users (tenant_id, email_normalized)
  WHERE signup_portal IS NOT NULL;

COMMENT ON COLUMN users.signup_portal IS
  'Immutable portal chosen at first signup (client|organizer|vendor|admin).';
COMMENT ON COLUMN users.onboarding_complete IS
  'True when portal-specific onboarding is finished (organizer profile, vendor KYC, etc.).';

COMMIT;
