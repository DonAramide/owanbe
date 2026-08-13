-- Phase 067 — Vendor service codes + per-user conversation read receipts
-- Additive. Keeps vendor_services.id UUID as PK. Does not implement Event Codes.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Human-readable service code (VS-000001)
-- ---------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS vendor_service_code_seq START 1;

ALTER TABLE vendor_services
  ADD COLUMN IF NOT EXISTS service_code TEXT;

UPDATE vendor_services
SET service_code = 'VS-' || lpad(nextval('vendor_service_code_seq')::text, 6, '0')
WHERE service_code IS NULL OR btrim(service_code) = '';

ALTER TABLE vendor_services
  ALTER COLUMN service_code SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS vendor_services_service_code_uidx
  ON vendor_services (service_code);

CREATE INDEX IF NOT EXISTS vendor_services_tenant_code_idx
  ON vendor_services (tenant_id, service_code);

COMMENT ON COLUMN vendor_services.service_code IS
  'Human-facing stable code (VS-000001). UUID id remains the internal primary key.';

-- ---------------------------------------------------------------------------
-- 2) Participant-scoped conversation read state (per vendor_request_id)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vendor_request_conversation_reads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  request_id      UUID NOT NULL REFERENCES vendor_event_requests (id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  last_read_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendor_request_conversation_reads_uidx UNIQUE (request_id, user_id)
);

CREATE INDEX IF NOT EXISTS vendor_request_conversation_reads_user_idx
  ON vendor_request_conversation_reads (tenant_id, user_id, last_read_at DESC);

COMMENT ON TABLE vendor_request_conversation_reads IS
  'Per-user last-read cursor for vendor_request_id conversation threads. Organizer and vendor are independent.';

COMMIT;
