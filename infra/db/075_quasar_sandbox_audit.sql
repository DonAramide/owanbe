-- Quasar sandbox audit, idempotency, and test-only tenant environment.
-- Apply after 074_quasar_sandbox.sql.

BEGIN;

ALTER TABLE quasar_merchant_accounts DROP CONSTRAINT IF EXISTS quasar_merchant_accounts_environment_check;
ALTER TABLE quasar_merchant_accounts
  ADD CONSTRAINT quasar_merchant_accounts_environment_check CHECK (environment = 'test');

COMMENT ON COLUMN quasar_merchant_accounts.environment IS
  'Sandbox phase stores test only. sk_live_* and environment live are rejected by the API.';

CREATE TABLE IF NOT EXISTS quasar_idempotency_keys (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_account_id   UUID NOT NULL REFERENCES quasar_merchant_accounts (id) ON DELETE RESTRICT,
  scope                 TEXT NOT NULL,
  idempotency_key       TEXT NOT NULL,
  response              JSONB NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT quasar_idempotency_unique UNIQUE (merchant_account_id, scope, idempotency_key)
);

COMMENT ON TABLE quasar_idempotency_keys IS
  'Replay store for Quasar money calls. Response JSON must not contain secrets.';

CREATE TABLE IF NOT EXISTS quasar_audit_log (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owanbe_tenant_id      UUID,
  action                TEXT NOT NULL,
  outcome               TEXT NOT NULL,
  reference             TEXT,
  detail                JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS quasar_audit_log_created_idx
  ON quasar_audit_log (created_at DESC);

COMMENT ON TABLE quasar_audit_log IS
  'Quasar integration audit. Detail is redacted before insert. Never store sk_*, qps_*, or qpc_* values.';

COMMIT;
