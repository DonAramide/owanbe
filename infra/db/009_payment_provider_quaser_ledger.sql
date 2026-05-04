-- Quaser as first-class payment provider + pooled ledger account seed pattern.
-- Apply after 005_payment_settlement_idempotent.sql (and 006 as needed).

BEGIN;

DO $enum$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'payment_provider' AND e.enumlabel = 'quaser'
  ) THEN
    ALTER TYPE payment_provider ADD VALUE 'quaser';
  END IF;
END
$enum$;

COMMENT ON TYPE payment_provider IS 'PSP / router integration; quaser = Owanbe Quaser router.';

COMMIT;
