-- Marketplace expansion — Rentals & Event Equipment
BEGIN;

CREATE TABLE IF NOT EXISTS rental_catalog_items (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id           UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  category_slug       TEXT NOT NULL,
  name                TEXT NOT NULL,
  description         TEXT NOT NULL DEFAULT '',
  photo_url           TEXT,
  total_quantity      INT NOT NULL DEFAULT 0 CHECK (total_quantity >= 0),
  available_quantity  INT NOT NULL DEFAULT 0 CHECK (available_quantity >= 0),
  reserved_quantity   INT NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
  rental_fee_minor    BIGINT NOT NULL DEFAULT 0 CHECK (rental_fee_minor >= 0),
  deposit_minor       BIGINT NOT NULL DEFAULT 0 CHECK (deposit_minor >= 0),
  active              BOOLEAN NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS rental_blackout_dates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id       UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  catalog_item_id UUID REFERENCES rental_catalog_items (id) ON DELETE CASCADE,
  blackout_date   DATE NOT NULL,
  reason          TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (vendor_id, catalog_item_id, blackout_date)
);

CREATE TABLE IF NOT EXISTS rental_bookings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id            UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  vendor_id           UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  catalog_item_id     UUID NOT NULL REFERENCES rental_catalog_items (id) ON DELETE RESTRICT,
  requester_name      TEXT NOT NULL,
  requester_user_id   UUID REFERENCES users (id) ON DELETE SET NULL,
  quantity_requested  INT NOT NULL CHECK (quantity_requested > 0),
  quantity_approved   INT CHECK (quantity_approved IS NULL OR quantity_approved > 0),
  counter_quantity    INT CHECK (counter_quantity IS NULL OR counter_quantity > 0),
  status              TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'countered', 'declined', 'delivered', 'returned', 'cancelled')),
  rental_fee_minor    BIGINT NOT NULL DEFAULT 0,
  deposit_minor       BIGINT NOT NULL DEFAULT 0,
  delivery_date       DATE,
  pickup_date         DATE,
  delivery_address    TEXT,
  damage_notes        TEXT,
  delivered_at        TIMESTAMPTZ,
  returned_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS rental_catalog_vendor_idx
  ON rental_catalog_items (tenant_id, vendor_id, category_slug)
  WHERE active = true;

CREATE INDEX IF NOT EXISTS rental_bookings_event_idx
  ON rental_bookings (tenant_id, event_id, created_at DESC);

CREATE INDEX IF NOT EXISTS rental_bookings_vendor_idx
  ON rental_bookings (tenant_id, vendor_id, status, delivery_date);

COMMIT;
