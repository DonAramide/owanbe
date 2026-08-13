# Multi-Service Vendor Commerce — Impact & Implementation Notes

## Impact assessment (reuse)

| Capability | Reused | Change |
|------------|--------|--------|
| Conversation timeline / messages | `vendor_request_id` spine | **Unchanged** |
| CRM stages / negotiation / contract derived status | Existing | Extended with agreement/fund/complete endpoints |
| Onboarding multi-select | Already multi-category + `services_offered` | No artificial max of 3 |
| Marketplace | Catalog + filters | Service filter + profile `servicesOffered`; per-service booked keys |
| Pricing | New rules table + util | Default **4000 bps (40%)**; service-specific optional |
| Escrow / wallets | No parallel wallet | `event_vendor_funds` + `vendor_request_fund_allocations`; CRM `funding_status` |
| Dual prices | Request columns | Organizer sees `servicePriceMinor` only; Vendor sees `vendorPayoutMinor` only |

## Schema (`063_multi_service_vendor_commerce.sql`)

- `UNIQUE (event_id, vendor_id, service_key)` replaces `(event_id, vendor_id)`
- Dual price columns + `funding_status`
- `platform_vendor_pricing_rules` (default 40%)
- `event_vendor_funds` / `vendor_request_fund_allocations`

## Conversation regression

`GET/POST .../vendor-requests/:requestId/timeline|messages` untouched in behavior (still stage-history notes + bypass guard).

## Manual next steps

1. Restart API to load new Nest providers.
2. Hot-restart Flutter.
3. Acceptance: multi-service request → message isolation → confirm agreement → fund event → fund booking → mark complete → confirm / report issue.
