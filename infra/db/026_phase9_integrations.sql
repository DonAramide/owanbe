-- Phase 9 — Production Integrations
BEGIN;

CREATE TABLE IF NOT EXISTS notification_deliveries (
  id              BIGSERIAL PRIMARY KEY,
  tenant_id       UUID REFERENCES tenants (id) ON DELETE SET NULL,
  channel         TEXT NOT NULL CHECK (channel IN ('email', 'sms', 'push')),
  template        TEXT NOT NULL DEFAULT '',
  recipient       TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'failed', 'skipped')),
  provider        TEXT NOT NULL DEFAULT '',
  external_id     TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  error_message   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS notification_deliveries_tenant_idx
  ON notification_deliveries (tenant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS media_objects (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  bucket          TEXT NOT NULL,
  object_key      TEXT NOT NULL,
  content_type    TEXT NOT NULL DEFAULT 'application/octet-stream',
  size_bytes      BIGINT,
  public_url      TEXT NOT NULL DEFAULT '',
  uploaded_by     UUID REFERENCES users (id) ON DELETE SET NULL,
  purpose         TEXT NOT NULL DEFAULT 'general',
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, bucket, object_key)
);

CREATE INDEX IF NOT EXISTS media_objects_tenant_idx ON media_objects (tenant_id, created_at DESC);

COMMIT;
