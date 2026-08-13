-- Phase 28 — Enterprise Administration & Control Plane
-- MDM remains dictionary master data (039). No device tables invented.

BEGIN;

CREATE INDEX IF NOT EXISTS mdm_entities_domain_status_idx
  ON mdm_entities (domain_id, status, sort_order);

CREATE INDEX IF NOT EXISTS mdm_versions_entity_idx
  ON mdm_versions (entity_id, version_number DESC);

-- Ensure seeded domains exist (idempotent with 039)
INSERT INTO mdm_domains (domain_key, label, icon, metadata_schema) VALUES
  ('marketplace', 'Marketplace Management', 'storefront', '{}'::JSONB),
  ('vendor_services', 'Vendor Services', 'settings_suggest', '{}'::JSONB),
  ('rental_marketplace', 'Rental Marketplace', 'inventory_2', '{}'::JSONB),
  ('event_configuration', 'Event Configuration', 'event', '{}'::JSONB),
  ('identity', 'Identity Dictionaries', 'fingerprint', '{}'::JSONB),
  ('geography', 'Geography & Locale', 'public', '{}'::JSONB),
  ('finance', 'Financial Rules & Tables', 'payments', '{}'::JSONB),
  ('communication', 'Communication Channels', 'message', '{}'::JSONB),
  ('operations', 'Operations & Workflows', 'task_alt', '{}'::JSONB),
  ('moderation', 'Marketplace Moderation', 'gavel', '{}'::JSONB)
ON CONFLICT (domain_key) DO NOTHING;

COMMIT;
