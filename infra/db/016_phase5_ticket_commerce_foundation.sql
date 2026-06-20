-- Phase 5.0 — Ticket commerce foundation (approved domain model)
-- Separate from vendor bookings. Adds organizers, ticket orders, entitlements,
-- commerce_kind tagging, and tenant fee defaults.
-- Apply after 015_qfe_treasury_dual_write.sql
--
-- RUN ORDER (enum values need separate commits — see PostgreSQL 55P04):
--   1) 016_phase5_ticket_commerce_foundation.sql
--   2) 017_phase5_ledger_enum_organizer_payable.sql
--   3) 018_phase5_ledger_enum_organizer_payout_clearing.sql
--   4) 019_phase5_organizer_ledger_constraints.sql

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Cross-cutting commerce classification (reporting + finance ops)
-- ---------------------------------------------------------------------------

CREATE TYPE commerce_kind AS ENUM (
  'TICKET',
  'BOOKING',
  'REFUND',
  'PAYOUT',
  'SETTLEMENT'
);

COMMENT ON TYPE commerce_kind IS
  'Tags finance objects for unified reporting across ticket vs vendor booking rails.';

-- ---------------------------------------------------------------------------
-- 2) Organizers (ledger entity — ticket revenue beneficiary)
-- ---------------------------------------------------------------------------

CREATE TYPE organizer_status AS ENUM ('draft', 'active', 'suspended', 'closed');

CREATE TABLE organizers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  owner_user_id   UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  display_name    TEXT NOT NULL,
  slug            TEXT NOT NULL,
  status          organizer_status NOT NULL DEFAULT 'active',
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT organizers_slug_unique UNIQUE (tenant_id, slug)
);

CREATE INDEX organizers_tenant_status_idx ON organizers (tenant_id, status);
CREATE INDEX organizers_owner_idx ON organizers (owner_user_id);

-- ---------------------------------------------------------------------------
-- 3) Events (minimal anchor — ticket orders FK here; sync from organizer portal)
-- ---------------------------------------------------------------------------

CREATE TYPE event_status AS ENUM (
  'draft',
  'published',
  'live',
  'completed',
  'cancelled'
);

CREATE TABLE events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  organizer_id    UUID NOT NULL REFERENCES organizers (id) ON DELETE RESTRICT,
  title           TEXT NOT NULL,
  slug            TEXT NOT NULL,
  status          event_status NOT NULL DEFAULT 'draft',
  starts_at       TIMESTAMPTZ NOT NULL,
  ends_at         TIMESTAMPTZ,
  external_ref    TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT events_slug_unique UNIQUE (tenant_id, slug),
  CONSTRAINT events_time_order_ok CHECK (ends_at IS NULL OR ends_at >= starts_at)
);

CREATE INDEX events_organizer_status_idx ON events (organizer_id, status, starts_at DESC);
CREATE UNIQUE INDEX events_tenant_external_ref_unique
  ON events (tenant_id, external_ref)
  WHERE external_ref IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4) Ticket commerce aggregate (NOT bookings)
-- ---------------------------------------------------------------------------

CREATE TYPE ticket_order_status AS ENUM (
  'draft',
  'pending_payment',
  'confirmed',
  'fulfilled',
  'cancelled',
  'partially_refunded',
  'refunded'
);

CREATE TYPE ticket_entitlement_status AS ENUM (
  'issued',
  'checked_in',
  'voided',
  'refunded'
);

