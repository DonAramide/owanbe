-- Enterprise Communication Platform (ECP) Database Schema
BEGIN;

CREATE TABLE IF NOT EXISTS communication_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_key    TEXT NOT NULL UNIQUE,
  channel         TEXT NOT NULL, -- 'email', 'sms', 'whatsapp', 'push', 'in_app', 'webhook'
  version_number  INT NOT NULL DEFAULT 1,
  status          TEXT NOT NULL DEFAULT 'published', -- 'draft', 'published', 'archived'
  variables       TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  content         JSONB NOT NULL DEFAULT '{}'::JSONB, -- localized contents mapping
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS communication_preferences (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         TEXT NOT NULL UNIQUE,
  allow_email     BOOLEAN NOT NULL DEFAULT true,
  allow_sms       BOOLEAN NOT NULL DEFAULT true,
  allow_whatsapp  BOOLEAN NOT NULL DEFAULT true,
  allow_push      BOOLEAN NOT NULL DEFAULT true,
  allow_marketing BOOLEAN NOT NULL DEFAULT true,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS communication_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id    TEXT NOT NULL,
  template_key    TEXT NOT NULL,
  channel         TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'queued', -- 'queued', 'sent', 'failed', 'bounced'
  payload         JSONB NOT NULL DEFAULT '{}'::JSONB,
  error_message   TEXT,
  retry_count     INT NOT NULL DEFAULT 0,
  correlation_id  TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed core templates
INSERT INTO communication_templates (template_key, channel, version_number, status, variables, content) VALUES
  (
    'welcome_verification',
    'email',
    1,
    'published',
    ARRAY['name', 'code'],
    '{
      "en": {
        "subject": "Welcome to Owanbe, {{name}}!",
        "body": "Hello {{name}},\n\nUse code {{code}} to verify your account."
      }
    }'::JSONB
  ),
  (
    'payout_complete',
    'sms',
    1,
    'published',
    ARRAY['amount', 'bank'],
    '{
      "en": {
        "body": "Alert: Your payout of {{amount}} to {{bank}} was completed successfully."
      }
    }'::JSONB
  ),
  (
    'vendor_approved',
    'whatsapp',
    1,
    'published',
    ARRAY['name'],
    '{
      "en": {
        "body": "Hello {{name}}, congratulations! Your Owanbe vendor portal verification has been approved. You are now active on the marketplace."
      }
    }'::JSONB
  )
ON CONFLICT (template_key) DO UPDATE
  SET content = EXCLUDED.content,
      variables = EXCLUDED.variables;

COMMIT;
