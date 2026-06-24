-- Phase 2B — Celebration wall (guest messages, reactions, moderation)
BEGIN;

CREATE TABLE IF NOT EXISTS event_wall_settings (
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  live_mode       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, event_id)
);

CREATE TABLE IF NOT EXISTS event_wall_posts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  guest_name      TEXT NOT NULL,
  message         TEXT NOT NULL,
  photo_url       TEXT,
  status          TEXT NOT NULL DEFAULT 'visible'
    CHECK (status IN ('visible', 'hidden', 'deleted')),
  pinned          BOOLEAN NOT NULL DEFAULT false,
  pinned_at       TIMESTAMPTZ,
  reactions       JSONB NOT NULL DEFAULT '{"heart":0,"celebrate":0,"cheers":0,"fire":0}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  moderated_by    UUID REFERENCES users (id) ON DELETE SET NULL,
  moderated_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS event_wall_posts_event_idx
  ON event_wall_posts (tenant_id, event_id, created_at DESC)
  WHERE status <> 'deleted';

CREATE INDEX IF NOT EXISTS event_wall_posts_pinned_idx
  ON event_wall_posts (tenant_id, event_id, pinned DESC, pinned_at DESC NULLS LAST)
  WHERE status = 'visible';

COMMIT;
