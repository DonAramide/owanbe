# PHASE 4 — TICKET PURCHASE & REGISTRATION GAP ANALYSIS

**Date:** 2026-07-24  
**Scope:** Attendee Ticket Purchase & Registration (selection → payment → digital tickets)  
**Surfaces:** Flutter `mobile/`, Nest `services/api/`, DB `infra/db/`  
**Method:** Evidence-only audit — **no code was written or modified**

---

## Executive verdict

The **structural happy path exists** in the Attendee Workspace:

`Discover / Event Detail → Ticket Select → Checkout → POST order + payment → Payment Success → My Tickets (entitlements)`

Backend ticket commerce (orders, payments, capture, ledger, entitlements, refunds queue, confirmation email) is **substantially built**. Flutter screens for select/checkout/success/My Tickets are **wired**.

Phase 4 is **not certification-ready** because:

1. Production Quaser / hosted payment UX is missing (`clientActionUrl`, polling).  
2. Payment response entitlements are a **partial DTO** vs Flutter’s strict `TicketEntitlementResponse`.  
3. Post-purchase sync writes the **deprecated local** `attendeeTicketsProvider` instead of invalidating `attendeeTicketsSyncProvider`.  
4. QR is an **icon + text**, not a scannable code.  
5. Order history, buyer refunds, resend ticket, push notifications, and Apple/Google Wallet are **absent or admin-only**.

| Layer | Maturity |
|-------|----------|
| DB + Nest ticket rail | High |
| Attendee purchase UI (stub/dev) | Medium |
| Prod payment + async capture UX | Low |
| Digital pass / QR / wallet | Low |
| Order management & buyer refunds | Low |
| Push / in-app purchase alerts | Not implemented |

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | Present and wired for the intended attendee path |
| **Implemented but Hidden** | Built but not surfaced on the primary attendee flow |
| **Implemented but Not Wired** | Exists in codebase; wrong provider/route/contract |
| **Backend Complete / Frontend Missing** | API/DB ready; attendee UI/client missing |
| **Frontend Complete / Backend Missing** | UI exists; backend support missing |
| **Partially Implemented** | Incomplete across layers |
| **Not Implemented** | No meaningful product implementation |

---

## Happy-path architecture

```
AttendeeDiscoverTab / AttendeeEventDetailScreen
  → AttendeeTicketSelectScreen (+ TicketTierCard, quantity)
  → cartProvider (CartLine)
  → AttendeeCheckoutScreen
  → TicketCommerceApi.createTicketOrder
       POST /v1/events/:eventId/ticket-orders
  → TicketCommerceApi.createTicketPayment
       POST /v1/ticket-orders/:orderId/payments
  → TicketPaymentsService → (stub) TicketCaptureService.applyCapture
                         → (prod) Quaser + webhook capture
  → ticket_entitlements + NotificationService.sendTicketConfirmation
  → AttendeePaymentSuccessScreen
  → AttendeeTicketsTab ← attendeeTicketsSyncProvider
       GET /v1/me/ticket-entitlements
```

**Parallel legacy path:** `/events/:id/tickets` → `TicketSelectScreen` → `/checkout` → `CheckoutScreen` (same cart + APIs).

---

## Primary files & modules

| Layer | Paths |
|-------|--------|
| Ticket select | `mobile/lib/portals/attendee/screens/attendee_ticket_select_screen.dart` |
| Tier UI | `mobile/lib/features/public/widgets/ticket_tier_card.dart` |
| Cart | `cartProvider` in `public_providers.dart`; `CartLine` in `public_models.dart` |
| Checkout | `attendee_checkout_screen.dart`; public `checkout_screen.dart` |
| Success | `attendee_payment_success_screen.dart` |
| My Tickets | `attendee_tickets_tab.dart`; `attendee_events_provider.dart` |
| QR sheet | `showAttendeeQrSheet` in `attendee_event_card.dart` |
| API client | `mobile/lib/core/api/ticket_commerce_api.dart` |
| Providers | `ticket_commerce_providers.dart` (`checkoutEntitlementsProvider`) |
| Nest controller | `services/api/src/modules/commerce/ticket-commerce.controller.ts` |
| Orders / payments / capture | `ticket-orders.service.ts`, `ticket-payments.service.ts`, `ticket-capture.service.ts` |
| Entitlements / refunds | `ticket-entitlements.service.ts`, `ticket-refund.controller.ts` |
| Quaser | `quaser-router.service.ts`, `quaser-webhook.service.ts` |
| DB | `infra/db/016_phase5_ticket_commerce_foundation.sql`, `020_phase5_ticket_tiers_and_capture.sql`, `028_identity_v101.sql` |

