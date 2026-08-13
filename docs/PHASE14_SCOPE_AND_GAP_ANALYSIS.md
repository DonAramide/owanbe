# PHASE 14 — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-07-31  
**Method:** Architecture-derived (Phases 11–13 + live code paths) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no non-report code changes  
**Prerequisite:** Phase 13 Live QA / Certification still pending per `PHASE13_TICKETING_COMMERCE_COMPLETION_REPORT.md`

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Organizers can create events (12) and correctly configure / gate ticket tiers (13). Buy path exists (Phase 5 rail). |
| **Critical-path hole** | After **publish**, visibility gating is soft; after **purchase**, organizers cannot see **orders / buyers** (aggregates only). |
| **Natural Phase 14** | Close the **public ticketed loop**: trustworthy Discover → buy → organizer sales visibility |
| **Not Phase 14** | Vendors CRM, org Finance hub, Marketing, Live Ops rebuild, Attendee CRM productization, promo/tax UI |
| **Overall** | **✅ Phase 14 Scope Defined** |

---

## 2. Phase 14 name & mission

### Name

**Publish-to-Purchase & Sales Visibility**

### One-line mission

Make a published public-ticketed event **reliably discoverable and purchasable under the correct visibility rules**, and give organizers **order- and buyer-level visibility** for what already sold — without building Marketing, Finance OS, or Vendor CRM.

### Why this phase (not Attendees / Finance / Vendors)

| Candidate “sound next” | Why deferred |
|------------------------|--------------|
| Vendor CRM | Parallel marketplace track; Phase 11–13 explicitly deferred; does not unblock sold tickets |
| Org-wide Finance | Ledger/refund admin already exist; not the post-13 operating gap; deferred as later finance phase |
| Marketing | Explicitly out of 11–13; no campaign substrate required to sell |
| Attendee CRM / guests productization | Private invite is a **parallel** access mode; public ticketed loop is the Phase 12–13 pressure path |
| Live Ops / check-in rebuild | Downstream of entitlements already issued; not the immediate post-publish gap |

**Architecture sequence already documented:**

| Phase | Closes |
|-------|--------|
| 11 | Organizer sees portfolio / enters workspace |
| 12 | Organizer creates draft → readiness → **ready to publish** |
| 13 | Tiers managed, gated, inventoried through purchase rules |
| **14** | **Publish actually reaches the right public + organizer sees who bought** |
| 15+ | Private invite closure, check-in depth, finance/marketing/vendors as separate phases |

Phase 12 readiness (`event_publish_readiness.dart`) next-best-action after tickets is **publish** — not Discover QA, not orders UI. Product pressure after 13 is therefore: **publish works for the right audience**, then **operate sales**.

---

## 3. Intended user journey (product decision)

```
Create (12) → Configure tickets (13) → Publish
    → Public Discover / event page (correct visibility)
    → Select tickets → Checkout → Payment / free fulfill
    → Buyer entitlements (My Tickets / pass)
    → Organizer: sales by tier (13) + orders & buyers (14)
```

| Priority | When | Next best action after Phase 14 |
|----------|------|----------------------------------|
| 1 | Public ticketed, published, wrong/hidden visibility | Fix listing visibility / republish gates |
| 2 | Sales occurring | Open **Orders / buyers** on Tickets or Attendees surface |
| 3 | Private invitation mode | Phase 15 candidate (RSVP deep-link + invite entitlement) — **not** Phase 14 P0 |

---

## 4. Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | End-to-end usable on live path |
| **Implemented but Hidden** | Built; not on primary route |
| **Implemented but Not Wired** | UI or API exists; not connected |
| **Backend Complete / Frontend Missing** | API/DB ready; insufficient UX |
| **Frontend Complete / Backend Missing** | UI present; API stubbed/absent/unenforced |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 14 completeness |
| **Not Implemented** | No meaningful product implementation |

---

## 5. Architecture map (reuse — do not rebuild)

### Already strong (reuse)

