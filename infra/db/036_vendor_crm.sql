-- Phase 36 — Vendor CRM pipeline
BEGIN;

CREATE TABLE IF NOT EXISTS vendor_event_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id          UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  vendor_id         UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  organizer_id      UUID NOT NULL REFERENCES organizers (id) ON DELETE RESTRICT,
  stage             TEXT NOT NULL DEFAULT 'new'
    CHECK (stage IN (
      'new', 'negotiating', 'accepted', 'scheduled', 'arrived', 'completed',
      'declined', 'cancelled'
    )),
  service_label     TEXT,
  message           TEXT NOT NULL DEFAULT '',
  negotiation_id    UUID REFERENCES vendor_negotiations (id) ON DELETE SET NULL,
  scheduled_at      TIMESTAMPTZ,
  scheduled_end     TIMESTAMPTZ,
  arrived_at        TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  source            TEXT NOT NULL DEFAULT 'marketplace',
  metadata          JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_id, vendor_id)
);

CREATE TABLE IF NOT EXISTS vendor_request_stage_history (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  request_id      UUID NOT NULL REFERENCES vendor_event_requests (id) ON DELETE CASCADE,
  from_stage      TEXT,
  to_stage        TEXT NOT NULL,
  actor_type      TEXT NOT NULL DEFAULT 'organizer',
  actor_user_id   UUID,
  note            TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE vendor_negotiations
  ADD COLUMN IF NOT EXISTS vendor_request_id UUID REFERENCES vendor_event_requests (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS vendor_event_requests_event_idx
  ON vendor_event_requests (tenant_id, event_id, stage, updated_at DESC);

CREATE INDEX IF NOT EXISTS vendor_event_requests_vendor_idx
  ON vendor_event_requests (tenant_id, vendor_id, stage, updated_at DESC);

CREATE INDEX IF NOT EXISTS vendor_request_stage_history_req_idx
  ON vendor_request_stage_history (request_id, created_at DESC);

COMMIT;
