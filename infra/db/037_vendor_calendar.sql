-- Phase 37 — Unified vendor calendar
BEGIN;

CREATE TABLE IF NOT EXISTS vendor_availability_settings (
  vendor_id         UUID PRIMARY KEY REFERENCES vendors (id) ON DELETE CASCADE,
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vacation_mode     BOOLEAN NOT NULL DEFAULT false,
  vacation_until    DATE,
  default_hours     JSONB NOT NULL DEFAULT '{}'::JSONB,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vendor_calendar_blocks (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id         UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  kind              TEXT NOT NULL
    CHECK (kind IN ('blackout', 'vacation', 'booking', 'rental_delivery', 'crm_scheduled', 'tentative')),
  starts_at         TIMESTAMPTZ NOT NULL,
  ends_at           TIMESTAMPTZ NOT NULL,
  all_day           BOOLEAN NOT NULL DEFAULT false,
  source_type       TEXT,
  source_id         UUID,
  reason            TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS vendor_calendar_blocks_vendor_idx
  ON vendor_calendar_blocks (tenant_id, vendor_id, starts_at, ends_at);

COMMIT;
