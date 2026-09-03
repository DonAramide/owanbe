-- Phase 073 — Additive buyer context on existing Vendor CRM
-- organizer_id remains the event organization (NOT NULL). Historical rows stay organizer buyers.
-- Does not replace vendor_event_requests or create a second CRM.

BEGIN;

ALTER TABLE vendor_event_requests
  ADD COLUMN IF NOT EXISTS buyer_kind TEXT NOT NULL DEFAULT 'organizer'
    CHECK (buyer_kind IN ('organizer', 'vendor'));

ALTER TABLE vendor_event_requests
  ADD COLUMN IF NOT EXISTS buyer_vendor_id UUID NULL REFERENCES vendors (id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS vendor_event_requests_buyer_vendor_idx
  ON vendor_event_requests (tenant_id, buyer_vendor_id, updated_at DESC)
  WHERE buyer_vendor_id IS NOT NULL;

COMMENT ON COLUMN vendor_event_requests.organizer_id IS
  'Event organization (canonical event owner). Not replaced by vendor-as-buyer.';

COMMENT ON COLUMN vendor_event_requests.buyer_kind IS
  'organizer (default, existing CRM) or vendor (Phase 4 buyer context).';

COMMENT ON COLUMN vendor_event_requests.buyer_vendor_id IS
  'When buyer_kind=vendor, the procuring vendor. Null for organizer-created requests.';

COMMIT;
