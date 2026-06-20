# Phase 5.2 — Organizer Finance Center

Ledger-backed finance for event organizers. Built inside Event Workspace → Finance tab.

## API

| Method | Path | Auth |
|--------|------|------|
| GET | `/v1/events/:eventId/finance/summary` | Commerce auth (JWT or dev headers) |
| GET | `/v1/events/:eventId/finance/transactions` | Commerce auth |

`:eventId` accepts UUID, `external_ref`, or slug (e.g. `evt_lagos_owanbe_2026`).

### Summary fields (ledger-backed)

- **ticketRevenueMinor** — sum of fulfilled order subtotals (organizer share)
- **platformFeeMinor** — sum of platform fees on fulfilled orders
- **netEarningsMinor** — organizer share for event
- **availableForPayoutMinor** — `organizer_payable` ledger balance − pending payouts − escrow hold
- **payoutEligible** — whether payout can be requested

### Data sources

- `ticket_orders`, `ticket_refund_cases`
- `ledger_accounts` (`organizer_payable`)
- `ledger_transactions` / `ledger_lines` (`payment_capture_ticket`)
- `organizer_payouts`

## Mobile

Event workspace Finance tab (`/organizer/events/:id?tab=4`) calls `OrganizerFinanceApi`.

Dev env (same as Phase 5.1):

```
OWANBE_API_BASE=http://localhost:8080/v1
OWANBE_TENANT_ID=11111111-1111-4111-8111-111111111111
OWANBE_ORGANIZER_USER_ID=22222222-2222-4222-8222-222222222222
```

## Vendor parallel wiring

`vendorWalletProvider`, `vendorWalletEntriesProvider`, and `vendorPayoutsProvider` use `VendorFinanceApi` as the primary source. `VendorStore` mock fallback applies only when `ALLOW_MOCK_FINANCE_FALLBACK=true` in mobile `.env`.
