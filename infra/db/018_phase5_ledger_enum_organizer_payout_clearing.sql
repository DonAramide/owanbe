-- Phase 5.0c — ledger_account_kind: organizer_payout_clearing
-- MUST commit before 019. Run after 017 has committed.

DO $enum$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'ledger_account_kind' AND e.enumlabel = 'organizer_payout_clearing'
  ) THEN
    ALTER TYPE ledger_account_kind ADD VALUE 'organizer_payout_clearing';
  END IF;
END
$enum$;
