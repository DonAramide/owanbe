# Phase 5.1 — Real Ticket Commerce Rail

Apply migrations **016 → 019 → 020 → 021** (in order), then start API.

## Dev tenant (seed 021)

| Key | Value |
|-----|-------|
| `OWANBE_TENANT_ID` | `11111111-1111-4111-8111-111111111111` |
| Event external ref | `evt_lagos_owanbe_2026` |
| Tier IDs | `tier_ga`, `tier_vip`, `tier_vvip` |

## API endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/v1/events/:eventId/ticket-orders` | Create order (no payment) |
| POST | `/v1/ticket-orders/:id/payments` | Initiate Quaser payment |
| GET | `/v1/ticket-orders/:orderId` | Order status |
| GET | `/v1/me/ticket-entitlements` | Issued tickets |

## Dev auth (no Supabase JWT)

Set `ALLOW_DEV_COMMERCE_AUTH=true` (default in development).

Headers:
- `X-Tenant-Id`
- `X-Dev-User-Id`
- `X-Dev-User-Email`

## Capture flow

When `QUASER_ROUTER_BASE_URL` is empty (dev stub), payment initiation **auto-captures** and issues entitlements.

Production: Quaser webhook `payment.captured` with `payment_id` = `ticket_payments.id` triggers `owanbe_apply_ticket_payment_capture`.

## Ledger posting (capture)

1. Dr PSP Clearing / Cr Escrow (gross)
2. Dr Escrow / Cr Platform Fees (fee)
3. Dr Escrow / Cr Organizer Payable (subtotal)

## Mobile

Set in `assets/env/supabase.env` or `.env`:
```
OWANBE_API_BASE=http://localhost:8080/v1
OWANBE_TENANT_ID=11111111-1111-4111-8111-111111111111
```

## Verification (Phase 5.2 gate)

With API running and `DATABASE_URL` set:

```bash
node scripts/verify-phase5-1-ticket-commerce.js
```

Checks: order → payment → capture → ledger → platform fee → organizer payable → entitlements.
