# Phase 5.3 — Finance Consolidation

Completes the money lifecycle before Platform Administration (Phase 6). No new admin dashboards — unfinished workflows wired into existing finance surfaces.

## Sprint Map

| Sprint | Scope | Key deliverables |
|--------|-------|------------------|
| **5.3A** | Organizer Payout Rail | `POST /v1/organizers/:id/payouts`, ledger release, Quaser webhook branch, mobile withdraw |
| **5.3B** | Refund Operations | `ticket_refund_cases` queue, approve/reject/escalate, ledger on complete |
| **5.3C** | Vendor Finance Cutover | `VendorFinanceApi` primary; `VendorStore` only with `ALLOW_MOCK_FINANCE_FALLBACK=true` |
| **5.3D** | Admin Finance Completion | Refund/chargeback on transactions, recon run, ticket refund tab |
| **5.3E** | Transaction Exports | `GET /v1/admin/finance/exports/:kind?format=csv\|xlsx` |
| **5.3F** | Reconciliation Automation | Ticket capture ↔ ledger checks, treasury dual-write mismatch detection |

## API — Organizer Payouts (5.3A)

```
POST /v1/organizers/:organizerId/payouts?amountMinor=<minor>
```

Auth: Commerce auth (JWT or dev headers).

States: `pending` → `processing` → `completed` | `failed`

Eligibility per ticket order:
- Order `fulfilled` or `confirmed`
- Escrow released (`escrow_release_not_before <= now()`)
- No open refund case
- No in-flight/completed payout for that order

Ledger on complete: Dr `organizer_payable` / Cr `organizer_payout_clearing` (`payout_organizer_release`)

Dev stub (`QUASER_ROUTER_BASE_URL` empty) auto-completes payout.

## API — Ticket Refunds (5.3B)

| Method | Path | Role |
|--------|------|------|
| POST | `/v1/ticket-orders/:orderId/refunds` | Buyer (commerce auth) |
| GET | `/v1/admin/finance/ticket-refunds` | Admin finance |
| GET | `/v1/admin/finance/ticket-refunds/:caseId` | Admin finance |
| POST | `/v1/admin/finance/ticket-refunds/:caseId/:action` | Admin finance (`approve`, `reject`, `escalate`) |

Workflow: `requested` → `under_review` (escalate) → `approved` → `completed` (second approve) | `rejected`

On `completed`:
- Entitlements → `refunded`
- Ledger `payment_refund_ticket`: Dr organizer_payable + platform_fees, Cr PSP clearing

## API — Exports (5.3E)

```
GET /v1/admin/finance/exports/:kind?format=csv|xlsx&limit=500
```

Kinds: `transactions`, `payouts`, `organizer-payouts`, `refunds`, `settlements`

## Reconciliation (5.3F)

`POST /v1/admin/finance/reconciliation/run` now also detects:
- Captured `ticket_payments` missing `payment_capture_ticket` ledger
- Orphan ticket capture ledger rows
- Treasury settlements with dual-write gaps

## Mobile

| Surface | Change |
|---------|--------|
| Event Workspace → Finance | **Request payout** button |
| Admin → Under Review | **Ticket refunds** tab |
| Admin → Transactions | Refund / Chargeback on captured payments |
| Admin → Reconciliation | **Run reconciliation** |
| Vendor wallet/dashboard | API-first finance (`ALLOW_MOCK_FINANCE_FALLBACK` for offline dev) |

## Dev configuration

```
# API
ALLOW_DEV_COMMERCE_AUTH=true
QUASER_ROUTER_BASE_URL=          # empty = stub auto-capture + auto-payout

# Mobile
OWANBE_API_BASE=http://localhost:8080/v1
OWANBE_TENANT_ID=11111111-1111-4111-8111-111111111111
OWANBE_ORGANIZER_USER_ID=22222222-2222-4222-8222-222222222222
ALLOW_MOCK_FINANCE_FALLBACK=false   # vendor finance: API required
```

Dev seed (`021_phase5_dev_commerce_seed.sql`) sets `escrow_release_delay_hours=0` so payouts are testable immediately after ticket capture.

Organizer ID: `33333333-3333-4333-8333-333333333333`

## Verification

```bash
node scripts/verify-phase5-3-finance-consolidation.js
```

Full commerce E2E (includes capture → ledger → entitlement):

```bash
node scripts/phase5-1-full-verification.js
```

## Phase gate (before Phase 6)

| Check | Required |
|-------|----------|
| Organizer Payouts | ✅ |
| Refund Operations | ✅ |
| Vendor Finance Unified | ✅ |
| Admin Finance Complete | ✅ |
| Exports | ✅ |
| Reconciliation | ✅ |
