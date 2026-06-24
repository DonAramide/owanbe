-- Phase 2A — Event website builder (structured templates per event)
BEGIN;

CREATE TABLE IF NOT EXISTS event_websites (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published')),
  template_id     TEXT NOT NULL DEFAULT 'wedding_classic'
    CHECK (template_id IN (
      'wedding_classic',
      'traditional_wedding',
      'birthday_celebration',
      'corporate_event',
      'naming_ceremony'
    )),
  public_slug     TEXT NOT NULL,
  theme_color     TEXT NOT NULL DEFAULT '#4B2C6F',
  font_pair       TEXT NOT NULL DEFAULT 'playfair_lato',
  cover_image_url TEXT,
  hero_image_url  TEXT,
  sections        JSONB NOT NULL DEFAULT '{
    "our_story": true,
    "event_details": true,
    "gallery": true,
    "rsvp": true,
    "registry": false,
    "directions": true,
    "accommodation": false,
    "vendors": false
  }'::jsonb,
  published_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_websites_event_unique UNIQUE (tenant_id, event_id),
  CONSTRAINT event_websites_slug_unique UNIQUE (tenant_id, public_slug)
);

CREATE INDEX IF NOT EXISTS event_websites_slug_idx
  ON event_websites (tenant_id, public_slug)
  WHERE status = 'published';

COMMIT;
