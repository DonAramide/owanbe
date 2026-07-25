-- Enterprise Email Infrastructure — provider-agnostic SMTP / API mail config
-- Applied after 047_deprecate_signup_portal.sql

BEGIN;

CREATE TABLE IF NOT EXISTS email_providers (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID REFERENCES tenants (id) ON DELETE CASCADE,
  -- NULL tenant_id = platform-wide (Super Admin) provider
  name                  TEXT NOT NULL,
  provider_type         TEXT NOT NULL,
  -- generic_smtp | zoho_smtp | microsoft_365 | google_workspace
  -- | amazon_ses | sendgrid | mailgun | postmark | custom_smtp | resend
  smtp_host             TEXT,
  smtp_port             INT,
  encryption_mode       TEXT NOT NULL DEFAULT 'starttls',
  -- starttls | ssl | none
  username              TEXT,
  password_ciphertext   TEXT,
  -- AES-256-GCM payload; never returned to clients after save
  api_key_ciphertext    TEXT,
  -- For API providers (SendGrid, Resend, Mailgun, Postmark, SES key)
  sender_name           TEXT NOT NULL DEFAULT 'Owanbe',
  sender_email          TEXT NOT NULL,
  reply_to              TEXT,
  connection_timeout_ms INT NOT NULL DEFAULT 10000,
  retry_attempts        INT NOT NULL DEFAULT 2,
  retry_delay_ms        INT NOT NULL DEFAULT 1000,
  daily_sending_limit   INT,
  enabled               BOOLEAN NOT NULL DEFAULT true,
  is_default            BOOLEAN NOT NULL DEFAULT false,
  priority              INT NOT NULL DEFAULT 100,
  health_status         TEXT NOT NULL DEFAULT 'unknown',
  -- unknown | healthy | degraded | unhealthy
  last_success_at       TIMESTAMPTZ,
  last_failure_at       TIMESTAMPTZ,
  last_error_message    TEXT,
  metadata              JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_by            UUID REFERENCES users (id) ON DELETE SET NULL,
  updated_by            UUID REFERENCES users (id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT email_providers_type_check CHECK (
    provider_type IN (
      'generic_smtp', 'zoho_smtp', 'microsoft_365', 'google_workspace',
      'amazon_ses', 'sendgrid', 'mailgun', 'postmark', 'custom_smtp', 'resend'
    )
  ),
  CONSTRAINT email_providers_encryption_check CHECK (
    encryption_mode IN ('starttls', 'ssl', 'none')
  )
);

CREATE INDEX IF NOT EXISTS email_providers_enabled_priority_idx
  ON email_providers (enabled, is_default DESC, priority ASC)
  WHERE enabled = true;

CREATE UNIQUE INDEX IF NOT EXISTS email_providers_one_platform_default_idx
  ON email_providers (is_default)
  WHERE is_default = true AND tenant_id IS NULL AND enabled = true;

CREATE TABLE IF NOT EXISTS email_provider_audit (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id     UUID REFERENCES email_providers (id) ON DELETE SET NULL,
  actor_user_id   UUID REFERENCES users (id) ON DELETE SET NULL,
  action          TEXT NOT NULL,
  -- created | updated | deleted | enabled | disabled | set_default
  -- | test_connection | test_email | supabase_sync | health_check
  detail          JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS email_provider_audit_provider_idx
  ON email_provider_audit (provider_id, created_at DESC);

COMMENT ON TABLE email_providers IS
  'Enterprise Email Infrastructure — single source of truth for Owanbe business email delivery. Credentials encrypted at rest.';
COMMENT ON COLUMN email_providers.tenant_id IS
  'NULL = platform-wide Super Admin provider; future multi-tenant overrides may set tenant_id.';
COMMENT ON COLUMN email_providers.password_ciphertext IS
  'Never expose decrypted password to API clients.';

COMMIT;
