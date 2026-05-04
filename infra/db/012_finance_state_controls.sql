-- Global finance state gate for emergency controls.
-- Apply after 011_financial_review_flags.sql.

BEGIN;

DO $enum$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t WHERE t.typname = 'finance_system_state'
  ) THEN
    CREATE TYPE finance_system_state AS ENUM ('normal', 'restricted', 'frozen');
  END IF;
END
$enum$;

CREATE TABLE IF NOT EXISTS finance_system_state_control (
  id               BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id = TRUE),
  state            finance_system_state NOT NULL DEFAULT 'normal',
  changed_by_user_id UUID REFERENCES users (id) ON DELETE SET NULL,
  reason           TEXT,
  metadata         JSONB NOT NULL DEFAULT '{}'::JSONB,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO finance_system_state_control (id, state, reason)
VALUES (TRUE, 'normal', 'bootstrap')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE finance_system_state_control IS
  'Singleton global finance gate: normal|restricted|frozen for emergency operations.';

COMMIT;
