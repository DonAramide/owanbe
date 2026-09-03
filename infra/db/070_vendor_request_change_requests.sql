-- Phase 070 — Structured vendor change requests (Phase 3C)
-- Additive. Does NOT mutate vendor_event_requests until a change is accepted.
-- Does NOT alter pricing, capabilities catalogue, or Event Operations SSE.
-- Parent relationship remains vendor_event_requests; this table stores proposals.

BEGIN;

CREATE TABLE IF NOT EXISTS vendor_request_change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  vendor_request_id uuid NOT NULL REFERENCES vendor_event_requests(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  vendor_id uuid NOT NULL REFERENCES vendors(id) ON DELETE RESTRICT,
  organizer_id uuid NOT NULL REFERENCES organizers(id) ON DELETE RESTRICT,
  requested_by_user_id uuid NOT NULL,
  responded_by_user_id uuid,
  type text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  -- Snapshot of booking-relevant state when the change was requested (immutable after create).
  original_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- Structured proposal (capability key, startsAt/endsAt, venue fields, requirement text, etc.).
  requested_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- Snapshot after acceptance (or decline note); never deletes original_snapshot.
  response_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  CONSTRAINT vendor_request_change_requests_type_check CHECK (
    type = ANY (ARRAY[
      'ADD_CAPABILITY',
      'REMOVE_CAPABILITY',
      'CHANGE_DATE',
      'CHANGE_TIME',
      'CHANGE_VENUE',
      'SPECIAL_REQUIREMENT'
    ])
  ),
  CONSTRAINT vendor_request_change_requests_status_check CHECK (
    status = ANY (ARRAY['pending', 'accepted', 'declined', 'cancelled', 'expired'])
  )
);

CREATE INDEX IF NOT EXISTS vendor_request_change_requests_parent_idx
  ON vendor_request_change_requests (tenant_id, vendor_request_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS vendor_request_change_requests_vendor_idx
  ON vendor_request_change_requests (tenant_id, vendor_id, status, created_at DESC);

COMMENT ON TABLE vendor_request_change_requests IS
  'Phase 3C structured change proposals against an existing vendor_event_request. Pending changes do not mutate the parent booking.';

COMMENT ON COLUMN vendor_request_change_requests.original_snapshot IS
  'Frozen view of parent/event state at request time for auditability.';

COMMENT ON COLUMN vendor_request_change_requests.requested_payload IS
  'Structured proposal only — not a chat message body.';

COMMIT;
