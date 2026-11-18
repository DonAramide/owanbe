-- Quasar sandbox linkage for Owanbe.
-- Credentials are ciphertext only. The API accepts sk_test_* only.
-- environment live is rejected. See 075 for the tightened check, audit log, and idempotency keys.
-- Apply after 073_vendor_crm_buyer_context.sql.

BEGIN;

CREATE TABLE IF NOT EXISTS quasar_merchant_accounts (
  id                                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owanbe_tenant_id                    UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  owner_kind                          TEXT NOT NULL CHECK (owner_kind IN ('organizer', 'vendor')),
  owner_id                            UUID NOT NULL,
  quasar_tenant_id                    UUID NOT NULL,
  slug                                TEXT NOT NULL,
  code                                TEXT,
  vertical                            TEXT NOT NULL DEFAULT 'owanbe',
  environment                         TEXT NOT NULL CHECK (environment IN ('test', 'live')),
  api_key_ciphertext                  TEXT NOT NULL,
  api_key_hint                        TEXT NOT NULL,
  wallet_owner_id                     UUID NOT NULL,
  webhook_url                         TEXT,
  webhook_signing_secret_ciphertext   TEXT,
  created_at                          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT quasar_merchant_owner_env_unique UNIQUE (owanbe_tenant_id, owner_kind, owner_id, environment),
  CONSTRAINT quasar_merchant_quasar_tenant_unique UNIQUE (quasar_tenant_id)
);

COMMENT ON TABLE quasar_merchant_accounts IS
  'One Quasar tenant per organizer or vendor wallet. API keys and webhook signing secrets are encrypted at rest.';

COMMENT ON COLUMN quasar_merchant_accounts.api_key_ciphertext IS
  'AES-GCM ciphertext. Sandbox stores sk_test_* only. Never return this column to clients.';

COMMENT ON COLUMN quasar_merchant_accounts.webhook_signing_secret_ciphertext IS
  'AES-GCM ciphertext of the Quasar endpoint signing secret. Never return this column to clients.';

CREATE TABLE IF NOT EXISTS quasar_virtual_accounts (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owanbe_tenant_id      UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  merchant_account_id   UUID NOT NULL REFERENCES quasar_merchant_accounts (id) ON DELETE RESTRICT,
  payer_id              UUID NOT NULL,
  currency              CHAR(3) NOT NULL,
  account_number        TEXT NOT NULL,
  bank_name             TEXT NOT NULL,
  provider_reference    TEXT,
  ticket_payment_id     UUID,
  metadata              JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT quasar_va_payer_currency_unique UNIQUE (merchant_account_id, payer_id, currency)
);

CREATE INDEX IF NOT EXISTS quasar_va_ticket_payment_idx
  ON quasar_virtual_accounts (ticket_payment_id)
  WHERE ticket_payment_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS quasar_transfers (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owanbe_tenant_id      UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  merchant_account_id   UUID NOT NULL REFERENCES quasar_merchant_accounts (id) ON DELETE RESTRICT,
  organizer_payout_id   UUID,
  reference             TEXT NOT NULL,
  amount_major          TEXT NOT NULL,
  currency              CHAR(3) NOT NULL,
  quasar_status         TEXT NOT NULL,
  destination           JSONB NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT quasar_transfers_reference_unique UNIQUE (merchant_account_id, reference)
);

CREATE INDEX IF NOT EXISTS quasar_transfers_payout_idx
  ON quasar_transfers (organizer_payout_id)
  WHERE organizer_payout_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS quasar_webhook_deliveries (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_account_id   UUID NOT NULL REFERENCES quasar_merchant_accounts (id) ON DELETE RESTRICT,
  event_name            TEXT NOT NULL,
  event_key             TEXT NOT NULL,
  payload               JSONB NOT NULL,
  result                TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT quasar_webhook_delivery_unique UNIQUE (merchant_account_id, event_key)
);

COMMIT;
