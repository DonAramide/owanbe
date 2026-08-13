-- Phase 25 — Hardening: notification lifecycle + webhook secret ciphertext

BEGIN;

-- Expand notification delivery statuses (keep legacy values for back-compat)
ALTER TABLE notification_deliveries DROP CONSTRAINT IF EXISTS notification_deliveries_status_check;
ALTER TABLE notification_deliveries
  ADD CONSTRAINT notification_deliveries_status_check
  CHECK (status IN (
    'pending', 'queued', 'sent', 'delivered', 'failed', 'retrying', 'dead_letter', 'skipped'
  ));

ALTER TABLE notification_deliveries
  ADD COLUMN IF NOT EXISTS attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS max_attempts INT NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS next_attempt_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_error TEXT;

CREATE INDEX IF NOT EXISTS notification_deliveries_retry_idx
  ON notification_deliveries (status, next_attempt_at)
  WHERE status IN ('queued', 'retrying', 'pending');

-- Outbound webhook secrets at rest (ciphertext); secret_key kept for migration read
ALTER TABLE platform_webhooks
  ADD COLUMN IF NOT EXISTS secrets_ciphertext TEXT;

COMMIT;