---

## 1. Ticket Selection

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Attendee select screen | **Implemented and Working** | `AttendeeTicketSelectScreen`, route `/attendee/events/:eventId/tickets` | — | — |
| Public select (legacy) | **Implemented and Working** | `ticket_select_screen.dart` | Duplicate of attendee flow | Small (optional consolidate) |
| Quantity selector | **Implemented and Working** | `TicketTierCard` +/−, remaining, sold-out | — | — |
| Tier pricing / inventory display | **Implemented and Working** | From `publicEventProvider` / `loadTiersForEvent` | — | — |
| Sales window on select UI | **Partially Implemented** | Dates on detail tiers; **not** on `TicketTierCard` | Not shown/enforced at select | Small |
| Sales window server enforcement | **Not Implemented** | Orders check pause/inventory; no `salesStartAt`/`salesEndAt` gate in `ticket-orders.service.ts` | Can buy outside window | Medium |
| Detail → Select CTA | **Implemented and Working** | `AttendeeEventDetailScreen` → `AttendeeRoutes.eventTickets` | — | — |

---

## 2. Cart

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| In-memory cart | **Implemented and Working** | `CartNotifier` / `cartProvider` | — | — |
| CartLine model | **Implemented and Working** | `public_models.dart` | — | — |
| Multi-event cart | **Partially Implemented** | Checkout uses `cart.first.eventId` | Single-event assumption | Small |
| Persisted / cross-session cart | **Not Implemented** | Memory only | Lost on refresh | Medium |
| Intermediate cart screen | **Implemented but Hidden** | Select clears cart and jumps to checkout | By design | — |
| Cart badge in attendee shell | **Not Implemented** | `cartCountProvider` unused in attendee nav | — | Small |

---

## 3. Checkout

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Attendee checkout UI | **Implemented and Working** | Order summary, Pay, error banner | Assumes workspace session | Small |
| Public checkout | **Implemented and Working** | Sign-in redirect + `EosResponsive` | — | — |
| Empty cart state | **Implemented and Working** | Both screens | — | — |
| Idempotency keys | **Implemented and Working** | Checkout → API headers; Nest honors | — | — |
| Offline / retry UX | **Partially Implemented** | 12s HTTP timeout | No offline queue | Medium |

---

## 4. Payment

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Create payment API | **Implemented and Working** | `POST ticket-orders/:orderId/payments` | — | — |
| Stub auto-capture | **Implemented and Working** | Stub Quaser → `TicketCaptureService.applyCapture` | Dev path | — |
| Quaser router | **Partially Implemented** | Real HTTP when configured; stub otherwise | Staging E2E historically incomplete | Medium |
| `clientActionUrl` to Flutter | **Frontend Complete / Backend Missing** (surface) / **Partially Implemented** | Type allows `quaser.clientActionUrl`; buildResult may not expose initiate URL to client UX | App never opens hosted pay | Medium |
| Flutter hosted payment / WebView | **Not Implemented** | One-shot POST; no polling | Prod pay cannot complete in-app | **Large** |
| Order status polling | **Backend Complete / Frontend Missing** | `GET ticket-orders/:orderId` | No mobile client/UI | Medium |
| Entitlement parse after pay | **Partially Implemented** | Flutter maps payment `entitlements` via full `TicketEntitlementResponse.fromJson`; API `loadEntitlements` returns **id, ticketCode, qrPayload, tierName** only | Contract mismatch → parse/success gaps | **Small** |

**Blocker:** Align payment entitlement DTO **or** after pay call `GET me/ticket-entitlements` instead of trusting partial payment payload.

---

## 5. Ticket Orders

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Create order + inventory lock | **Implemented and Working** | `ticket-orders.service.ts` (`FOR UPDATE`, fees) | — | — |
| Order status enum (DB) | **Implemented and Working** | `ticket_order_status` in 016 | — | — |
| Get order by id | **Backend Complete / Frontend Missing** | Controller + service; no Flutter method/UI | Needed for async pay | Medium |
| Cancel unpaid order | **Not Implemented** | No cancel API/UI | Inventory release not exposed | Medium |
| Buyer order history | **Not Implemented** | No list endpoint/UI for buyer | — | Medium |

**DB entities:** `ticket_orders`, `ticket_order_lines`, `event_ticket_tiers`, payment/ledger tables from Phase 5 foundation migrations.

