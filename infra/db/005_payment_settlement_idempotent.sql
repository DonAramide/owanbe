-- Idempotent Quaser / PSP capture path: row lock + payment_events dedupe + ledger ON CONFLICT.
-- Requires existing owanbe_core.sql (payments, payment_events, ledger_*).

BEGIN;

-- Allow multiple NULL event_id rows only if needed; enforce uniqueness when router sends stable ids.
ALTER TABLE payment_events DROP CONSTRAINT IF EXISTS payment_events_dedupe;
CREATE UNIQUE INDEX payment_events_provider_event_id_unique
  ON payment_events (provider, event_id)
  WHERE event_id IS NOT NULL;

-- External reference from router (OWB-*, quaser ref) — one payment row per router reference per tenant.
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS quaser_reference TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS payments_tenant_quaser_reference_unique
  ON payments (tenant_id, quaser_reference)
  WHERE quaser_reference IS NOT NULL;

-- Ledger transaction "type" / purpose for uniqueness (capture vs fee split rows) — idempotency_key already unique per tenant.
-- Optional: explicit capture fingerprint on lines — omitted; single capture txn per payment enforced by idempotency_key.

CREATE OR REPLACE FUNCTION owanbe_payments_status_transition_chk()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP <> 'UPDATE' OR OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- Terminal captured: only refund-like transitions allowed
  IF OLD.status = 'captured'::payment_status THEN
    IF NEW.status NOT IN ('captured', 'partially_refunded', 'refunded') THEN
      RAISE EXCEPTION 'payments invalid transition from captured to %', NEW.status;
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status IN ('failed', 'voided', 'refunded') THEN
    RAISE EXCEPTION 'payments status terminal (%); cannot transition to %', OLD.status, NEW.status;
  END IF;

  -- pending-ish → succeeded (captured) or failed/voided
  IF NEW.status = 'captured'::payment_status AND OLD.status NOT IN (
    'initiated', 'requires_action', 'authorized'
  ) THEN
    RAISE EXCEPTION 'payments cannot capture from status %', OLD.status;
  END IF;

  IF NEW.status IN ('failed', 'voided') AND OLD.status NOT IN (
    'initiated', 'requires_action', 'authorized'
  ) THEN
    RAISE EXCEPTION 'payments cannot fail from status %', OLD.status;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS payments_status_transition_chk ON payments;
CREATE TRIGGER payments_status_transition_chk
BEFORE UPDATE OF status ON payments
FOR EACH ROW
EXECUTE PROCEDURE owanbe_payments_status_transition_chk();

COMMENT ON FUNCTION owanbe_payments_status_transition_chk() IS
  'Enforces pending-ish → captured|failed|voided; captured → refunds only; no succeeded→pending.';

-- ---------------------------------------------------------------------------
-- Core idempotent settlement: lock payment, dedupe event, ledger upsert, mark captured.
-- Pass four ledger account UUIDs (PSP clearing debit, escrow credit, escrow debit fee, platform credit fee).
-- p_gross_minor = captured gross; p_fee_minor = platform fee portion from escrow.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION owanbe_apply_quaser_payment_capture(
  p_payment_id UUID,
  p_tenant_id UUID,
  p_provider payment_provider,
  p_router_event_id TEXT,
  p_event_type TEXT,
  p_payload JSONB,
  p_psp_clearing_account_id UUID,
  p_escrow_account_id UUID,
  p_platform_fees_account_id UUID,
  p_gross_minor BIGINT,
  p_fee_minor BIGINT
) RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
  v_pay RECORD;
  v_event_rows INT := 0;
  v_txn_id UUID;
  v_existing_txn UUID;
  v_line_count INT;
  v_idem TEXT;
