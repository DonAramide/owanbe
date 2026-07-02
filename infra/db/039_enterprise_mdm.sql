-- Enterprise Master Data Management (MDM) Database Schema
BEGIN;

CREATE TABLE IF NOT EXISTS mdm_domains (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  domain_key      TEXT NOT NULL UNIQUE,
  label           TEXT NOT NULL,
  icon            TEXT NOT NULL,
  metadata_schema JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mdm_entities (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  domain_id       UUID NOT NULL REFERENCES mdm_domains (id) ON DELETE CASCADE,
  parent_id       UUID REFERENCES mdm_entities (id) ON DELETE SET NULL,
  slug            TEXT NOT NULL,
  label           TEXT NOT NULL,
  description     TEXT,
  status          TEXT NOT NULL DEFAULT 'published', -- 'draft', 'published', 'archived'
  sort_order      INT NOT NULL DEFAULT 0,
  effective_date  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expiry_date     TIMESTAMPTZ,
  properties      JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT mdm_entities_slug_domain_unique UNIQUE (domain_id, slug)
);

CREATE TABLE IF NOT EXISTS mdm_versions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id       UUID NOT NULL REFERENCES mdm_entities (id) ON DELETE CASCADE,
  version_number  INT NOT NULL,
  status          TEXT NOT NULL,
  data_snapshot   JSONB NOT NULL,
  created_by      TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mdm_audit_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operator        TEXT NOT NULL,
  affected_target TEXT NOT NULL,
  action_type     TEXT NOT NULL,
  prev_val        TEXT,
  new_val         TEXT,
  reason          TEXT,
  correlation_id  TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed Initial Domains
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
ON CONFLICT (domain_key) DO UPDATE 
  SET label = EXCLUDED.label, icon = EXCLUDED.icon;

COMMIT;