---

## 6. Registration / Entitlement linking

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Issue entitlements on capture | **Implemented and Working** | `ticket-capture.service.ts` | — | — |
| List my entitlements | **Implemented and Working** | `GET me/ticket-entitlements` + `fetchMyEntitlements` | — | — |
| Link entitlements on sign-in | **Implemented and Working** | `POST me/ticket-entitlements/link` via `auth_notifier` | Failures swallowed | Small |
| Guest pre-account claim UI | **Partially Implemented** | Guest columns in 028; `lookupInvitations` unused in portals | No claim-by-email purchase path | Medium |
| Attendee onboarding | **Partially Implemented** | Profile onboarding; not purchase-specific | — | Small |

---

## 7. Digital Tickets / My Tickets

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Tickets tab sync | **Implemented and Working** | `attendeeTicketsSyncProvider` | — | — |
| Ticket cards / dashboard | **Implemented and Working** | `AttendeeTicketsTab`, `AttendeeEventCard` | — | — |
| Find my ticket | **Partially Implemented** | Local filter over synced list | No invitation lookup | Small |
| Post-purchase sync | **Implemented but Not Wired** | Success → `attendeeTicketsProvider.addAll`; list reads **sync** provider | Tickets stale until pull-to-refresh | **Small** |
| Event enrichment perf | **Partially Implemented** | N× `publicEventProvider` per entitlement | N+1 fetches | Medium |

---

## 8. QR Codes

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Server `qrPayload` | **Implemented and Working** | Capture: `OWANBE:{eventId}:{tierId}:{ticketCode}` | — | — |
| Ops QR check-in | **Implemented and Working** | Event operations / `performQrCheckIn` | Ops surface, not purchase | — |
| Attendee QR display | **Partially Implemented** | `Icons.qr_code_2` + selectable text; **no** `qr_flutter` | Not scannable at gate | **Small** |
| Synthetic detail QR | **Partially Implemented** | Fallback `OWANBE:$eventId` | Weaker than entitlement payload | Small |

---

## 9. Event Pass

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| In-app pass experience | **Partially Implemented** | Marketing copy + QR sheet | No dedicated pass layout / brightness / offline cache | Medium |
| Branded pass artwork | **Not Implemented** | — | — | Medium |

---

## 10. Order Management

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Order history | **Not Implemented** | — | — | Medium |
| Order status UI | **Backend Complete / Frontend Missing** | `GET ticket-orders/:orderId` | — | Medium |
| Cancel pending | **Not Implemented** | — | — | Medium |
| Admin refunds queue | **Implemented and Working** | Admin finance + `ticket-refund` admin routes | Not attendee | — |

---

## 11. Notifications

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Email on capture | **Partially Implemented** | `NotificationService.sendTicketConfirmation` | Provider/config dependent; non-blocking | Medium (ops) |
| Push on purchase | **Not Implemented** | Push path log-only / unwired | — | Medium |
| In-app purchase alert | **Not Implemented** | — | — | Small |
| Resend ticket | **Backend Complete / Frontend Missing** | `POST ticket-entitlements/:id/resend` | No mobile overflow action | **Small** |

---

## 12. Emails

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Ticket confirmation template | **Partially Implemented** | `ticket_confirmation` HTML with code | No QR image in email | Medium |
| Resend API | **Backend Complete / Frontend Missing** | Entitlements service | — | Small |
| Email infrastructure admin | **Implemented but Hidden** | Super-admin email screens | Not attendee | — |

---

## 13. Wallet Integration

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Apple Wallet / Google Wallet | **Not Implemented** | No PassKit / Google Wallet in repo | — | **Large** |
| Vendor ledger wallet | **Not Implemented** (for tickets) | Vendor wallet only | Unrelated | — |
| In-app ticket list as “wallet” | **Partially Implemented** | My Tickets = entitlement list | Not a payment pass | — |

---

## 14. Refunds

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Buyer create refund case | **Backend Complete / Frontend Missing** | `POST ticket-orders/:orderId/refunds` | No Flutter client/UI | Medium |
| Admin approve/reject | **Implemented and Working** | Admin finance panel | — | — |
| Entitlement → refunded | **Implemented and Working** | Refund service updates status | — | — |

---

