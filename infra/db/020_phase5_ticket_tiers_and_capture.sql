-- Phase 5.1 — Event ticket tiers, ticket payment events, idempotent ticket capture ledger function.
-- Apply after 019_phase5_organizer_ledger_constraints.sql

BEGIN;

CREATE TABLE event_ticket_tiers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id          UUID NOT NULL REFERENCES events (id) ON DELETE RESTRICT,
  external_tier_id  TEXT NOT NULL,
  name              TEXT NOT NULL,
  description       TEXT NOT NULL DEFAULT '',
  tier_type         TEXT NOT NULL DEFAULT 'regular',
  price_minor       BIGINT NOT NULL CHECK (price_minor >= 0),
  currency          CHAR(3) NOT NULL,
  capacity          INT NOT NULL CHECK (capacity >= 0),
  remaining         INT NOT NULL CHECK (remaining >= 0),
  sales_paused      BOOLEAN NOT NULL DEFAULT FALSE,
  metadata          JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_ticket_tiers_external_unique UNIQUE (tenant_id, event_id, external_tier_id),
  CONSTRAINT event_ticket_tiers_remaining_lte_capacity CHECK (remaining <= capacity)
);

CREATE INDEX event_ticket_tiers_event_idx ON event_ticket_tiers (event_id, sales_paused);

CREATE TABLE ticket_payment_events (
  id                BIGSERIAL PRIMARY KEY,
  ticket_payment_id UUID NOT NULL REFERENCES ticket_payments (id) ON DELETE RESTRICT,
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  provider          payment_provider NOT NULL,
  event_id          TEXT,
  event_type        TEXT NOT NULL,
  payload           JSONB NOT NULL,
  received_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ticket_payment_events_provider_event_id_unique
  ON ticket_payment_events (provider, event_id)
  WHERE event_id IS NOT NULL;

CREATE INDEX ticket_payment_events_payment_idx
  ON ticket_payment_events (ticket_payment_id, received_at DESC);

ALTER TABLE ticket_payments
  ADD COLUMN IF NOT EXISTS commerce_kind commerce_kind NOT NULL DEFAULT 'TICKET'::commerce_kind;

-- Idempotent ticket capture: PSP → escrow → platform fee + organizer payable
CREATE OR REPLACE FUNCTION owanbe_apply_ticket_payment_capture(
  p_ticket_payment_id UUID,
  p_tenant_id UUID,
  p_provider payment_provider,
  p_router_event_id TEXT,
  p_event_type TEXT,
  p_payload JSONB,
  p_psp_clearing_account_id UUID,
  p_escrow_account_id UUID,
  p_platform_fees_account_id UUID,
  p_organizer_payable_account_id UUID,
  p_gross_minor BIGINT,
  p_fee_minor BIGINT,
  p_organizer_share_minor BIGINT
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
  IF p_organizer_share_minor IS NULL OR p_organizer_share_minor < 0 THEN
    RAISE EXCEPTION 'invalid p_organizer_share_minor';
  END IF;
  IF p_fee_minor + p_organizer_share_minor <> p_gross_minor THEN
    RAISE EXCEPTION 'fee + organizer_share must equal gross';
  END IF;

  v_idem := 'ticket_capture:' || p_ticket_payment_id::TEXT;

  SELECT tp.*, tord.id AS order_id, tord.organizer_id, tord.event_id
  INTO v_pay
  FROM ticket_payments tp
  INNER JOIN ticket_orders tord ON tord.id = tp.ticket_order_id
  WHERE tp.id = p_ticket_payment_id AND tp.tenant_id = p_tenant_id
  FOR UPDATE OF tp;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', false, 'error', 'ticket_payment_not_found');
  END IF;

  IF v_pay.status = 'captured'::payment_status THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'already_captured');
  END IF;

  IF v_pay.status IN ('failed', 'voided', 'refunded') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'terminal_payment_status', 'status', v_pay.status::TEXT);
  END IF;

  IF p_router_event_id IS NOT NULL AND btrim(p_router_event_id) <> '' THEN
    INSERT INTO ticket_payment_events (ticket_payment_id, tenant_id, provider, event_id, event_type, payload)
    VALUES (p_ticket_payment_id, p_tenant_id, p_provider, p_router_event_id, p_event_type, p_payload)
    ON CONFLICT (provider, event_id) WHERE event_id IS NOT NULL DO NOTHING;
    GET DIAGNOSTICS v_event_rows = ROW_COUNT;
  ELSE
    INSERT INTO ticket_payment_events (ticket_payment_id, tenant_id, provider, event_id, event_type, payload)
    VALUES (p_ticket_payment_id, p_tenant_id, p_provider, NULL, p_event_type, p_payload);
  END IF;

  INSERT INTO ledger_transactions (
    tenant_id, ticket_order_id, payment_id, idempotency_key, reason, commerce_kind
  ) VALUES (
    p_tenant_id,
    v_pay.ticket_order_id,
    NULL,
    v_idem,
    'payment_capture_ticket',
    'TICKET'::commerce_kind
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
    INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
    VALUES
      (v_txn_id, p_psp_clearing_account_id, 'debit', p_gross_minor, v_pay.currency, 'ticket capture gross'),
      (v_txn_id, p_escrow_account_id, 'credit', p_gross_minor, v_pay.currency, 'ticket capture to escrow');

    IF p_fee_minor > 0 THEN
      INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
      VALUES
        (v_txn_id, p_escrow_account_id, 'debit', p_fee_minor, v_pay.currency, 'platform fee'),
        (v_txn_id, p_platform_fees_account_id, 'credit', p_fee_minor, v_pay.currency, 'platform fee');
    END IF;

    IF p_organizer_share_minor > 0 THEN
      INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
      VALUES
        (v_txn_id, p_escrow_account_id, 'debit', p_organizer_share_minor, v_pay.currency, 'organizer share'),
        (v_txn_id, p_organizer_payable_account_id, 'credit', p_organizer_share_minor, v_pay.currency, 'organizer payable');
    END IF;
  END IF;

  UPDATE ticket_payments
  SET
    status = 'captured'::payment_status,
    amount_captured_minor = p_gross_minor,
    updated_at = now()
  WHERE id = p_ticket_payment_id AND tenant_id = p_tenant_id;

  UPDATE ticket_orders
  SET
    status = 'confirmed'::ticket_order_status,
    updated_at = now()
  WHERE id = v_pay.ticket_order_id
    AND tenant_id = p_tenant_id
    AND status = 'pending_payment'::ticket_order_status;

  RETURN jsonb_build_object('skipped', false, 'reason', 'applied', 'ledger_transaction_id', v_txn_id);
END;
$$;

COMMIT;
