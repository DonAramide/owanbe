-- Phase 3A — Seating planner (tables, guest assignment, layout)
BEGIN;

CREATE TABLE IF NOT EXISTS event_seating_layouts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  name            TEXT NOT NULL DEFAULT 'Main floor',
  canvas_width    INT NOT NULL DEFAULT 900 CHECK (canvas_width > 0),
  canvas_height   INT NOT NULL DEFAULT 640 CHECK (canvas_height > 0),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_id)
);

CREATE TABLE IF NOT EXISTS event_seating_tables (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  layout_id       UUID NOT NULL REFERENCES event_seating_layouts (id) ON DELETE CASCADE,
  label           TEXT NOT NULL,
  table_kind      TEXT NOT NULL DEFAULT 'round'
    CHECK (table_kind IN ('round', 'rectangular', 'head', 'vip')),
  capacity        INT NOT NULL DEFAULT 8 CHECK (capacity > 0),
  is_vip          BOOLEAN NOT NULL DEFAULT false,
  position_x      DOUBLE PRECISION NOT NULL DEFAULT 40,
  position_y      DOUBLE PRECISION NOT NULL DEFAULT 40,
  rotation_deg    DOUBLE PRECISION NOT NULL DEFAULT 0,
  sort_order      INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_seating_assignments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  table_id        UUID NOT NULL REFERENCES event_seating_tables (id) ON DELETE CASCADE,
  guest_ref       TEXT NOT NULL,
  guest_name      TEXT NOT NULL,
  seat_index      INT CHECK (seat_index IS NULL OR seat_index >= 0),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (table_id, guest_ref)
);

CREATE INDEX IF NOT EXISTS event_seating_tables_event_idx
  ON event_seating_tables (tenant_id, event_id, sort_order);

CREATE INDEX IF NOT EXISTS event_seating_assignments_event_idx
  ON event_seating_assignments (tenant_id, event_id);

CREATE INDEX IF NOT EXISTS event_seating_assignments_table_idx
  ON event_seating_assignments (table_id);

COMMIT;