CREATE TABLE ticket_orders (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  organizer_id            UUID NOT NULL REFERENCES organizers (id) ON DELETE RESTRICT,
  event_id                UUID NOT NULL REFERENCES events (id) ON DELETE RESTRICT,
  buyer_user_id           UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  status                  ticket_order_status NOT NULL DEFAULT 'draft',
  currency                CHAR(3) NOT NULL,
  subtotal_minor          BIGINT NOT NULL CHECK (subtotal_minor >= 0),
  platform_fee_minor      BIGINT NOT NULL DEFAULT 0 CHECK (platform_fee_minor >= 0),
  total_minor             BIGINT NOT NULL CHECK (total_minor >= 0),
  amount_refunded_minor   BIGINT NOT NULL DEFAULT 0 CHECK (amount_refunded_minor >= 0),
  platform_fee_refunded_minor BIGINT NOT NULL DEFAULT 0 CHECK (platform_fee_refunded_minor >= 0),
  idempotency_key         TEXT,
  completed_at            TIMESTAMPTZ,
  escrow_release_not_before TIMESTAMPTZ,
  metadata                JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ticket_orders_idempotency_unique UNIQUE (tenant_id, idempotency_key),
  CONSTRAINT ticket_orders_total_chk CHECK (total_minor = subtotal_minor + platform_fee_minor),
  CONSTRAINT ticket_orders_refund_lte_total CHECK (amount_refunded_minor <= total_minor)
);

CREATE INDEX ticket_orders_event_status_idx ON ticket_orders (event_id, status, created_at DESC);
CREATE INDEX ticket_orders_organizer_status_idx ON ticket_orders (organizer_id, status, created_at DESC);
CREATE INDEX ticket_orders_buyer_idx ON ticket_orders (buyer_user_id, created_at DESC);
CREATE INDEX ticket_orders_escrow_release_queue_idx
  ON ticket_orders (tenant_id, status, escrow_release_not_before)
  WHERE status = 'fulfilled';

CREATE TABLE ticket_order_lines (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  ticket_order_id   UUID NOT NULL REFERENCES ticket_orders (id) ON DELETE RESTRICT,
  tier_id           TEXT NOT NULL,
  tier_name         TEXT NOT NULL,
  tier_type         TEXT NOT NULL DEFAULT 'regular',
  unit_price_minor  BIGINT NOT NULL CHECK (unit_price_minor >= 0),
  quantity          INT NOT NULL CHECK (quantity > 0),
  line_subtotal_minor BIGINT NOT NULL CHECK (line_subtotal_minor >= 0),
  currency          CHAR(3) NOT NULL,
  metadata          JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ticket_order_lines_order_idx ON ticket_order_lines (ticket_order_id);

CREATE TABLE ticket_entitlements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  ticket_order_id   UUID NOT NULL REFERENCES ticket_orders (id) ON DELETE RESTRICT,
  ticket_order_line_id UUID NOT NULL REFERENCES ticket_order_lines (id) ON DELETE RESTRICT,
  event_id          UUID NOT NULL REFERENCES events (id) ON DELETE RESTRICT,
  holder_user_id    UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  ticket_code       TEXT NOT NULL,
  status            ticket_entitlement_status NOT NULL DEFAULT 'issued',
  issued_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  checked_in_at     TIMESTAMPTZ,
  metadata          JSONB NOT NULL DEFAULT '{}'::JSONB,
  CONSTRAINT ticket_entitlements_code_unique UNIQUE (tenant_id, ticket_code)
);

CREATE INDEX ticket_entitlements_order_idx ON ticket_entitlements (ticket_order_id);
CREATE INDEX ticket_entitlements_event_holder_idx ON ticket_entitlements (event_id, holder_user_id);

