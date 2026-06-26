-- Phase 35 — Program / run sheet planner
BEGIN;

CREATE TABLE IF NOT EXISTS event_program_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id          UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  title             TEXT NOT NULL,
  description       TEXT NOT NULL DEFAULT '',
  start_time        TIMESTAMPTZ NOT NULL,
  duration_minutes  INT NOT NULL DEFAULT 15 CHECK (duration_minutes > 0),
  owner_type        TEXT NOT NULL DEFAULT 'planner'
    CHECK (owner_type IN ('mc', 'bride', 'groom', 'planner', 'coordinator', 'vendor')),
  owner_id          TEXT,
  owner_name        TEXT NOT NULL DEFAULT '',
  vendor_id         UUID REFERENCES vendors (id) ON DELETE SET NULL,
  status            TEXT NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned', 'ready', 'in_progress', 'completed', 'skipped', 'delayed')),
  sort_order        INT NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_activity_log (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id          UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  program_item_id   UUID REFERENCES event_program_items (id) ON DELETE SET NULL,
  activity_kind     TEXT NOT NULL
    CHECK (activity_kind IN (
      'program_created', 'program_updated', 'program_started',
      'program_completed', 'program_delayed', 'program_reminder'
    )),
  headline          TEXT NOT NULL,
  detail            TEXT NOT NULL DEFAULT '',
  metadata          JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_program_reminders (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id          UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  program_item_id   UUID NOT NULL REFERENCES event_program_items (id) ON DELETE CASCADE,
  offset_minutes    INT NOT NULL CHECK (offset_minutes IN (5, 15)),
  remind_at         TIMESTAMPTZ NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (program_item_id, offset_minutes)
);

CREATE INDEX IF NOT EXISTS event_program_items_event_idx
  ON event_program_items (tenant_id, event_id, sort_order, start_time);

CREATE INDEX IF NOT EXISTS event_activity_log_event_idx
  ON event_activity_log (tenant_id, event_id, created_at DESC);

CREATE INDEX IF NOT EXISTS event_program_reminders_due_idx
  ON event_program_reminders (tenant_id, event_id, status, remind_at)
  WHERE status = 'pending';

COMMIT;