## 15. Technical Quality

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Loading states | **Implemented and Working** | Select / checkout / tickets refresh | — | — |
| Error states | **Partially Implemented** | Checkout banner | Weak payment code mapping | Small |
| Empty states | **Implemented and Working** | Empty cart / no tickets | — | — |
| Offline (checkout) | **Partially Implemented** | Detail has offline banner | Checkout not offline-aware | Medium |
| Responsive checkout | **Partially Implemented** | Public responsive; attendee single column | — | Small |
| Performance (My Tickets) | **Partially Implemented** | N+1 event fetches | — | Medium |
| Verification scripts | **Implemented and Working** | `verify-phase5-1-ticket-commerce.js` etc. | Flutter not in loop | — |

---

## Master gap matrix (Phase 4 blockers first)

| Gap | Classification | Effort | Severity |
|-----|----------------|--------|----------|
| Payment entitlement JSON ↔ Flutter model | Partially Implemented | Small | **High** |
| Invalidate `attendeeTicketsSyncProvider` after pay | Implemented but Not Wired | Small | **High** |
| Hosted Quaser / `clientActionUrl` + polling | Not Implemented / BE-FE gap | Medium–Large | **High** |
| Scannable QR widget | Partially Implemented | Small | Medium |
| Resend confirmation from ticket card | Backend Complete / FE Missing | Small | Medium |
| Order detail + history | Backend Complete / FE Missing / NI | Medium | Medium |
| Buyer refund request UI | Backend Complete / FE Missing | Medium | Medium |
| Sales window enforce (UI + server) | Partially / Not Implemented | Medium | Medium |
| Push / in-app purchase notify | Not Implemented | Medium | Medium |
| Cancel unpaid order | Not Implemented | Medium | Low–Medium |
| Guest claim flow | Partially Implemented | Medium | Medium |
| Apple/Google Wallet | Not Implemented | Large | Low (defer) |

---

## Single-sprint implementation roadmap

Ordered for **one Phase 4 completion sprint**. Reuse Nest commerce + existing screens; do not rebuild checkout architecture.

### Wave A — Unblock stub/dev E2E (Small)

1. **Align payment entitlements** — enrich `loadEntitlements` **or** after pay call `fetchMyEntitlements` and skip strict parse of partial payload.  
2. **Invalidate tickets sync** on success — `ref.invalidate(attendeeTicketsSyncProvider)` (and keep optional local add).  
3. **Scannable QR** — add QR package; render `qrPayload` in `showAttendeeQrSheet`.  
4. **Resend ticket** — wire `POST ticket-entitlements/:id/resend` from ticket overflow.

### Wave B — Production payment (Medium–Large)

5. **Surface `clientActionUrl`** from payment create result.  
6. **Flutter hosted pay** — external URL / WebView + return deep link.  
7. **`GET ticket-orders/:orderId` client + polling** until captured/failed; then sync entitlements.  
8. **Map payment error codes** to human checkout copy.

### Wave C — Order lifecycle & trust (Medium)

9. **Buyer order history / detail** screen.  
10. **Buyer refund request** using existing refund POST.  
11. **Sales window** display on select + server validation.  
12. **Cancel unpaid order** API + UI (if product requires).

### Wave D — Engagement (Medium)

13. **In-app success snackbar / home feed item.**  
14. **Push template** on capture (when push infra ready).  
15. **Guest claim** via existing invitation lookup + link.

### Explicit deferrals (out of sprint unless capacity)

16. **Apple Wallet / Google Wallet** (Large).  
17. Full public/attendee checkout UI consolidation.  
18. Multi-event cart.

### Non-goals

- Do not redesign Event Details or Discover.  
- Do not duplicate Nest commerce services.  
- Do not start Phase 5.

---

## Recommended Phase 4 “PASS” bar

Treat Phase 4 as **PASS** when:

- Stub and configured Quaser paths both leave the attendee with entitlements visible on My Tickets without manual refresh.  
- Payment success never depends on a mismatched partial entitlement DTO.  
- QR sheet is scannable by ops check-in.  
- Attendee can resend confirmation.  
- Async/prod payment either completes via hosted URL + poll **or** is explicitly scoped as PARTIAL with documented ops-only capture.  
- Buyer refund request is available **or** explicitly deferred with PARTIAL certification.

Wallet passes may remain **PARTIAL / deferred** if product agrees.

---

## Bottom line

Phase 4 is a **wiring and production-payment gap**, not a greenfield commerce gap. Nest already owns orders, capture, entitlements, refunds, and confirmation email. The sprint should prioritize **contract + sync + QR + Quaser UX**, then order/refund surfaces. Apple/Google Wallet is the only true Large greenfield item.

**No implementation was performed as part of this analysis.**