| Asset | Path | Role |
|-------|------|------|
| Publish | `events.service.ts` `publish()` | `status=published`; public ticketed `TICKETS_REQUIRED` |
| Discover FE | `discover_screen.dart` → `publicEventsProvider` | Lists `GET /events` |
| Ticket select / checkout | `/events/:id/tickets`, `/checkout`, `ticket_commerce_api.dart` | Purchase happy path |
| Tier storefront filters | `ticket-tier-rules.ts`, public `GET …/tiers` | Phase 13 saleability |
| Entitlements / passes | `ticket-entitlements.service.ts`, `/attendee/passes` | Buyer wallet after pay |
| Sales aggregates | `GET …/tiers/sales`, dashboard KPIs | Phase 13 reporting |
| Per-event finance | `organizer-finance.service.ts` | Ledger summary (not order CRM) |
| Attendees shells | EOS Attendees + CC Attendees tab | UI exists; data empty |
| Tickets manage UI | `TicketsTabV3`, `TicketManagementScreen` | Natural home for order list |

### Critical gaps (Phase 14 target)

| Gap | Evidence |
|-----|----------|
| `listPublic` ignores `listingVisibility` | `events.service.ts` filters only `status IN (published, live, completed)` — no `public` / `invite_only` / `hidden` filter |
| Soft invite purchase gate | `ticket-orders.service.ts` blocks only `listingVisibility === 'hidden'`; Phase 13 deferred strict invite gate |
| No organizer order list API | `ticket-commerce.controller.ts`: create + `me/ticket-orders` only |
| Buyers always empty in organizer FE | `events_api.dart` / `organizer_event_store.dart`: `attendees: const []` |
| Free / complimentary fulfill incomplete | Comp tier + `freeOrder` still payment-shaped; Phase 13 deferred short-circuit |
| Private RSVP deep-link | Invite URL `/events/:id/rsvp?token=` — **no Flutter `rsvp` route** (parallel track; not P0) |

---

## 6. Module audit (Phase 14 lens)

### 6.1 Public go-live / storefront

| Capability | Classification | Notes |
|------------|----------------|-------|
| Publish event | **Implemented and Working** | Server gates for public ticketed tiers |
| Discover listing | **Partially Implemented** | Lists all published; **does not honor listingVisibility** |
| Public event detail | **Partially Implemented** | Multiple routes (`/events/:id`, attendee mirrors); primary Discover→buy path needs certification |
| Tier storefront rules | **Implemented and Working** | Phase 13 hidden / window / pause / archive |
| Event-level purchase gate | **Partially Implemented** | `hidden` blocks; `invite_only` still buyable if tiers exist |
| Event website builder | **Partially Implemented** | Exists; not primary Discover commerce surface |
| Free / zero-price fulfill | **Partially Implemented** | Needs auto-fulfill / short-circuit for comp & free |

### 6.2 Purchase → entitlement

| Capability | Classification | Notes |
|------------|----------------|-------|
| Create order + pay | **Implemented and Working** | Phase 5 + Phase 13 smoke |
| Issue entitlements on capture | **Implemented and Working** | `ticket-capture.service.ts` |
| My Tickets / digital pass | **Implemented and Working** | Attendee passes + QR |
| Buyer refund request | **Implemented and Working** | Buyer API |
| Organizer / admin refund action | **Backend Complete / Frontend Missing** (admin) | Admin finance queue only — **out of Phase 14 P0** (document; optional P2 link) |

### 6.3 Organizer sales visibility

| Capability | Classification | Notes |
|------------|----------------|-------|
| Sales by tier | **Implemented and Working** | Phase 13 |
| Dashboard sold / revenue | **Implemented and Working** | Aggregates |
| Event order list | **Not Implemented** | No organizer endpoint |
| Buyer / attendee list from purchases | **Frontend Complete / Backend Missing** (data) | Shells exist; API hardcodes `[]` |
| Comp issue outside checkout | **Not Implemented** | Comp = zero-price tier via buy path only |
| Search / filter buyers | **Not Implemented** | Depends on order/buyer feed |

