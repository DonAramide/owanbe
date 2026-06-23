-- Phase Event V2 — celebration-first event model, admin-managed config, vendor negotiations
-- Apply after 026_phase9_integrations.sql
-- Idempotent: safe to re-run if a prior attempt stopped mid-script.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

DO $enum$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_access_mode') THEN
    CREATE TYPE event_access_mode AS ENUM ('PRIVATE_INVITATION', 'PUBLIC_TICKETED');
  END IF;
END
$enum$;

COMMENT ON TYPE event_access_mode IS
  'PRIVATE_INVITATION = weddings, birthdays (RSVP metrics). PUBLIC_TICKETED = concerts, festivals (ticket metrics).';

DO $enum$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vendor_negotiation_status') THEN
    CREATE TYPE vendor_negotiation_status AS ENUM (
      'pending',
      'accepted',
      'declined',
      'cancelled'
    );
  END IF;
END
$enum$;

DO $enum$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'negotiation_offer_status') THEN
    CREATE TYPE negotiation_offer_status AS ENUM (
      'pending',
      'accepted',
      'rejected',
      'countered',
      'final'
    );
  END IF;
END
$enum$;

-- ---------------------------------------------------------------------------
-- Admin-managed tenant configuration
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS tenant_event_categories (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  slug            TEXT NOT NULL,
  label           TEXT NOT NULL,
  description     TEXT,
  icon_key        TEXT,
  access_mode     event_access_mode NOT NULL DEFAULT 'PRIVATE_INVITATION',
  sort_order      INT NOT NULL DEFAULT 0,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tenant_event_categories_slug_unique UNIQUE (tenant_id, slug)
);

CREATE TABLE IF NOT EXISTS tenant_event_tags (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  slug            TEXT NOT NULL,
  label           TEXT NOT NULL,
  sort_order      INT NOT NULL DEFAULT 0,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tenant_event_tags_slug_unique UNIQUE (tenant_id, slug)
);

CREATE TABLE IF NOT EXISTS tenant_event_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  slug            TEXT NOT NULL,
  label           TEXT NOT NULL,
  category_slug   TEXT,
  access_mode     event_access_mode NOT NULL DEFAULT 'PRIVATE_INVITATION',
  checklist       JSONB NOT NULL DEFAULT '[]'::JSONB,
  vendor_hints    JSONB NOT NULL DEFAULT '[]'::JSONB,
  budget_hints    JSONB NOT NULL DEFAULT '{}'::JSONB,
  sort_order      INT NOT NULL DEFAULT 0,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tenant_event_templates_slug_unique UNIQUE (tenant_id, slug)
);

CREATE TABLE IF NOT EXISTS tenant_vendor_categories (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  slug            TEXT NOT NULL,
  label           TEXT NOT NULL,
  icon_key        TEXT,
  sort_order      INT NOT NULL DEFAULT 0,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tenant_vendor_categories_slug_unique UNIQUE (tenant_id, slug)
);

CREATE TABLE IF NOT EXISTS tenant_budget_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  slug            TEXT NOT NULL,
  label           TEXT NOT NULL,
  category_slug   TEXT,
  access_mode     event_access_mode NOT NULL DEFAULT 'PRIVATE_INVITATION',
  allocations     JSONB NOT NULL DEFAULT '[]'::JSONB,
  sort_order      INT NOT NULL DEFAULT 0,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tenant_budget_templates_slug_unique UNIQUE (tenant_id, slug)
);

CREATE INDEX IF NOT EXISTS tenant_event_categories_tenant_idx
  ON tenant_event_categories (tenant_id, is_active, sort_order);
CREATE INDEX IF NOT EXISTS tenant_event_tags_tenant_idx
  ON tenant_event_tags (tenant_id, is_active, sort_order);
CREATE INDEX IF NOT EXISTS tenant_event_templates_tenant_idx
  ON tenant_event_templates (tenant_id, is_active, sort_order);
CREATE INDEX IF NOT EXISTS tenant_vendor_categories_tenant_idx
  ON tenant_vendor_categories (tenant_id, is_active, sort_order);
CREATE INDEX IF NOT EXISTS tenant_budget_templates_tenant_idx
  ON tenant_budget_templates (tenant_id, is_active, sort_order);

-- ---------------------------------------------------------------------------
-- Vendor negotiation (organizer ↔ vendor price offers)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS vendor_negotiations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  vendor_id       UUID NOT NULL,
  organizer_id    UUID NOT NULL REFERENCES organizers (id) ON DELETE CASCADE,
  status          vendor_negotiation_status NOT NULL DEFAULT 'pending',
  service_label   TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS vendor_negotiations_event_idx
  ON vendor_negotiations (tenant_id, event_id, status);
CREATE INDEX IF NOT EXISTS vendor_negotiations_vendor_idx
  ON vendor_negotiations (tenant_id, vendor_id, status);

CREATE TABLE IF NOT EXISTS vendor_negotiation_offers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_id  UUID NOT NULL REFERENCES vendor_negotiations (id) ON DELETE CASCADE,
  actor_type      TEXT NOT NULL CHECK (actor_type IN ('organizer', 'vendor')),
  actor_user_id   UUID NOT NULL,
  amount_minor    BIGINT NOT NULL,
  currency        TEXT NOT NULL DEFAULT 'NGN',
  message         TEXT,
  status          negotiation_offer_status NOT NULL DEFAULT 'pending',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS vendor_negotiation_offers_neg_idx
  ON vendor_negotiation_offers (negotiation_id, created_at);
