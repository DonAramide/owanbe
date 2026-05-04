-- Owanbe: vendor payouts + disputes (apply after owanbe_core.sql)
-- Aligns with pooled escrow ledger (booking_id on ledger_transactions, not per-booking accounts).

BEGIN;

CREATE TYPE payout_status AS ENUM ('pending', 'processing', 'completed', 'failed');
CREATE TYPE dispute_status AS ENUM ('open', 'under_review', 'awaiting_evidence', 'resolved', 'closed');
CREATE TYPE dispute_outcome AS ENUM ('pending', 'favor_client', 'favor_vendor', 'split', 'dismissed');

CREATE TABLE payouts (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id              UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  booking_id             UUID NOT NULL REFERENCES bookings (id) ON DELETE RESTRICT,
  vendor_id              UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  payment_id             UUID NOT NULL REFERENCES payments (id) ON DELETE RESTRICT,
  currency               CHAR(3) NOT NULL,
  amount_minor           BIGINT NOT NULL CHECK (amount_minor > 0),
  status                 payout_status NOT NULL DEFAULT 'pending',
  idempotency_key        TEXT NOT NULL,
  quaser_reference       TEXT,
  provider_transfer_ref  TEXT,
  ledger_transaction_id  UUID REFERENCES ledger_transactions (id) ON DELETE RESTRICT,
  failure_code           TEXT,
  failure_message        TEXT,
  released_by_admin_id   UUID REFERENCES users (id) ON DELETE SET NULL,
  metadata               JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payouts_idempotency_unique UNIQUE (tenant_id, idempotency_key)
);

-- At most one in-flight payout per booking (retry after failed/completed uses new row + new idempotency_key).
CREATE UNIQUE INDEX payouts_one_in_flight_per_booking
  ON payouts (booking_id)
  WHERE status IN ('pending', 'processing');

CREATE INDEX payouts_vendor_status_idx ON payouts (vendor_id, status, created_at DESC);
CREATE INDEX payouts_tenant_status_idx ON payouts (tenant_id, status);

CREATE TABLE disputes (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  booking_id           UUID NOT NULL REFERENCES bookings (id) ON DELETE RESTRICT,
  opened_by_user_id    UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  status               dispute_status NOT NULL DEFAULT 'open',
  outcome              dispute_outcome NOT NULL DEFAULT 'pending',
  title                TEXT NOT NULL,
  description          TEXT NOT NULL,
  amount_claimed_minor BIGINT CHECK (amount_claimed_minor IS NULL OR amount_claimed_minor >= 0),
  currency             CHAR(3),
  payout_blocked       BOOLEAN NOT NULL DEFAULT TRUE,
  assigned_admin_id    UUID REFERENCES users (id) ON DELETE SET NULL,
  resolution_notes     TEXT,
  resolved_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX disputes_booking_idx ON disputes (booking_id, status);
CREATE INDEX disputes_tenant_status_idx ON disputes (tenant_id, status, created_at DESC);

COMMIT;