### 6.4 Private invitation (explicitly scoped)

| Capability | Classification | Phase 14 treatment |
|------------|----------------|--------------------|
| Guests CRUD / send invites | **Implemented and Working** | Reuse; do not expand |
| Token validate + RSVP API | **Implemented and Working** | Backend present |
| Guest RSVP deep-link UI | **Not Implemented** | **Out of P0** — Phase 15 candidate |
| Invite → ticket entitlement | **Not Implemented** | **Out of Phase 14** |

### 6.5 Explicitly out of Phase 14

| Module | Reason |
|--------|--------|
| Marketing / campaigns | Deferred since Phase 11 |
| Org-wide Finance hub / payouts UX | Later finance phase |
| Promo / tax / fee config UI | Phase 13 deferred |
| Vendor CRM productization | Parallel track |
| Live Ops / check-in rebuild | Downstream; entitlements already exist |
| Advanced analytics time-series | Still synthesized; deferred |
| Scheduled publish | Phase 12 deferred |

---

## 7. Objectives (what “done” means)

1. **Visibility honesty:** Discover / public list only shows events intended for open discovery; `invite_only` and `hidden` cannot appear as open marketplace listings; purchase eligibility matches listing mode.
2. **Purchase certification:** Documented E2E path Discover → detail → select → checkout → entitlement (paid + free/comp short-circuit where price+fee = 0).
3. **Sales visibility:** Organizer can list **orders** for an event and see **buyers** derived from `ticket_orders` / `ticket_entitlements` (replace empty `attendees`).
4. **No domain creep:** No Marketing, Vendor CRM, org Finance nav, or full private invite entitlement model in this sprint.
5. **Reuse:** Extend existing Tickets / Attendees surfaces and commerce APIs — do not invent a parallel “Sales OS”.

---

## 8. In-scope modules

| Module | In scope | Primary surfaces |
|--------|----------|------------------|
| A. Listing & purchase gates | Yes | `listPublic`, order create eligibility, access/listing metadata |
| B. Storefront E2E certification | Yes | Discover, event detail, ticket select, checkout, free fulfill |
| C. Organizer orders API | Yes | New organizer-scoped list (by event); wire Flutter |
| D. Buyers from entitlements | Yes | Feed Attendees / Tickets UIs from real purchase data |
| E. Minimal sales ops UX | Yes | Order list + buyer search on TicketsTab and/or Attendees tab |
| F. Private RSVP deep-link | Optional P1 only | Route + validate token UI — **no** entitlement model |
| G. Organizer refund approve | Optional P2 | Thin link to existing admin cases — not full finance |

---

## 9. Effort & reuse estimates

| Workstream | Reuse | Effort | Notes |
|------------|-------|--------|-------|
| A. Visibility / purchase gates | High (~70%) | **S–M** | Filter + harden rules already partially in orders service |
| B. Free/comp fulfill + E2E QA | Medium (~50%) | **M** | Capture path exists; short-circuit + scripts |
| C. Organizer order list API + FE | Low–Medium (~30%) | **M** | New query; reuse order row shapes |
| D. Buyers wiring | Medium (~40%) | **M** | Shells exist; replace `attendees: []` |
| E. Polish / empty / error | High | **S** | Follow Phase 11–13 patterns |
| **Sprint total** | — | **M** (~1 week focused) | Split P0/P1 if timeboxed |

**S** = days · **M** ≈ 1 week · **L** = multi-week

---

## 10. Completion sprint plan

### Single sprint goal

**Published public events are discoverable and buyable under correct visibility, and organizers can see orders and buyers for what sold.**

### P0 (must ship)

1. Filter `listPublic` (and equivalent Discover feeds) by `listingVisibility` — only open/public listings in marketplace Discover.  
2. Align purchase eligibility with listing / access mode (strict enough that `invite_only` cannot be openly purchased via Discover; keep `hidden` blocked).  
3. Organizer **event order list** API (`GET` scoped to event + organizer access) + Flutter client.  
4. Wire **buyers / attendees** from `ticket_entitlements` (or order lines) — remove hardcoded empty attendees on live organizer event load.  
5. Surface orders + buyers on existing Tickets and/or Attendees Command Center surfaces (search by name/email if available).  
6. Regression: publish → Discover visibility matrix; paid happy path → entitlement; sold-out / hidden tier still enforced (Phase 13).

