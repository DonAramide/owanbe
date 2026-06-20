-- Phase 5.4 — Persistence migration (vendor participation, live ops)
-- Apply after 021_phase5_dev_commerce_seed.sql

BEGIN;

CREATE TYPE vendor_participation_status AS ENUM (
  'invited',
  'applied',
  'pending',
  'approved',
  'rejected',
  'live',
  'completed'
);

CREATE TABLE vendor_event_participations (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id             UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  event_id              UUID NOT NULL REFERENCES events (id) ON DELETE RESTRICT,
  status                vendor_participation_status NOT NULL DEFAULT 'applied',
  booth_label           TEXT NOT NULL DEFAULT 'Vendor village',
  expected_payout_minor BIGINT NOT NULL DEFAULT 0,
  metadata              JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendor_event_participations_unique UNIQUE (vendor_id, event_id)
);

CREATE INDEX vendor_event_participations_vendor_idx
  ON vendor_event_participations (vendor_id, status, created_at DESC);
CREATE INDEX vendor_event_participations_event_idx
  ON vendor_event_participations (event_id, status);

CREATE TYPE event_incident_category AS ENUM (
  'safety',
  'crowd',
  'vendor',
  'technical',
  'medical',
  'other'
);

CREATE TYPE event_incident_priority AS ENUM ('low', 'medium', 'high', 'critical');

CREATE TYPE event_incident_status AS ENUM ('open', 'resolved', 'escalated');

CREATE TABLE event_check_ins (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id                UUID NOT NULL REFERENCES events (id) ON DELETE RESTRICT,
  entitlement_id          UUID REFERENCES ticket_entitlements (id) ON DELETE SET NULL,
  ticket_code             TEXT NOT NULL,
  holder_name             TEXT NOT NULL DEFAULT '',
  tier_name               TEXT NOT NULL DEFAULT '',
  checked_in_by_user_id   UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  source                  TEXT NOT NULL DEFAULT 'manual',
  checked_in_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata                JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE INDEX event_check_ins_event_idx ON event_check_ins (event_id, checked_in_at DESC);
CREATE UNIQUE INDEX event_check_ins_event_ticket_unique ON event_check_ins (event_id, ticket_code);

CREATE TABLE event_incidents (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id    UUID NOT NULL REFERENCES events (id) ON DELETE RESTRICT,
  title       TEXT NOT NULL,
  category    event_incident_category NOT NULL DEFAULT 'other',
  priority    event_incident_priority NOT NULL DEFAULT 'medium',
  status      event_incident_status NOT NULL DEFAULT 'open',
  reporter    TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  metadata    JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX event_incidents_event_idx ON event_incidents (event_id, status, created_at DESC);

CREATE TABLE event_feed_items (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id   UUID NOT NULL REFERENCES events (id) ON DELETE RESTRICT,
  feed_type  TEXT NOT NULL,
  headline   TEXT NOT NULL,
  detail     TEXT NOT NULL DEFAULT '',
  metadata   JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX event_feed_items_event_idx ON event_feed_items (event_id, created_at DESC);

-- Dev vendor for participation testing (owner = dev organizer/attendee user for simplicity)
INSERT INTO vendors (id, tenant_id, owner_user_id, business_name, slug, status, country_code, city, description)
VALUES (
  '55555555-5555-4555-8555-555555555555',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  'Jollof & Co',
  'jollof-and-co',
  'active',
  'NG',
  'Lagos',
  'Premium West African catering'
)
ON CONFLICT DO NOTHING;

COMMIT;
