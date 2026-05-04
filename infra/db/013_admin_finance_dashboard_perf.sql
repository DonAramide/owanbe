BEGIN;

-- Dashboard timeline and list endpoint acceleration.
CREATE INDEX IF NOT EXISTS payments_tenant_created_idx
  ON payments (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS payouts_tenant_created_idx
  ON payouts (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ledger_transactions_tenant_reason_created_idx
  ON ledger_transactions (tenant_id, reason, created_at DESC);

CREATE INDEX IF NOT EXISTS reconciliation_reports_tenant_created_idx
  ON reconciliation_reports (tenant_id, created_at DESC);

COMMIT;
