# PHASE 5.1 VERIFICATION REPORT

**Run timestamp:** 2026-06-19T19:15:21Z (UTC)  
**Environment:** localhost — API `:8080`, Postgres `owanbe-postgres`  
**Tenant:** `11111111-1111-4111-8111-111111111111`  
**Attendee:** `22222222-2222-4222-8222-222222222222` (`attendee@owanbe.dev`)

---

## SECTION 1 — ENVIRONMENT VERIFICATION

| Check | Result | Evidence |
|-------|--------|----------|
| API running | PASS | `GET /health` → `200` `{ "status": "ok" }` |
| Database connected | PASS | `SELECT 1` succeeded |
| Migrations 016–021 | PASS | `commerce_kind` enum present (TICKET, BOOKING, REFUND, PAYOUT, SETTLEMENT); tables `ticket_orders`, `ticket_order_lines`, `ticket_payments`, `ticket_entitlements`, `organizers`, `event_ticket_tiers`, `tenant_finance_settings` exist |
| Tenant finance settings | PASS | `ticket_platform_fee_bps = 500`, `vendor_platform_fee_bps = 1000`, `escrow_release_delay_hours = 48` |
| Organizer entity | PASS | `33333333-3333-4333-8333-333333333333` — Lagos Events Co (`lagos-events-co`, active) |
| Event seed | PASS | `44444444-4444-4444-8444-444444444444` — external_ref **`evt_lagos_owanbe_2026`**, published |
| Tier seeds | PASS | **`tier_ga`**, **`tier_vip`**, **`tier_vvip`** |

---

## SECTION 2 — TICKET ORDER CREATION

**Request:** `POST /v1/events/evt_lagos_owanbe_2026/ticket-orders` — 1× GA (`tier_ga`)

| Field | Value |
|-------|-------|
| order_id | `003ac920-2ecd-4e61-a472-69e423cd3f11` |
| attendee_id | `22222222-2222-4222-8222-222222222222` |
| event_id | `44444444-4444-4444-8444-444444444444` |
| quantity | 1 |
| subtotal_minor | 1,500,000 |
| platform_fee_minor | 75,000 |
| total_minor | 1,575,000 |
| status | `pending_payment` |

**DB row confirmed** in `ticket_orders` + `ticket_order_lines`.

---

## SECTION 3 — PAYMENT INITIATION

**Request:** `POST /v1/ticket-orders/003ac920-2ecd-4e61-a472-69e423cd3f11/payments`

| Field | Value |
|-------|-------|
| payment_id | `fb909dd0-878f-4852-8a8a-81fe5d4afb10` |
| psp_reference | `OWB-DEV-fb909dd0` |
| amount_minor | 1,575,000 |
| currency | NGN |
| commerce_kind | TICKET |
| payment_status (after initiation) | `captured` (dev auto-capture) |

**DB row confirmed** in `ticket_payments`.

---

## SECTION 4 — PAYMENT CAPTURE

**Path:** Dev auto-capture (Quaser stub — `QUASER_ROUTER_BASE_URL` empty)

| Field | Value |
|-------|-------|
| status before | (no prior row) → `initiated` at insert |
| status after | **`captured`** |
| capture timestamp | `2026-06-19 19:15:21.808233+00` (`ticket_payments.updated_at`) |
| order status after | **`fulfilled`** |

---

## SECTION 5 — LEDGER VERIFICATION

**Transaction ID:** `d02f219f-a565-4908-8716-1333581dff23`  
**Reason:** `payment_capture_ticket`  
**commerce_kind:** TICKET  
**ticket_order_id:** `003ac920-2ecd-4e61-a472-69e423cd3f11`

| # | Account code | Direction | Amount (minor) | Memo |
|---|--------------|-----------|----------------|------|
| 1 | `quaser_psp_clearing_NGN` | Dr | 1,575,000 | ticket capture gross |
| 1 | `escrow_pool_NGN` | Cr | 1,575,000 | ticket capture to escrow |
| 2 | `escrow_pool_NGN` | Dr | 75,000 | platform fee |
| 2 | `platform_fees_NGN` | Cr | 75,000 | platform fee |
| 3 | `escrow_pool_NGN` | Dr | 1,500,000 | organizer share |
| 3 | `organizer_payable_33333333-3333-4333-8333-333333333333_NGN` | Cr | 1,500,000 | organizer payable |

Escrow net: +1,575,000 − 75,000 − 1,500,000 = **0**

---

## SECTION 6 — PLATFORM FEE VALIDATION

| Field | Value |
|-------|-------|
| ticket_platform_fee_bps | 500 |
| subtotal (gross ticket) | 1,500,000 |
| computed fee | 1,500,000 × 500 / 10,000 = **75,000** |
| stored platform_fee_minor | **75,000** |
| organizer share (subtotal) | 1,500,000 |
| order total | 1,575,000 |

**Match:** stored = computed ✓

---

## SECTION 7 — ORGANIZER PAYABLE

| Field | Value |
|-------|-------|
| Account | `organizer_payable_33333333-3333-4333-8333-333333333333_NGN` |
| balance_before | 0 |
| balance_after | 1,500,000 |
| credit this capture | 1,500,000 |

---

## SECTION 8 — ENTITLEMENT ISSUANCE

| Field | Value |
|-------|-------|
| entitlement_id | `72a22055-52e2-42d1-82fe-b0a8fad5abab` |
| ticket_code | `TKT-72D070D062DA` |
| qr_code | `OWANBE:44444444-4444-4444-8444-444444444444:tier_ga:TKT-72D070D062DA` |
| status | **`issued`** (schema active state) |
| attendee_id | `22222222-2222-4222-8222-222222222222` |

---

## SECTION 9 — ATTENDEE EXPERIENCE

**Request:** `GET /v1/me/ticket-entitlements`

| Field | Value |
|-------|-------|
| entitlement returned | yes |
| ticket_code | `TKT-72D070D062DA` |
| event_name | Lagos Sunset Owanbe |
| tier | General Admission |
| qrPayload | present |

Mobile attendee dashboard consumes this endpoint via `attendeeTicketsSyncProvider`.

---

## SECTION 10 — CONSISTENCY CHECK

| Component | Amount (minor) |
|-----------|----------------|
| Ticket order total | 1,575,000 |
| Platform fee | 75,000 |
| Organizer payable | 1,500,000 |
| **Sum (fee + organizer)** | **1,575,000** |
| **Difference** | **0** |

---

## FINAL GATE

| Check | Result |
|-------|--------|
| Ticket Order Created | **PASS** |
| Payment Initiated | **PASS** |
| Capture Received | **PASS** |
| Ledger Posted | **PASS** |
| Platform Fee Calculated | **PASS** |
| Organizer Payable Updated | **PASS** |
| Ticket Issued | **PASS** |
| QR Generated | **PASS** |
| Attendee Dashboard Updated | **PASS** |

## Overall Result: **PASS**

Phase 5.2 remains **NOT APPROVED** until this report is formally accepted by product owner.
