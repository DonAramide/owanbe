-- Phase 38 — Guest list & invitation infrastructure (RSVP tokens, delivery tracking)
BEGIN;

CREATE TYPE event_guest_rsvp_status AS ENUM ('invited', 'pending', 'confirmed', 'declined');

CREATE TYPE event_invitation_status AS ENUM (
  'draft',
  'queued',
  'sent',
  'delivered',
  'opened',
  'failed',
  'bounced'
);

CREATE TYPE event_invitation_channel AS ENUM ('email', 'sms', 'link', 'whatsapp');

CREATE TABLE event_guests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  email           TEXT,
  phone_e164      TEXT,
  group_label     TEXT,
  rsvp_status     event_guest_rsvp_status NOT NULL DEFAULT 'invited',
  entitlement_ref TEXT,
  source          TEXT NOT NULL DEFAULT 'manual',
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_guests_email_or_phone CHECK (email IS NOT NULL OR phone_e164 IS NOT NULL OR name <> '')
);

CREATE INDEX event_guests_event_idx ON event_guests (tenant_id, event_id, created_at DESC);
CREATE INDEX event_guests_rsvp_idx ON event_guests (event_id, rsvp_status);

CREATE TABLE event_invitations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  guest_id        UUID NOT NULL REFERENCES event_guests (id) ON DELETE CASCADE,
  status          event_invitation_status NOT NULL DEFAULT 'draft',
  channel         event_invitation_channel NOT NULL DEFAULT 'link',
  template_id     TEXT,
  sent_at         TIMESTAMPTZ,
  delivered_at    TIMESTAMPTZ,
  opened_at       TIMESTAMPTZ,
  failed_at       TIMESTAMPTZ,
  failure_reason  TEXT,
  delivery_ref    TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX event_invitations_event_idx ON event_invitations (tenant_id, event_id, created_at DESC);
CREATE INDEX event_invitations_guest_idx ON event_invitations (guest_id, created_at DESC);
CREATE INDEX event_invitations_status_idx ON event_invitations (event_id, status);

CREATE TABLE event_invitation_tokens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  guest_id        UUID NOT NULL REFERENCES event_guests (id) ON DELETE CASCADE,
  invitation_id   UUID REFERENCES event_invitations (id) ON DELETE SET NULL,
  token_hash      TEXT NOT NULL,
  expires_at      TIMESTAMPTZ,
  used_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_invitation_tokens_hash_unique UNIQUE (token_hash)
);

CREATE INDEX event_invitation_tokens_guest_idx ON event_invitation_tokens (guest_id, created_at DESC);

COMMIT;