-- Ticket-side PSP orchestration (parallel to payments.booking_id rail)
CREATE TABLE ticket_payments (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  ticket_order_id         UUID NOT NULL REFERENCES ticket_orders (id) ON DELETE RESTRICT,
  provider                payment_provider NOT NULL,
  provider_intent_ref     TEXT,
  provider_charge_ref     TEXT,
  quaser_reference        TEXT,
  status                  payment_status NOT NULL DEFAULT 'initiated',
  currency                CHAR(3) NOT NULL,
  amount_authorized_minor BIGINT CHECK (amount_authorized_minor IS NULL OR amount_authorized_minor >= 0),
  amount_captured_minor   BIGINT NOT NULL DEFAULT 0 CHECK (amount_captured_minor >= 0),
  amount_refunded_minor   BIGINT NOT NULL DEFAULT 0 CHECK (amount_refunded_minor >= 0),
  under_review            BOOLEAN NOT NULL DEFAULT FALSE,
  idempotency_key         TEXT,
  metadata                JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ticket_payments_idempotency_unique UNIQUE (tenant_id, idempotency_key),
  CONSTRAINT ticket_payments_refund_lte_capture CHECK (amount_refunded_minor <= amount_captured_minor)
);

CREATE UNIQUE INDEX ticket_payments_tenant_quaser_reference_unique
  ON ticket_payments (tenant_id, quaser_reference)
  WHERE quaser_reference IS NOT NULL;

CREATE INDEX ticket_payments_order_idx ON ticket_payments (ticket_order_id, created_at DESC);

