-- Phase 22 — Organization & Team Management
-- Organizer membership mirrors vendor_users; owner remains organizers.owner_user_id.

BEGIN;

CREATE TABLE IF NOT EXISTS organizer_members (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  organizer_id    UUID NOT NULL REFERENCES organizers (id) ON DELETE CASCADE,
  user_id         UUID REFERENCES users (id) ON DELETE SET NULL,
  email           TEXT NOT NULL,
  org_role        TEXT NOT NULL DEFAULT 'staff'
                  CHECK (org_role IN ('admin', 'manager', 'staff')),
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'active', 'revoked')),
  invite_token    TEXT NOT NULL,
  invited_by      UUID REFERENCES users (id) ON DELETE SET NULL,
  invited_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at     TIMESTAMPTZ,
  revoked_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT organizer_members_token_unique UNIQUE (invite_token)
);

CREATE UNIQUE INDEX IF NOT EXISTS organizer_members_org_email_active_uidx
  ON organizer_members (organizer_id, lower(email))
  WHERE status IN ('pending', 'active');

CREATE UNIQUE INDEX IF NOT EXISTS organizer_members_org_user_active_uidx
  ON organizer_members (organizer_id, user_id)
  WHERE user_id IS NOT NULL AND status = 'active';

CREATE INDEX IF NOT EXISTS organizer_members_user_idx
  ON organizer_members (user_id)
  WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS organizer_members_org_status_idx
  ON organizer_members (organizer_id, status);

COMMIT;
