-- Phase 10 — Attendee post-event feedback (overall rating + written comment)
BEGIN;

CREATE TABLE IF NOT EXISTS event_attendee_feedback (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id     UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment      TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_attendee_feedback_one_per_attendee
    UNIQUE (tenant_id, event_id, user_id)
);

CREATE INDEX IF NOT EXISTS event_attendee_feedback_event_idx
  ON event_attendee_feedback (tenant_id, event_id, created_at DESC);

CREATE INDEX IF NOT EXISTS event_attendee_feedback_user_idx
  ON event_attendee_feedback (tenant_id, user_id, updated_at DESC);

COMMENT ON TABLE event_attendee_feedback IS
  'One overall event rating + written feedback per attendee (Phase 10). No surveys.';

COMMIT;
