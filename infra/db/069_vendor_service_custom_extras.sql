-- Phase 069 — Vendor-owned custom extras (per bookable service)
-- Additive. Does NOT alter Admin capability catalogue or pricing rules.
-- Ownership: vendors.id → vendor_services → custom_extras JSONB.

BEGIN;

ALTER TABLE vendor_services
  ADD COLUMN IF NOT EXISTS custom_extras JSONB NOT NULL DEFAULT '[]'::JSONB;

COMMENT ON COLUMN vendor_services.custom_extras IS
  'Vendor-owned extras for this bookable service (not Admin catalogue). Shape: [{ id, name, description, priceMinor, currency, active, isPublic }].';

COMMIT;