-- Organizer payouts (ticket commerce — separate from vendor payouts)
CREATE TABLE organizer_payouts (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id              UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  organizer_id           UUID NOT NULL REFERENCES organizers (id) ON DELETE RESTRICT,
  ticket_order_id        UUID REFERENCES ticket_orders (id) ON DELETE RESTRICT,
  currency               CHAR(3) NOT NULL,
  amount_minor           BIGINT NOT NULL CHECK (amount_minor > 0),
  status                 payout_status NOT NULL DEFAULT 'pending',
  idempotency_key        TEXT NOT NULL,
  quaser_reference       TEXT,
  provider_transfer_ref  TEXT,
  ledger_transaction_id  UUID REFERENCES ledger_transactions (id) ON DELETE RESTRICT,
  failure_code           TEXT,
  failure_message        TEXT,
  under_review           BOOLEAN NOT NULL DEFAULT FALSE,
  metadata               JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT organizer_payouts_idempotency_unique UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX organizer_payouts_organizer_status_idx
  ON organizer_payouts (organizer_id, status, created_at DESC);

-- Ticket refund cases (fee reversal tracked on order + case)
CREATE TYPE ticket_refund_status AS ENUM (
  'requested',
  'under_review',
  'approved',
  'processing',
  'completed',
  'rejected'
);

CREATE TABLE ticket_refund_cases (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                   UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  ticket_order_id             UUID NOT NULL REFERENCES ticket_orders (id) ON DELETE RESTRICT,
  ticket_payment_id           UUID REFERENCES ticket_payments (id) ON DELETE RESTRICT,
  requested_by_user_id        UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  status                      ticket_refund_status NOT NULL DEFAULT 'requested',
  amount_minor                BIGINT NOT NULL CHECK (amount_minor > 0),
  platform_fee_reversal_minor BIGINT NOT NULL DEFAULT 0 CHECK (platform_fee_reversal_minor >= 0),
  currency                    CHAR(3) NOT NULL,
  reason                      TEXT NOT NULL DEFAULT '',
  metadata                    JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ticket_refund_cases_order_idx ON ticket_refund_cases (ticket_order_id, status);

-- Ledger organizer_id column (no new enum values in this migration — see 017–019)
ALTER TABLE ledger_accounts
  ADD COLUMN IF NOT EXISTS organizer_id UUID REFERENCES organizers (id) ON DELETE RESTRICT;

-- Ledger transactions: ticket order link + commerce_kind
ALTER TABLE ledger_transactions
  ADD COLUMN IF NOT EXISTS ticket_order_id UUID REFERENCES ticket_orders (id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS commerce_kind commerce_kind;

UPDATE ledger_transactions
SET commerce_kind = 'BOOKING'::commerce_kind
WHERE commerce_kind IS NULL AND booking_id IS NOT NULL;

UPDATE ledger_transactions
SET commerce_kind = 'PAYOUT'::commerce_kind
WHERE commerce_kind IS NULL
  AND reason IN ('payout_escrow_release', 'payout_transfer_initiated', 'payout_transfer_completed');

ALTER TABLE ledger_transactions
  ALTER COLUMN commerce_kind SET DEFAULT 'BOOKING'::commerce_kind;

CREATE INDEX IF NOT EXISTS ledger_transactions_ticket_order_idx
  ON ledger_transactions (ticket_order_id, created_at DESC)
  WHERE ticket_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ledger_transactions_commerce_kind_idx
  ON ledger_transactions (tenant_id, commerce_kind, created_at DESC);

-- ---------------------------------------------------------------------------
-- 6) Tag existing finance objects with commerce_kind
-- ---------------------------------------------------------------------------

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS commerce_kind commerce_kind NOT NULL DEFAULT 'BOOKING'::commerce_kind;

ALTER TABLE payouts
  ADD COLUMN IF NOT EXISTS commerce_kind commerce_kind NOT NULL DEFAULT 'PAYOUT'::commerce_kind;

ALTER TABLE financial_transactions
  ADD COLUMN IF NOT EXISTS commerce_kind commerce_kind,
  ADD COLUMN IF NOT EXISTS ticket_order_id UUID REFERENCES ticket_orders (id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS organizer_id UUID REFERENCES organizers (id) ON DELETE RESTRICT;

UPDATE financial_transactions
SET commerce_kind = 'SETTLEMENT'::commerce_kind
WHERE commerce_kind IS NULL AND kind = 'treasury_settlement'::financial_transaction_kind;

ALTER TABLE reconciliation_reports
  ADD COLUMN IF NOT EXISTS commerce_kind commerce_kind,
  ADD COLUMN IF NOT EXISTS ticket_order_id UUID REFERENCES ticket_orders (id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- 7) Tenant finance settings — approved MVP defaults (not hardcoded in app)
-- ---------------------------------------------------------------------------

ALTER TABLE tenant_finance_settings
  ADD COLUMN IF NOT EXISTS ticket_platform_fee_bps INT NOT NULL DEFAULT 500
    CHECK (ticket_platform_fee_bps >= 0 AND ticket_platform_fee_bps <= 10000),
  ADD COLUMN IF NOT EXISTS vendor_platform_fee_bps INT NOT NULL DEFAULT 1000
    CHECK (vendor_platform_fee_bps >= 0 AND vendor_platform_fee_bps <= 10000);

ALTER TABLE tenant_finance_settings
  ALTER COLUMN escrow_release_delay_hours SET DEFAULT 48;

COMMENT ON COLUMN tenant_finance_settings.ticket_platform_fee_bps IS
  'Platform fee on ticket commerce in basis points (500 = 5.00%).';

COMMENT ON COLUMN tenant_finance_settings.vendor_platform_fee_bps IS
  'Platform fee on vendor booking commerce in basis points (1000 = 10.00%).';

COMMENT ON COLUMN tenant_finance_settings.escrow_release_delay_hours IS
  'Hours after event/booking completion before escrow release (default 48).';

-- Seed defaults for existing tenants
INSERT INTO tenant_finance_settings (
  tenant_id,
  escrow_release_delay_hours,
  ticket_platform_fee_bps,
  vendor_platform_fee_bps
)
SELECT t.id, 48, 500, 1000
FROM tenants t
ON CONFLICT (tenant_id) DO UPDATE SET
  ticket_platform_fee_bps = COALESCE(tenant_finance_settings.ticket_platform_fee_bps, EXCLUDED.ticket_platform_fee_bps),
  vendor_platform_fee_bps = COALESCE(tenant_finance_settings.vendor_platform_fee_bps, EXCLUDED.vendor_platform_fee_bps),
  escrow_release_delay_hours = GREATEST(tenant_finance_settings.escrow_release_delay_hours, 48),
  updated_at = now();

COMMIT;
