-- Phase 066 — Per-service base payout on vendor_services + request markup snapshot
-- Additive. Does not replace vendor_packages or pricing rules.

BEGIN;

ALTER TABLE vendor_services
  ADD COLUMN IF NOT EXISTS base_payout_minor BIGINT
    CHECK (base_payout_minor IS NULL OR base_payout_minor >= 0);

ALTER TABLE vendor_services
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'NGN';

COMMENT ON COLUMN vendor_services.base_payout_minor IS
  'Vendor/base payout for this bookable service (minor units). Authoritative commercial base; packages remain optional catalog.';

-- Backfill from name-matched active packages (lowest payout wins).
UPDATE vendor_services vs
SET
  base_payout_minor = sub.unit_amount_minor,
  currency = COALESCE(NULLIF(sub.currency, ''), vs.currency),
  updated_at = now()
FROM (
  SELECT DISTINCT ON (vs2.id)
    vs2.id AS service_id,
    p.unit_amount_minor,
    p.currency
  FROM vendor_services vs2
  INNER JOIN vendor_packages p
    ON p.tenant_id = vs2.tenant_id
   AND p.vendor_id = vs2.vendor_id
   AND COALESCE(p.is_active, true) = true
   AND lower(trim(p.name)) = lower(trim(vs2.service_name))
  WHERE vs2.base_payout_minor IS NULL
  ORDER BY vs2.id, p.unit_amount_minor ASC
) sub
WHERE vs.id = sub.service_id
  AND vs.base_payout_minor IS NULL
  AND sub.unit_amount_minor IS NOT NULL
  AND sub.unit_amount_minor > 0;

ALTER TABLE vendor_event_requests
  ADD COLUMN IF NOT EXISTS pricing_markup_bps INTEGER
    CHECK (pricing_markup_bps IS NULL OR (pricing_markup_bps >= 0 AND pricing_markup_bps <= 9000));

COMMENT ON COLUMN vendor_event_requests.pricing_markup_bps IS
  'Markup bps snapshotted at request creation. Historical requests must not recalculate when admin rules change.';

COMMIT;