BEGIN
  IF p_gross_minor IS NULL OR p_gross_minor < 0 THEN
    RAISE EXCEPTION 'invalid p_gross_minor';
  END IF;
  IF p_fee_minor IS NULL OR p_fee_minor < 0 OR p_fee_minor > p_gross_minor THEN
    RAISE EXCEPTION 'invalid p_fee_minor';
  END IF;

  v_idem := 'capture:' || p_payment_id::TEXT;

  -- 1) Strong per-payment serialization (NOT in-memory)
  SELECT * INTO v_pay FROM payments WHERE id = p_payment_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', false, 'error', 'payment_not_found');
  END IF;

  -- 2) Early exit: already succeeded (captured)
  IF v_pay.status = 'captured'::payment_status THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'already_succeeded');
  END IF;

  IF v_pay.status IN ('failed', 'voided', 'refunded') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'terminal_payment_status', 'status', v_pay.status::TEXT);
  END IF;

  -- 3) Append-only event dedupe (duplicate router deliveries)
  IF p_router_event_id IS NOT NULL AND btrim(p_router_event_id) <> '' THEN
    INSERT INTO payment_events (payment_id, tenant_id, provider, event_id, event_type, payload)
    VALUES (p_payment_id, p_tenant_id, p_provider, p_router_event_id, p_event_type, p_payload)
    ON CONFLICT (provider, event_id) WHERE event_id IS NOT NULL DO NOTHING;
    GET DIAGNOSTICS v_event_rows = ROW_COUNT;
    -- v_event_rows = 0 means duplicate event_id; capture path below remains idempotent via ledger ON CONFLICT
  ELSE
    INSERT INTO payment_events (payment_id, tenant_id, provider, event_id, event_type, payload)
    VALUES (p_payment_id, p_tenant_id, p_provider, NULL, p_event_type, p_payload);
  END IF;

  -- 4) Ledger header: INSERT ON CONFLICT DO NOTHING, then resolve txn id
  INSERT INTO ledger_transactions (tenant_id, booking_id, payment_id, idempotency_key, reason)
  VALUES (
    p_tenant_id,
    v_pay.booking_id,
    p_payment_id,
    v_idem,
    'payment_capture_quaser'
  )
  ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
  RETURNING id INTO v_txn_id;

  IF v_txn_id IS NULL THEN
    SELECT id INTO v_existing_txn FROM ledger_transactions
    WHERE tenant_id = p_tenant_id AND idempotency_key = v_idem;
    v_txn_id := v_existing_txn;
  END IF;

  IF v_txn_id IS NULL THEN
    RAISE EXCEPTION 'ledger transaction missing after upsert';
  END IF;

  SELECT COUNT(*)::INT INTO v_line_count FROM ledger_lines WHERE transaction_id = v_txn_id;

  IF v_line_count = 0 THEN
    -- Gross: Dr PSP clearing / Cr escrow
    INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
    VALUES
      (v_txn_id, p_psp_clearing_account_id, 'debit', p_gross_minor, v_pay.currency, 'capture gross'),
      (v_txn_id, p_escrow_account_id, 'credit', p_gross_minor, v_pay.currency, 'capture to escrow');
    -- Fee: Dr escrow / Cr platform fees
    IF p_fee_minor > 0 THEN
      INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
      VALUES
        (v_txn_id, p_escrow_account_id, 'debit', p_fee_minor, v_pay.currency, 'platform fee'),
        (v_txn_id, p_platform_fees_account_id, 'credit', p_fee_minor, v_pay.currency, 'platform fee');
    END IF;
  END IF;

  -- 5) Mark payment captured exactly once (trigger enforces transitions)
  UPDATE payments
  SET
    status = 'captured',
    amount_captured_minor = p_gross_minor,
    updated_at = now(),
    raw_event_ids = array_append(COALESCE(raw_event_ids, '{}'::TEXT[]), COALESCE(p_router_event_id, p_event_type))
  WHERE id = p_payment_id AND status <> 'captured'::payment_status;

  RETURN jsonb_build_object(
    'skipped', false,
    'reason', 'applied',
    'ledger_transaction_id', v_txn_id,
    'payment_id', p_payment_id
  );
END;
$$;

COMMENT ON FUNCTION owanbe_apply_quaser_payment_capture IS
  'Idempotent capture: FOR UPDATE payment, dedupe payment_events, ledger txn ON CONFLICT, lines once, then captured.';

COMMIT;
