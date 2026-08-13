-- Phase 64 — Vendor pricing overrides (extends platform_vendor_pricing_rules)
-- Additive only: preserve existing default/service rules and all historical commerce prices.
-- Hierarchy: vendor+service → vendor → service → default → 4000 bps fallback.
-- vendor_id MUST reference vendors.id (canonical vendor identity), never users.id.

BEGIN;

ALTER TABLE platform_vendor_pricing_rules
  ADD COLUMN IF NOT EXISTS vendor_id UUID NULL REFERENCES vendors (id) ON DELETE CASCADE;

-- Replace service uniqueness so vendor-scoped rows can share a service_key.
DROP INDEX IF EXISTS platform_vendor_pricing_rules_service_uidx;

CREATE UNIQUE INDEX IF NOT EXISTS platform_vendor_pricing_rules_service_uidx
  ON platform_vendor_pricing_rules (tenant_id, service_key)
  WHERE service_key IS NOT NULL
    AND vendor_id IS NULL
    AND is_default = false;

CREATE UNIQUE INDEX IF NOT EXISTS platform_vendor_pricing_rules_vendor_uidx
  ON platform_vendor_pricing_rules (tenant_id, vendor_id)
  WHERE vendor_id IS NOT NULL
    AND service_key IS NULL
    AND is_default = false;

CREATE UNIQUE INDEX IF NOT EXISTS platform_vendor_pricing_rules_vendor_service_uidx
  ON platform_vendor_pricing_rules (tenant_id, vendor_id, service_key)
  WHERE vendor_id IS NOT NULL
    AND service_key IS NOT NULL
    AND is_default = false;

CREATE INDEX IF NOT EXISTS platform_vendor_pricing_rules_vendor_id_idx
  ON platform_vendor_pricing_rules (tenant_id, vendor_id)
  WHERE vendor_id IS NOT NULL;

COMMIT;
