-- Owanbe Platform OS / Integration Hub Database Schema
BEGIN;

CREATE TABLE IF NOT EXISTS platform_registry (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_key TEXT NOT NULL UNIQUE,
  label           TEXT NOT NULL,
  category        TEXT NOT NULL, -- 'payment', 'crm', 'messaging', 'accounting'
  version_number  TEXT NOT NULL DEFAULT '1.0.0',
  status          TEXT NOT NULL DEFAULT 'active', -- 'active', 'degraded', 'offline'
  circuit_breaker TEXT NOT NULL DEFAULT 'closed', -- 'closed', 'open', 'half_open'
  credentials     JSONB NOT NULL DEFAULT '{}'::JSONB,
  metrics         JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS platform_api_keys (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id       TEXT NOT NULL UNIQUE,
  client_secret   TEXT NOT NULL,
  scopes          TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  allowed_ips     TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  rate_limit      INT NOT NULL DEFAULT 60,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS platform_event_bus (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic           TEXT NOT NULL,
  payload         JSONB NOT NULL,
  published_by    TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS platform_webhooks (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id       TEXT NOT NULL,
  target_url      TEXT NOT NULL,
  secret_key      TEXT NOT NULL,
  subscribed_topics TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS platform_webhook_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id      UUID NOT NULL REFERENCES platform_webhooks (id) ON DELETE CASCADE,
  topic           TEXT NOT NULL,
  status          TEXT NOT NULL, -- 'success', 'retry_pending', 'failed'
  payload_body    TEXT NOT NULL,
  response_code   INT,
  response_body   TEXT,
  retry_count     INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS platform_plugins (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plugin_key      TEXT NOT NULL UNIQUE,
  manifest        JSONB NOT NULL,
  is_installed    BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed defaults
INSERT INTO platform_registry (integration_key, label, category, metrics) VALUES
  ('stripe', 'Stripe Payments Gateway', 'payment', '{"latencyMs": 142, "errorRate": "0.1%", "healthScore": 99.8}'::JSONB),
  ('paystack', 'Paystack API Broker', 'payment', '{"latencyMs": 95, "errorRate": "0.0%", "healthScore": 100.0}'::JSONB),
  ('salesforce', 'Salesforce CRM Connector', 'crm', '{"latencyMs": 280, "errorRate": "1.4%", "healthScore": 98.2}'::JSONB),
  ('twilio', 'Twilio SMS & Messaging', 'messaging', '{"latencyMs": 122, "errorRate": "0.5%", "healthScore": 99.2}'::JSONB);

INSERT INTO platform_webhooks (client_id, target_url, secret_key, subscribed_topics) VALUES
  ('invify_app', 'https://api.invify.com/hooks/owanbe', 'whsec_invify_99201', ARRAY['TicketPurchased', 'UserCreated']);

COMMIT;
