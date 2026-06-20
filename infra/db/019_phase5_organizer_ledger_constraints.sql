-- Phase 5.0d — organizer ledger account constraints (after 017 + 018 committed)
-- Apply after 016_phase5_ticket_commerce_foundation.sql, 017, and 018.

BEGIN;

ALTER TABLE ledger_accounts DROP CONSTRAINT IF EXISTS ledger_accounts_owner_shape_chk;

ALTER TABLE ledger_accounts ADD CONSTRAINT ledger_accounts_owner_shape_chk CHECK (
  (kind = 'vendor_payable'::ledger_account_kind AND vendor_id IS NOT NULL)
  OR (kind = 'organizer_payable'::ledger_account_kind AND organizer_id IS NOT NULL)
  OR (kind = 'client_wallet'::ledger_account_kind AND user_id IS NOT NULL)
  OR (kind NOT IN (
    'vendor_payable'::ledger_account_kind,
    'organizer_payable'::ledger_account_kind,
    'client_wallet'::ledger_account_kind
  ))
);

CREATE INDEX IF NOT EXISTS ledger_accounts_organizer_idx
  ON ledger_accounts (tenant_id, organizer_id)
  WHERE organizer_id IS NOT NULL;

COMMIT;
