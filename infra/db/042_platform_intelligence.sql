-- Enterprise Decision Intelligence Platform (EDIP) Database Schema
BEGIN;

CREATE TABLE IF NOT EXISTS ai_recommendations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category        TEXT NOT NULL, -- 'commerce', 'security', 'operations', 'marketing'
  label           TEXT NOT NULL,
  reasoning       TEXT NOT NULL,
  confidence_score NUMERIC(4,3) NOT NULL,
  business_impact TEXT NOT NULL,
  financial_impact NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  required_permission TEXT NOT NULL,
  suggested_action TEXT NOT NULL,
  deep_link       TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'active', -- 'active', 'dismissed', 'executed'
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_anomalies (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anomaly_type    TEXT NOT NULL, -- 'refund_spike', 'payment_failed', 'security_drift'
  description     TEXT NOT NULL,
  severity        TEXT NOT NULL, -- 'low', 'medium', 'high'
  source_engine   TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_predictions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key      TEXT NOT NULL, -- 'attendance', 'ticket_sales', 'traffic'
  forecast_value  NUMERIC(12,2) NOT NULL,
  confidence_lower NUMERIC(12,2),
  confidence_upper NUMERIC(12,2),
  target_date     DATE NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed defaults logs
INSERT INTO ai_recommendations (category, label, reasoning, confidence_score, business_impact, financial_impact, required_permission, suggested_action, deep_link) VALUES
  (
    'operations',
    'Approve Pending Vendors',
    '3 vendors have been in the onboarding verification queue for > 48 hours.',
    0.950,
    'Speeds up vendor onboarding flow and adds marketplace depth.',
    1200000.00,
    'vendor.approve',
    'Go to Verification Center and approve compliance documents.',
    '/admin/verifications'
  ),
  (
    'commerce',
    'Launch Reminder Campaign',
    'Ticket sales for Owanbe Staging Gala are slowing down. predicted attendance is dropping.',
    0.890,
    'Boosts ticket sales and increases weekend event attendance.',
    8500000.00,
    'campaign.create',
    'Go to Communication Center and launch the scheduled reminder campaign.',
    '/admin/communications'
  ),
  (
    'security',
    'Investigate Security Incidents',
    'Drift detected in MFA authentication settings for usr_1.',
    0.980,
    'Protects administrator accounts against credential compromise.',
    0.00,
    'security.write',
    'Go to Security Center and verify authentication logs.',
    '/admin/security'
  );

INSERT INTO ai_anomalies (anomaly_type, description, severity, source_engine) VALUES
  ('refund_spike', 'Refund rate increased by 18% over the last 24 hours.', 'high', 'CommerceEngine'),
  ('security_drift', 'MFA config drift detected on usr_1.', 'medium', 'SecurityEngine');

INSERT INTO ai_predictions (metric_key, forecast_value, target_date) VALUES
  ('attendance', 1240.00, '2026-07-04'),
  ('ticket_sales', 4500000.00, '2026-07-04');

COMMIT;
