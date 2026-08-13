-- Phase 29 — Identity & Security Productization
BEGIN;

ALTER TABLE platform_security_events DROP CONSTRAINT IF EXISTS platform_security_events_type_chk;
ALTER TABLE platform_security_events ADD CONSTRAINT platform_security_events_type_chk CHECK (
  event_type IN (
    'failed_login',
    'permission_escalation',
    'suspicious_activity',
    'finance_exception',
    'rate_limit_violation',
    'session_abuse',
    'mfa_enrolled',
    'mfa_verified',
    'mfa_disabled',
    'mfa_recovery',
    'account_lifecycle'
  )
);

-- Optional suspension reason on users (additive; status remains canonical lifecycle)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS suspended_reason TEXT,
  ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS suspended_by UUID REFERENCES users (id) ON DELETE SET NULL;

COMMIT;
