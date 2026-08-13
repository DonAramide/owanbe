-- Phase 24 — Integrations & External Services
-- Registry truth, messaging providers, outbound webhook reliability.

BEGIN;

-- Live registry (replace mock Stripe/Salesforce as source of truth)
ALTER TABLE platform_registry
  ADD COLUMN IF NOT EXISTS provider_type TEXT,
  ADD COLUMN IF NOT EXISTS enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS health_detail TEXT,
  ADD COLUMN IF NOT EXISTS config JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS secrets_ciphertext TEXT,
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES tenants (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS organizer_id UUID REFERENCES organizers (id) ON DELETE CASCADE;

-- Soft-disable mock catalog entries that are not productized
UPDATE platform_registry
SET status = 'offline',
    enabled = false,
    health_detail = 'Unavailable — not productized in Phase 24 (deferred)',
    updated_at = now()
WHERE integration_key IN ('stripe', 'paystack', 'salesforce');

INSERT INTO platform_registry (integration_key, label, category, status, enabled, provider_type, health_detail, metrics)
VALUES
  ('quaser', 'Quaser Payments', 'payment', 'active', true, 'quaser', 'Inbound webhook + router', '{"healthScore": 100}'::JSONB),
  ('enterprise_email', 'Enterprise Email', 'messaging', 'active', true, 'email', 'EmailService / email_providers', '{"healthScore": 100}'::JSONB),
  ('twilio_sms', 'Twilio SMS', 'messaging', 'active', true, 'sms', 'NotificationService SMS adapter', '{"healthScore": 100}'::JSONB),
  ('whatsapp_business', 'WhatsApp Business', 'messaging', 'degraded', true, 'whatsapp', 'Foundation — configure credentials to activate', '{"healthScore": 50}'::JSONB),
  ('supabase_storage', 'Supabase Storage', 'storage', 'active', true, 'storage', 'StorageService media objects', '{"healthScore": 100}'::JSONB),
  ('outbound_webhooks', 'Outbound Webhooks', 'platform', 'active', true, 'webhook', 'Signed partner deliveries', '{"healthScore": 100}'::JSONB)
ON CONFLICT (integration_key) DO UPDATE SET
  label = EXCLUDED.label,
  category = EXCLUDED.category,
  status = EXCLUDED.status,
  enabled = EXCLUDED.enabled,
  provider_type = EXCLUDED.provider_type,
  health_detail = EXCLUDED.health_detail,
  updated_at = now();

-- Messaging provider credentials (SMS / WhatsApp) — secrets encrypted
CREATE TABLE IF NOT EXISTS messaging_providers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID REFERENCES tenants (id) ON DELETE CASCADE,
  organizer_id        UUID REFERENCES organizers (id) ON DELETE CASCADE,
  channel             TEXT NOT NULL CHECK (channel IN ('sms', 'whatsapp')),
  provider_type       TEXT NOT NULL DEFAULT 'twilio',
  name                TEXT NOT NULL,
  enabled             BOOLEAN NOT NULL DEFAULT true,
  is_default          BOOLEAN NOT NULL DEFAULT false,
  from_address        TEXT,
  secrets_ciphertext  TEXT,
  config              JSONB NOT NULL DEFAULT '{}'::JSONB,
  last_error          TEXT,
  created_by          UUID REFERENCES users (id) ON DELETE SET NULL,
  updated_by          UUID REFERENCES users (id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS messaging_providers_platform_default_uidx
  ON messaging_providers (channel)
  WHERE is_default = true AND enabled = true AND tenant_id IS NULL;

CREATE TABLE IF NOT EXISTS messaging_provider_audit (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id     UUID REFERENCES messaging_providers (id) ON DELETE SET NULL,
  actor_user_id   UUID REFERENCES users (id) ON DELETE SET NULL,
  action          TEXT NOT NULL,
  detail          JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Outbound webhooks — tenant/org aware
ALTER TABLE platform_webhooks
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES tenants (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS organizer_id UUID REFERENCES organizers (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS label TEXT,
  ADD COLUMN IF NOT EXISTS max_attempts INT NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Delivery queue with retry / DLQ
CREATE TABLE IF NOT EXISTS platform_webhook_deliveries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id      UUID NOT NULL REFERENCES platform_webhooks (id) ON DELETE CASCADE,
  tenant_id       UUID,
  organizer_id    UUID,
  topic           TEXT NOT NULL,
  payload         JSONB NOT NULL DEFAULT '{}'::JSONB,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'running', 'success', 'retry_pending', 'failed', 'dead_letter')),
  attempts        INT NOT NULL DEFAULT 0,
  max_attempts    INT NOT NULL DEFAULT 5,
  next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_status_code INT,
  last_error      TEXT,
  response_body   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS platform_webhook_deliveries_due_idx
  ON platform_webhook_deliveries (status, next_attempt_at)
  WHERE status IN ('pending', 'retry_pending');

CREATE INDEX IF NOT EXISTS platform_webhook_deliveries_webhook_idx
  ON platform_webhook_deliveries (webhook_id, created_at DESC);

COMMIT;
