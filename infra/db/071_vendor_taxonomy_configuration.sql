-- Phase 071 — Vendor taxonomy configuration (additive)
-- Super Admin definitions: business capabilities, offering kind on categories,
-- master resource catalogue.
-- Does NOT assign capabilities to vendors.
-- Does NOT alter vendor_services, vendor_event_requests, rental_bookings,
-- or rental_catalog_items rows/semantics.
-- Does NOT hard-delete categories.

BEGIN;

ALTER TABLE tenant_vendor_categories
  ADD COLUMN IF NOT EXISTS offering_kind TEXT NOT NULL DEFAULT 'unclassified'
    CHECK (offering_kind IN ('service', 'rental', 'unclassified'));

ALTER TABLE tenant_vendor_categories
  ADD COLUMN IF NOT EXISTS parent_id UUID NULL
    REFERENCES tenant_vendor_categories (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS tenant_vendor_categories_kind_idx
  ON tenant_vendor_categories (tenant_id, offering_kind, is_active, sort_order);

COMMENT ON COLUMN tenant_vendor_categories.offering_kind IS
  'Admin taxonomy class: service (performed) vs rental (package/set category). unclassified = legacy unclassified seed. Does not change rental_catalog_items.category_slug.';

-- Known rental slugs from 033 / ensureRentalCategories — classification of taxonomy rows only.
UPDATE tenant_vendor_categories
SET offering_kind = 'rental'
WHERE offering_kind = 'unclassified'
  AND slug IN (
    'rentals-equipment', 'chairs', 'tables', 'canopies', 'tents', 'stage-platforms',
    'led-screens', 'sound-systems', 'lighting-systems', 'generators', 'mobile-toilets',
    'cooling-fans', 'air-conditioners', 'dance-floors', 'cutlery-crockery',
    'thrones-vip-seating', 'backdrops', 'photo-booths', 'event-equipment'
  );

UPDATE tenant_vendor_categories
SET offering_kind = 'service'
WHERE offering_kind = 'unclassified'
  AND slug IN (
    'venue', 'decorator', 'photographer', 'dj', 'mc', 'security', 'cake', 'drinks',
    'ushers', 'live-band', 'catering', 'florist', 'av-production',
    'fashion-attire', 'aso-ebi', 'traditional-wear', 'wedding-gowns',
    'bridesmaid-dresses', 'suits', 'gele', 'fashion-accessories', 'tailoring'
  );

-- Authoritative Service Provider / Rental Provider definitions (not vendor assignment).
CREATE TABLE IF NOT EXISTS tenant_vendor_business_capabilities (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  capability_key  TEXT NOT NULL
    CHECK (capability_key IN ('SERVICE_PROVIDER', 'RENTAL_PROVIDER')),
  label           TEXT NOT NULL,
  description     TEXT NOT NULL DEFAULT '',
  is_active       BOOLEAN NOT NULL DEFAULT true,
  sort_order      INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tenant_vendor_business_capabilities_key_uidx UNIQUE (tenant_id, capability_key)
);

CREATE INDEX IF NOT EXISTS tenant_vendor_business_capabilities_tenant_idx
  ON tenant_vendor_business_capabilities (tenant_id, is_active, sort_order);

COMMENT ON TABLE tenant_vendor_business_capabilities IS
  'Super Admin definitions of vendor business capabilities. Not vendor identity. Not assigned to vendors in 071.';

INSERT INTO tenant_vendor_business_capabilities (tenant_id, capability_key, label, description, is_active, sort_order)
SELECT t.id, v.capability_key, v.label, v.description, true, v.sort_order
FROM tenants t
CROSS JOIN (
  VALUES
    ('SERVICE_PROVIDER', 'Service Provider', 'Vendor performs a service (e.g. DJ, catering). Organizers book the service.', 0),
    ('RENTAL_PROVIDER', 'Rental Provider', 'Vendor supplies rental packages/sets of equipment or resources.', 1)
) AS v(capability_key, label, description, sort_order)
ON CONFLICT (tenant_id, capability_key) DO NOTHING;

-- Master resource / component catalogue (definitions only — not inventory).
CREATE TABLE IF NOT EXISTS tenant_vendor_resource_catalog (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  slug            TEXT NOT NULL,
  label           TEXT NOT NULL,
  description     TEXT NOT NULL DEFAULT '',
  is_active       BOOLEAN NOT NULL DEFAULT true,
  sort_order      INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tenant_vendor_resource_catalog_slug_uidx UNIQUE (tenant_id, slug)
);

CREATE INDEX IF NOT EXISTS tenant_vendor_resource_catalog_tenant_idx
  ON tenant_vendor_resource_catalog (tenant_id, is_active, sort_order);

COMMENT ON TABLE tenant_vendor_resource_catalog IS
  'Master resource kinds for future service requirements and rental package contents. Not vendor stock, bookings, or finance.';

INSERT INTO tenant_vendor_resource_catalog (tenant_id, slug, label, description, is_active, sort_order)
SELECT t.id, v.slug, v.label, v.description, true, v.sort_order
FROM tenants t
CROSS JOIN (
  VALUES
    ('microphone', 'Microphone', 'Handheld or wireless microphone', 0),
    ('speaker', 'Speaker', 'PA / event speaker', 1),
    ('mixer', 'Mixer', 'Audio mixer', 2),
    ('dj-controller', 'DJ Controller', 'DJ performance controller', 3),
    ('keyboard', 'Keyboard', 'Musical keyboard', 4),
    ('drum-set', 'Drum Set', 'Drum kit', 5),
    ('lighting', 'Lighting', 'Event lighting fixture or kit', 6),
    ('cable-kit', 'Cable Kit', 'Audio/power cable set', 7)
) AS v(slug, label, description, sort_order)
ON CONFLICT (tenant_id, slug) DO NOTHING;

COMMIT;
