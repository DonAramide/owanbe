-- Phase 8 — Attendee event-scoped networking (connections)
BEGIN;

CREATE TABLE IF NOT EXISTS event_attendee_connections (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id            UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  requester_user_id   UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  recipient_user_id   UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  status              TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_attendee_connections_no_self CHECK (requester_user_id <> recipient_user_id),
  CONSTRAINT event_attendee_connections_pair_unique
    UNIQUE (event_id, requester_user_id, recipient_user_id)
);

CREATE INDEX IF NOT EXISTS event_attendee_connections_event_idx
  ON event_attendee_connections (tenant_id, event_id, status);

CREATE INDEX IF NOT EXISTS event_attendee_connections_recipient_idx
  ON event_attendee_connections (tenant_id, recipient_user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS event_attendee_connections_requester_idx
  ON event_attendee_connections (tenant_id, requester_user_id, status, created_at DESC);

COMMENT ON TABLE event_attendee_connections IS
  'Mutual, event-scoped attendee connection requests (Phase 8).';

COMMIT;
