-- Phase 068 — Vendor service capabilities + admin category capability catalogue
-- Additive. Does not replace vendor_services.status or vendor_event_requests.
-- Offer ON/OFF remains vendor_services.status. Date availability is derived, not stored.

BEGIN;

ALTER TABLE vendor_services
  ADD COLUMN IF NOT EXISTS capabilities JSONB NOT NULL DEFAULT '[]'::JSONB;

COMMENT ON COLUMN vendor_services.capabilities IS
  'Vendor-declared equipment/capability flags for this bookable service. Keys must come from tenant_vendor_categories.metadata.capabilities.';

ALTER TABLE tenant_vendor_categories
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::JSONB;

COMMENT ON COLUMN tenant_vendor_categories.metadata IS
  'Admin catalogue extras. capabilities: [{ key, label, enabled }].';

-- Seed a controlled Admin catalogue for well-known service slugs.
-- Does not invent vendor-provided capabilities (vendor_services.capabilities stays []).
UPDATE tenant_vendor_categories
SET metadata = jsonb_build_object(
  'capabilities',
  '[
    {"key":"sound_system","label":"Sound System","enabled":true},
    {"key":"microphones","label":"Microphones","enabled":true},
    {"key":"speakers","label":"Speakers","enabled":true},
    {"key":"lighting","label":"Lighting","enabled":true},
    {"key":"dj_controller","label":"DJ Controller","enabled":true},
    {"key":"generator","label":"Generator","enabled":true},
    {"key":"smoke_machine","label":"Smoke Machine","enabled":true},
    {"key":"led_screen","label":"LED Screen","enabled":false},
    {"key":"stage","label":"Stage","enabled":false},
    {"key":"ac","label":"AC","enabled":false}
  ]'::jsonb
)
WHERE slug = 'dj'
  AND (metadata->'capabilities' IS NULL OR jsonb_typeof(metadata->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(COALESCE(metadata->'capabilities', '[]'::jsonb)) = 0);

UPDATE tenant_vendor_categories
SET metadata = jsonb_build_object(
  'capabilities',
  '[
    {"key":"cameras","label":"Cameras","enabled":true},
    {"key":"lighting","label":"Lighting","enabled":true},
    {"key":"drone","label":"Drone","enabled":true},
    {"key":"backdrop","label":"Backdrop","enabled":true},
    {"key":"photo_booth","label":"Photo Booth","enabled":false}
  ]'::jsonb
)
WHERE slug IN ('photographer', 'photo')
  AND (metadata->'capabilities' IS NULL OR jsonb_typeof(metadata->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(COALESCE(metadata->'capabilities', '[]'::jsonb)) = 0);

UPDATE tenant_vendor_categories
SET metadata = jsonb_build_object(
  'capabilities',
  '[
    {"key":"chafing_dishes","label":"Chafing Dishes","enabled":true},
    {"key":"waitstaff","label":"Waitstaff","enabled":true},
    {"key":"small_chops","label":"Small Chops","enabled":true},
    {"key":"drinks_station","label":"Drinks Station","enabled":true},
    {"key":"generator","label":"Generator","enabled":false}
  ]'::jsonb
)
WHERE slug = 'catering'
  AND (metadata->'capabilities' IS NULL OR jsonb_typeof(metadata->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(COALESCE(metadata->'capabilities', '[]'::jsonb)) = 0);

UPDATE tenant_vendor_categories
SET metadata = jsonb_build_object(
  'capabilities',
  '[
    {"key":"backdrop","label":"Backdrop","enabled":true},
    {"key":"lighting","label":"Lighting","enabled":true},
    {"key":"florals","label":"Florals","enabled":true},
    {"key":"draping","label":"Draping","enabled":true},
    {"key":"stage","label":"Stage","enabled":false}
  ]'::jsonb
)
WHERE slug IN ('decorator', 'florist')
  AND (metadata->'capabilities' IS NULL OR jsonb_typeof(metadata->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(COALESCE(metadata->'capabilities', '[]'::jsonb)) = 0);

UPDATE tenant_vendor_categories
SET metadata = jsonb_build_object(
  'capabilities',
  '[
    {"key":"bar_setup","label":"Bar Setup","enabled":true},
    {"key":"glassware","label":"Glassware","enabled":true},
    {"key":"coolers","label":"Coolers","enabled":true},
    {"key":"waitstaff","label":"Waitstaff","enabled":true}
  ]'::jsonb
)
WHERE slug = 'drinks'
  AND (metadata->'capabilities' IS NULL OR jsonb_typeof(metadata->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(COALESCE(metadata->'capabilities', '[]'::jsonb)) = 0);

COMMIT;
