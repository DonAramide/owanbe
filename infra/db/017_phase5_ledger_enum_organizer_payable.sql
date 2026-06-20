-- Phase 5.0b — ledger_account_kind: organizer_payable
-- MUST commit before 018 and 019. Run this file alone (not bundled with 016).
-- PostgreSQL rejects new enum values used in the same transaction they are added.

DO $enum$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'ledger_account_kind' AND e.enumlabel = 'organizer_payable'
  ) THEN
    ALTER TYPE ledger_account_kind ADD VALUE 'organizer_payable';
  END IF;
END
$enum$;
