-- Production-grade controls: tenant finance settings, booking escrow clock,
-- reconciliation jobs/reports, admin override audit, system_control ledger kind.
-- Apply after owanbe_core.sql + 002_payouts_disputes.sql (+ prior migrations as needed).

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Ledger: SYSTEM_CONTROL for reconciliation corrections & controlled adjustments
--    (PG: new enum value committed before use in same migration — split if your runner requires.)
-- ---------------------------------------------------------------------------

DO $enum$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'ledger_account_kind' AND e.enumlabel = 'system_control'
  ) THEN
    ALTER TYPE ledger_account_kind ADD VALUE 'system_control';
  END IF;
END
$enum$;

-- ---------------------------------------------------------------------------
-- 2) Per-tenant finance knobs (payout safety window, etc.)
-- ---------------------------------------------------------------------------

CREATE TABLE tenant_finance_settings (
  tenant_id                    UUID PRIMARY KEY REFERENCES tenants (id) ON DELETE RESTRICT,
  escrow_release_delay_hours   INT NOT NULL DEFAULT 36
    CHECK (escrow_release_delay_hours >= 0 AND escrow_release_delay_hours <= 168),
  reconciliation_cron_tz       TEXT NOT NULL DEFAULT 'Africa/Lagos',
  metadata                     JSONB NOT NULL DEFAULT '{}'::JSONB,
  updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 3) Booking completion clock for pooled escrow release (not a bank account)
-- ---------------------------------------------------------------------------

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS escrow_release_not_before TIMESTAMPTZ;

COMMENT ON COLUMN bookings.completed_at IS
  'When booking entered completed (service fulfilled). Drives escrow release eligibility.';

COMMENT ON COLUMN bookings.escrow_release_not_before IS
  'Earliest time automated escrow release / payout job may run; = completed_at + tenant delay unless admin overrides.';

CREATE INDEX IF NOT EXISTS bookings_escrow_release_queue_idx
  ON bookings (tenant_id, status, escrow_release_not_before)
  WHERE status = 'completed';

-- ---------------------------------------------------------------------------
-- 4) Admin override of escrow release window (immutable audit rows)
-- ---------------------------------------------------------------------------

CREATE TABLE escrow_release_admin_overrides (
  id                     BIGSERIAL PRIMARY KEY,
  tenant_id              UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  booking_id             UUID NOT NULL REFERENCES bookings (id) ON DELETE RESTRICT,
  admin_user_id          UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  previous_not_before    TIMESTAMPTZ,
  new_not_before         TIMESTAMPTZ NOT NULL,
  reason                 TEXT NOT NULL,
  correlation_id         TEXT,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX escrow_release_overrides_booking_idx
  ON escrow_release_admin_overrides (booking_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 5) Reconciliation (PSP/Quaser vs internal ledger) — jobs + line-level reports
-- ---------------------------------------------------------------------------

CREATE TYPE reconciliation_job_status AS ENUM ('pending', 'running', 'succeeded', 'failed', 'partial');
CREATE TYPE reconciliation_issue_kind AS ENUM (
  'psp_only_transaction',
  'ledger_only_transaction',
  'amount_mismatch',
  'currency_mismatch',
  'status_mismatch',
  'duplicate_router_event',
  'unknown'
);
CREATE TYPE reconciliation_resolution_status AS ENUM (
  'open',
  'waived',
  'adjusted_via_system_control',
  'psp_adjustment_pending',
  'escalated',
  'resolved'
);

CREATE TABLE reconciliation_jobs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  provider          payment_provider NOT NULL,
  period_start      TIMESTAMPTZ NOT NULL,
  period_end        TIMESTAMPTZ NOT NULL,
  status            reconciliation_job_status NOT NULL DEFAULT 'pending',
  triggered_by      TEXT NOT NULL DEFAULT 'cron' CHECK (triggered_by IN ('cron', 'manual', 'system')),
  actor_user_id     UUID REFERENCES users (id) ON DELETE SET NULL,
  summary           JSONB NOT NULL DEFAULT '{}'::JSONB,
  error_message     TEXT,
  started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at       TIMESTAMPTZ,
  CONSTRAINT reconciliation_jobs_period_chk CHECK (period_end > period_start)
);

CREATE INDEX reconciliation_jobs_tenant_started_idx
  ON reconciliation_jobs (tenant_id, started_at DESC);

CREATE TABLE reconciliation_reports (
  id                 BIGSERIAL PRIMARY KEY,
  job_id             UUID NOT NULL REFERENCES reconciliation_jobs (id) ON DELETE RESTRICT,
  tenant_id          UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  issue_kind         reconciliation_issue_kind NOT NULL,
  severity           TEXT NOT NULL DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  external_reference TEXT,
  internal_reference TEXT,
  payment_id         UUID REFERENCES payments (id) ON DELETE SET NULL,
  booking_id         UUID REFERENCES bookings (id) ON DELETE SET NULL,
  ledger_txn_id      UUID REFERENCES ledger_transactions (id) ON DELETE SET NULL,
  expected_minor       BIGINT,
  actual_minor         BIGINT,
  delta_minor          BIGINT,
  currency             CHAR(3),
  details              JSONB NOT NULL DEFAULT '{}'::JSONB,
  resolution_status    reconciliation_resolution_status NOT NULL DEFAULT 'open',
  resolution_notes     TEXT,
  resolved_by_user_id  UUID REFERENCES users (id) ON DELETE SET NULL,
  resolved_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX reconciliation_reports_job_idx ON reconciliation_reports (job_id, issue_kind);
CREATE INDEX reconciliation_reports_open_idx
  ON reconciliation_reports (tenant_id, resolution_status)
  WHERE resolution_status = 'open';

-- ---------------------------------------------------------------------------
-- 6) Payout lifecycle: silent PSP failure tracking (operational, not ledger truth)
-- ---------------------------------------------------------------------------

ALTER TABLE payouts
  ADD COLUMN IF NOT EXISTS last_psp_poll_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS expected_settlement_by TIMESTAMPTZ;

COMMENT ON COLUMN payouts.last_psp_poll_at IS
  'Last server-to-server poll to Quaser/PSP for transfer status when webhooks are delayed or missing.';

COMMENT ON COLUMN payouts.expected_settlement_by IS
  'SLA deadline for marking investigation if still processing without terminal PSP state.';

COMMIT;
