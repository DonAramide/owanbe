-- Phase 072 — Vendor capability assignment, service blueprints, rental packages
-- Additive. Does not replace vendor_services, vendor_event_requests,
-- rental_catalog_items, or rental_bookings.

BEGIN;

CREATE TABLE IF NOT EXISTS vendor_business_capability_assignments (
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id       UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  capability_key  TEXT NOT NULL
    CHECK (capability_key IN ('SERVICE_PROVIDER', 'RENTAL_PROVIDER')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (vendor_id, capability_key)
);

CREATE INDEX IF NOT EXISTS vendor_business_capability_assignments_tenant_idx
  ON vendor_business_capability_assignments (tenant_id, capability_key);

COMMENT ON TABLE vendor_business_capability_assignments IS
  'Vendor-selected business capabilities. Keys must exist in tenant_vendor_business_capabilities. Not a second identity.';

CREATE TABLE IF NOT EXISTS vendor_offering_category_selections (
  tenant_id    UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id    UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  category_id  UUID NOT NULL REFERENCES tenant_vendor_categories (id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (vendor_id, category_id)
);

CREATE INDEX IF NOT EXISTS vendor_offering_category_selections_tenant_idx
  ON vendor_offering_category_selections (tenant_id, vendor_id);

COMMENT ON TABLE vendor_offering_category_selections IS
  'Vendor-selected service/rental categories from tenant_vendor_categories.';

ALTER TABLE vendor_services
  ADD COLUMN IF NOT EXISTS category_id UUID NULL
    REFERENCES tenant_vendor_categories (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS vendor_services_category_id_idx
  ON vendor_services (category_id)
  WHERE category_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS vendor_service_blueprint_resources (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id          UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  vendor_service_id  UUID NOT NULL REFERENCES vendor_services (id) ON DELETE CASCADE,
  resource_id        UUID NOT NULL REFERENCES tenant_vendor_resource_catalog (id) ON DELETE RESTRICT,
  is_required        BOOLEAN NOT NULL DEFAULT true,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendor_service_blueprint_resources_uidx UNIQUE (vendor_service_id, resource_id)
);

CREATE INDEX IF NOT EXISTS vendor_service_blueprint_resources_service_idx
  ON vendor_service_blueprint_resources (vendor_service_id);

COMMENT ON TABLE vendor_service_blueprint_resources IS
  'Service blueprint: standard required resources from the master catalogue. Not inventory.';

ALTER TABLE rental_catalog_items
  ADD COLUMN IF NOT EXISTS is_package BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN rental_catalog_items.is_package IS
  'When true, item is a rental package/set. Existing rows default false. Bookings still use this catalog id.';

CREATE TABLE IF NOT EXISTS rental_package_components (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id        UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  catalog_item_id  UUID NOT NULL REFERENCES rental_catalog_items (id) ON DELETE CASCADE,
  resource_id      UUID NOT NULL REFERENCES tenant_vendor_resource_catalog (id) ON DELETE RESTRICT,
  quantity         INT NOT NULL CHECK (quantity >= 1),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rental_package_components_uidx UNIQUE (catalog_item_id, resource_id)
);

CREATE INDEX IF NOT EXISTS rental_package_components_item_idx
  ON rental_package_components (catalog_item_id);

COMMENT ON TABLE rental_package_components IS
  'Package definition quantities (Speaker x 2). Not buyer request quantities.';

COMMIT;
