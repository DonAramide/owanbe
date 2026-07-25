-- RC Phase 5 — deprecate portal-first signup_portal column (audit-only, no drop)
BEGIN;

ALTER TABLE users RENAME COLUMN signup_portal TO signup_portal_deprecated;

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_signup_portal_check;
ALTER TABLE users ADD CONSTRAINT users_signup_portal_deprecated_check
  CHECK (signup_portal_deprecated IS NULL OR signup_portal_deprecated IN ('client', 'organizer', 'vendor', 'admin'));

DROP INDEX IF EXISTS users_signup_portal_lookup_idx;
CREATE INDEX IF NOT EXISTS users_signup_portal_deprecated_lookup_idx
  ON users (tenant_id, email_normalized)
  WHERE signup_portal_deprecated IS NOT NULL;

COMMENT ON COLUMN users.signup_portal_deprecated IS
  'Deprecated Phase-3 portal lock (audit only). Owanbe 2.0 uses last_active_workspace + workspace profiles.';

COMMIT;
