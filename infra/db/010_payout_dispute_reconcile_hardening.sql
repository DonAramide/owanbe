-- Production hardening: single completed payout per booking, DB-level dispute gate on payouts,
-- optional reconciliation enum extension. Apply after 002_payouts_disputes.sql and 006_fintech_escrow_controls.sql.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) At most one terminal "completed" payout per booking (prevents double release)
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS payouts_one_completed_per_booking
  ON payouts (booking_id)
  WHERE status = 'completed';

COMMENT ON INDEX payouts_one_completed_per_booking IS
  'Ensures escrow release ledger payout cannot be duplicated for the same booking.';

-- ---------------------------------------------------------------------------
-- 2) Block payout rows while a dispute is open (DB-enforced, not only app filters)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION owanbe_payouts_block_when_dispute_open()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status::text IN ('pending', 'processing', 'completed') THEN
    IF EXISTS (
      SELECT 1
      FROM disputes d
      WHERE d.booking_id = NEW.booking_id
        AND d.status::text IN ('open', 'under_review', 'awaiting_evidence')
    ) THEN
      RAISE EXCEPTION 'PAYOUT_BLOCKED_OPEN_DISPUTE: booking_id=%', NEW.booking_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS payouts_dispute_block_ins ON payouts;
CREATE TRIGGER payouts_dispute_block_ins
BEFORE INSERT ON payouts
FOR EACH ROW
EXECUTE PROCEDURE owanbe_payouts_block_when_dispute_open();

DROP TRIGGER IF EXISTS payouts_dispute_block_upd ON payouts;
CREATE TRIGGER payouts_dispute_block_upd
BEFORE UPDATE ON payouts
FOR EACH ROW
EXECUTE PROCEDURE owanbe_payouts_block_when_dispute_open();

COMMENT ON FUNCTION owanbe_payouts_block_when_dispute_open() IS
  'Prevents payout lifecycle from entering pending/processing/completed while a dispute is open.';

COMMIT;
