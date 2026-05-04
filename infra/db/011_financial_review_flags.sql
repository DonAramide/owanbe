-- Financial review flags for reconciliation enforcement and operational holds.
-- Apply after 010_payout_dispute_reconcile_hardening.sql.

BEGIN;

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS under_review BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE payouts
  ADD COLUMN IF NOT EXISTS under_review BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS payments_under_review_idx
  ON payments (tenant_id, under_review)
  WHERE under_review = TRUE;

CREATE INDEX IF NOT EXISTS payouts_under_review_idx
  ON payouts (tenant_id, under_review)
  WHERE under_review = TRUE;

COMMENT ON COLUMN payments.under_review IS
  'Set by reconciliation/ops when financial inconsistency is detected. Blocks new financial actions.';

COMMENT ON COLUMN payouts.under_review IS
  'Set by reconciliation/ops when payout needs manual review.';

COMMIT;
