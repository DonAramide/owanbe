-- QFE Sprint S5: financial_transactions + treasury settlement dual-write anchors.
-- Apply after 014_dispute_resolution_system.sql (and prior ledger/payout migrations).
-- ledger_lines remain the immutable ledger_entries (QFE v1.0 legacy ledger).

BEGIN;

CREATE TYPE financial_transaction_kind AS ENUM (
  'treasury_settlement'
);

CREATE TYPE financial_transaction_status AS ENUM (
  'pending',
  'posted',
  'failed'
);

CREATE TABLE financial_transactions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  kind                  financial_transaction_kind NOT NULL,
  status                financial_transaction_status NOT NULL DEFAULT 'pending',
  idempotency_key       TEXT NOT NULL,
  settlement_reference  TEXT NOT NULL,
  currency              CHAR(3) NOT NULL,
  amount_minor          BIGINT NOT NULL CHECK (amount_minor >= 0),
  booking_id            UUID REFERENCES bookings (id) ON DELETE RESTRICT,
  payment_id            UUID REFERENCES payments (id) ON DELETE RESTRICT,
  payout_id             UUID REFERENCES payouts (id) ON DELETE RESTRICT,
  ledger_transaction_id UUID REFERENCES ledger_transactions (id) ON DELETE RESTRICT,
  metadata              JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT financial_transactions_idempotency_unique UNIQUE (tenant_id, idempotency_key),
  CONSTRAINT financial_transactions_settlement_ref_unique UNIQUE (tenant_id, settlement_reference)
);

CREATE INDEX financial_transactions_tenant_kind_created_idx
  ON financial_transactions (tenant_id, kind, created_at DESC);

CREATE INDEX financial_transactions_payout_idx
  ON financial_transactions (payout_id)
  WHERE payout_id IS NOT NULL;

CREATE TABLE financial_transaction_postings (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  financial_transaction_id UUID NOT NULL REFERENCES financial_transactions (id) ON DELETE RESTRICT,
  sequence_no              SMALLINT NOT NULL CHECK (sequence_no >= 0),
  ledger_account_id        UUID NOT NULL REFERENCES ledger_accounts (id) ON DELETE RESTRICT,
  direction                ledger_line_direction NOT NULL,
  amount_minor             BIGINT NOT NULL CHECK (amount_minor > 0),
  currency                 CHAR(3) NOT NULL,
  memo                     TEXT NOT NULL DEFAULT '',
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT financial_transaction_postings_seq_unique
    UNIQUE (financial_transaction_id, sequence_no),
  CONSTRAINT financial_transaction_postings_currency_chk CHECK (char_length(currency) = 3)
);

CREATE INDEX financial_transaction_postings_txn_idx
  ON financial_transaction_postings (financial_transaction_id);

-- Treasury settlement lifecycle (status transitions + reconciliation anchors).
CREATE TYPE treasury_settlement_status AS ENUM (
  'pending',
  'journal_posted',
  'reconciled',
  'mismatch'
);

CREATE TABLE treasury_settlements (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  payout_id                UUID NOT NULL REFERENCES payouts (id) ON DELETE RESTRICT,
  settlement_reference     TEXT NOT NULL,
  status                   treasury_settlement_status NOT NULL DEFAULT 'pending',
  currency                 CHAR(3) NOT NULL,
  amount_minor             BIGINT NOT NULL CHECK (amount_minor >= 0),
  ledger_transaction_id    UUID REFERENCES ledger_transactions (id) ON DELETE RESTRICT,
  financial_transaction_id UUID REFERENCES financial_transactions (id) ON DELETE RESTRICT,
  metadata                 JSONB NOT NULL DEFAULT '{}'::jsonb,
  posted_at                TIMESTAMPTZ,
  reconciled_at            TIMESTAMPTZ,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT treasury_settlements_payout_unique UNIQUE (payout_id),
  CONSTRAINT treasury_settlements_reference_unique UNIQUE (tenant_id, settlement_reference)
);

CREATE INDEX treasury_settlements_tenant_status_idx
  ON treasury_settlements (tenant_id, status, updated_at DESC);

COMMENT ON TABLE financial_transactions IS
  'QFE canonical transaction headers; treasury_settlement kind mirrors legacy ledger capture for payout release.';
COMMENT ON TABLE financial_transaction_postings IS
  'QFE postings parallel to ledger_lines (ledger_entries) for dual-write reconciliation.';
COMMENT ON TABLE treasury_settlements IS
  'Treasury settlement state machine; settlement_reference is idempotent business key (treasury_settlement:{payout_id}).';

COMMIT;
