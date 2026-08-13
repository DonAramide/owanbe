-- Phase 26 — Organizer Marketing & Growth (campaigns as consumer layer)

BEGIN;

CREATE TABLE IF NOT EXISTS marketing_campaigns (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  organizer_id      UUID NOT NULL REFERENCES organizers (id) ON DELETE CASCADE,
  event_id          UUID REFERENCES events (id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'sending', 'sent', 'failed', 'cancelled')),
  channel           TEXT NOT NULL DEFAULT 'email'
                    CHECK (channel IN ('email', 'sms', 'whatsapp')),
  audience_segment  TEXT NOT NULL DEFAULT 'all_guests',
  subject           TEXT,
  body              TEXT NOT NULL DEFAULT '',
  recipient_count   INT NOT NULL DEFAULT 0,
  sent_count        INT NOT NULL DEFAULT 0,
  failed_count      INT NOT NULL DEFAULT 0,
  skipped_count     INT NOT NULL DEFAULT 0,
  last_error        TEXT,
  sent_at           TIMESTAMPTZ,
  created_by        UUID REFERENCES users (id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS marketing_campaigns_org_idx
  ON marketing_campaigns (tenant_id, organizer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS marketing_campaigns_event_idx
  ON marketing_campaigns (event_id, created_at DESC)
  WHERE event_id IS NOT NULL;

-- Optional snapshot of resolved recipients at send time (not canonical identity)
CREATE TABLE IF NOT EXISTS marketing_campaign_recipients (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id       UUID NOT NULL REFERENCES marketing_campaigns (id) ON DELETE CASCADE,
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  recipient         TEXT NOT NULL,
  display_name      TEXT,
  source_kind       TEXT NOT NULL DEFAULT 'guest'
                    CHECK (source_kind IN ('guest', 'buyer', 'attendee', 'unknown')),
  source_id         TEXT,
  notification_id   TEXT,
  delivery_status   TEXT NOT NULL DEFAULT 'queued',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS marketing_campaign_recipients_campaign_idx
  ON marketing_campaign_recipients (campaign_id, created_at DESC);

COMMIT;