### P1 (should ship)

7. Free / complimentary order **auto-fulfill** (skip payment when amount due = 0).  
8. Discover → detail → checkout E2E script / Live QA checklist for Phase 14.  
9. Empty / loading / error states on new order & buyer lists.  
10. Optional: RSVP deep-link route only (token validate + RSVP) — **no** pass issuance.

### P2 (defer if timeboxed)

11. Organizer-facing refund case list (read) linking to admin finance — not full approve UX.  
12. Complimentary **issue** outside checkout (organizer grants entitlement).  
13. Event website as alternate storefront polish.

### Explicitly out of sprint

- Marketing, org Finance hub, Vendor CRM, Live Ops rebuild, promo/tax UI, invite→entitlement model, analytics rebuild.

---

## 11. Roadmap hint — Phases 15–20 (non-binding)

Derived from deferred items across 11–13 and remaining critical-path forks. **Numbers are planning hints only** — each phase still needs its own scope doc before build.

| Phase | Candidate theme | Depends on |
|-------|-----------------|------------|
| **14** | Publish-to-Purchase & Sales Visibility | Phase 13 cert |
| **15** | Private invitation closure (RSVP UI + invite access model) | Guests/invites APIs |
| **16** | Door / Live Ops (check-in against entitlements) | Issued passes + sales visibility |
| **17** | Organizer finance & refunds productization | Refund cases + ledger |
| **18** | Vendor marketplace CRM (inbox → booking ops) | Vendor identity foundations |
| **19** | Marketing / communications campaigns | Comms engine foundations |
| **20** | Analytics & reporting depth (real time-series) | Sales + ops data |

Promo / tax / fee config can attach to 14 P2, 17, or a commerce-hardening slice — not a reason to redefine 14.

---

## 12. Architectural decision (resolved for scope)

| Question | Decision |
|----------|----------|
| Public ticketed loop vs private invite in same sprint? | **Public loop is Phase 14 P0.** Private RSVP deep-link is optional P1 or Phase 15. |
| New “Sales” product surface? | **No** — extend Tickets + Attendees + commerce APIs. |
| Is organizer refund approval in scope? | **No** for P0 (admin queue remains). Optional P2 read-link only. |

No further architectural decisions block naming or scoping Phase 14.

---

## 13. Dependencies & stop conditions

| Gate | Status |
|------|--------|
| Phase 13 implementation | Complete (completion report) |
| Phase 13 Live QA / Certification | **Pending** — do not start Phase 14 build until certified (or explicitly waived) |
| Phase 14 scope doc | **This document** |
| Phase 14 implementation | **Not started** — requires explicit authorization after this scope |

**STOP:** Do not begin Phase 14 coding, Phase 15, or Marketing/Finance/Vendor delivery from this doc alone.

---

## 14. Suggested Live QA themes (post-implementation)

- Matrix: `listingVisibility` = public / invite_only / hidden × Discover visibility × purchase allowed/denied  
- Paid purchase → entitlement appears in My Tickets; organizer sees order + buyer  
- Free/comp path → entitlement without stuck `pending_payment`  
- Phase 13 regressions: sales window, hidden tier, pause, archive, abandoned release  
- Private invite: confirm **not** broken by visibility filters (send/hub still works)

---

## 15. Final classification

### ✅ Phase 14 Scope Defined

**Phase 14 = Publish-to-Purchase & Sales Visibility**

Natural successor to Event Creation (12) + Ticketing & Commerce (13). Closes the public ticketed operating loop with high reuse of Discover, checkout, entitlements, and organizer shells — without inventing Attendee CRM, Finance OS, or Vendor productization as Phase 14.
