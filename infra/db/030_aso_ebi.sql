-- Phase 2C — Aso-Ebi manager (fabric catalog, packages, reservations, inventory)
BEGIN;

CREATE TABLE IF NOT EXISTS event_aso_ebi_fabrics (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  name            TEXT NOT NULL DEFAULT 'Aso-Ebi fabric',
  photo_url       TEXT,
  description     TEXT NOT NULL DEFAULT '',
  active          BOOLEAN NOT NULL DEFAULT true,
  sort_order      INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_aso_ebi_packages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  fabric_id       UUID NOT NULL REFERENCES event_aso_ebi_fabrics (id) ON DELETE CASCADE,
  package_type    TEXT NOT NULL
    CHECK (package_type IN ('fabric_only', 'fabric_cap', 'premium')),
  price_minor     BIGINT NOT NULL CHECK (price_minor >= 0),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (fabric_id, package_type)
);

CREATE TABLE IF NOT EXISTS event_aso_ebi_inventory (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id            UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  fabric_id           UUID NOT NULL REFERENCES event_aso_ebi_fabrics (id) ON DELETE CASCADE,
  package_type        TEXT NOT NULL
    CHECK (package_type IN ('fabric_only', 'fabric_cap', 'premium')),
  size                TEXT NOT NULL,
  quantity_available  INT NOT NULL DEFAULT 0 CHECK (quantity_available >= 0),
  quantity_reserved   INT NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
  quantity_collected  INT NOT NULL DEFAULT 0 CHECK (quantity_collected >= 0),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (fabric_id, package_type, size)
);

CREATE TABLE IF NOT EXISTS event_aso_ebi_reservations (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id            UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  fabric_id           UUID NOT NULL REFERENCES event_aso_ebi_fabrics (id) ON DELETE RESTRICT,
  package_type        TEXT NOT NULL
    CHECK (package_type IN ('fabric_only', 'fabric_cap', 'premium')),
  size                TEXT NOT NULL,
  guest_name          TEXT NOT NULL,
  guest_email         TEXT,
  user_id             UUID REFERENCES users (id) ON DELETE SET NULL,
  price_minor         BIGINT NOT NULL CHECK (price_minor >= 0),
  payment_status      TEXT NOT NULL DEFAULT 'pending'
    CHECK (payment_status IN ('pending', 'paid')),
  fulfillment_status  TEXT NOT NULL DEFAULT 'reserved'
    CHECK (fulfillment_status IN ('reserved', 'collected', 'cancelled')),
  reserved_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at             TIMESTAMPTZ,
  collected_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS event_aso_ebi_fabrics_event_idx
  ON event_aso_ebi_fabrics (tenant_id, event_id, sort_order)
  WHERE active = true;

CREATE INDEX IF NOT EXISTS event_aso_ebi_reservations_event_idx
  ON event_aso_ebi_reservations (tenant_id, event_id, reserved_at DESC)
  WHERE fulfillment_status <> 'cancelled';

COMMIT;
