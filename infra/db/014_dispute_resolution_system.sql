BEGIN;

-- Enrich disputes with immutable financial/linkage references.
ALTER TABLE disputes
  ADD COLUMN IF NOT EXISTS payment_id UUID REFERENCES payments (id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS client_user_id UUID REFERENCES users (id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS vendor_id UUID REFERENCES vendors (id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS reason TEXT,
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS resolution_amount_minor BIGINT CHECK (
    resolution_amount_minor IS NULL OR resolution_amount_minor >= 0
  );

-- Backfill links from booking where possible.
UPDATE disputes d
SET client_user_id = b.client_user_id,
    vendor_id = b.vendor_id,
    payment_id = COALESCE(
      d.payment_id,
      (
        SELECT p.id
        FROM payments p
        WHERE p.tenant_id = d.tenant_id
          AND p.booking_id = d.booking_id
        ORDER BY p.created_at DESC
        LIMIT 1
      )
    )
FROM bookings b
WHERE b.id = d.booking_id
  AND d.client_user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS disputes_tenant_idempotency_idx
  ON disputes (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS disputes_tenant_payment_idx
  ON disputes (tenant_id, payment_id, created_at DESC);

CREATE INDEX IF NOT EXISTS disputes_tenant_vendor_client_idx
  ON disputes (tenant_id, vendor_id, client_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS dispute_messages (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  dispute_id       UUID NOT NULL REFERENCES disputes (id) ON DELETE CASCADE,
  sender_type      TEXT NOT NULL CHECK (sender_type IN ('client', 'vendor', 'admin')),
  sender_user_id   UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  message          TEXT NOT NULL,
  attachments      JSONB NOT NULL DEFAULT '[]'::jsonb,
  idempotency_key  TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT dispute_messages_tenant_idem_unique UNIQUE (tenant_id, dispute_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS dispute_messages_dispute_created_idx
  ON dispute_messages (dispute_id, created_at ASC);

CREATE TABLE IF NOT EXISTS dispute_evidence (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  dispute_id       UUID NOT NULL REFERENCES disputes (id) ON DELETE CASCADE,
  type             TEXT NOT NULL CHECK (type IN ('image', 'video', 'document')),
  url              TEXT NOT NULL,
  uploaded_by      UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  metadata         JSONB NOT NULL DEFAULT '{}'::jsonb,
  idempotency_key  TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT dispute_evidence_tenant_idem_unique UNIQUE (tenant_id, dispute_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS dispute_evidence_dispute_created_idx
  ON dispute_evidence (dispute_id, created_at DESC);

COMMIT;
