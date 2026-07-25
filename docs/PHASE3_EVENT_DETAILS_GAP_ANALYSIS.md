# PHASE 3 — EVENT DETAILS GAP ANALYSIS

**Date:** 2026-07-24  
**Scope:** Attendee Event Details live QA vs codebase  
**Primary surface:** `mobile/lib/portals/attendee/screens/attendee_event_detail_screen.dart`  
**Method:** Evidence-only audit — **no code was written or modified**

---

## Executive verdict

Phase 3 Event Details is a **strong information + ticket summary page** with a wired Buy path (detail → ticket select → checkout → Nest commerce). Most QA failures are **not blocked by checkout** — they are **missing from the detail UI**, **stripped in the public Flutter model**, or **not implemented as product features**.

| Area | Summary |
|------|---------|
| 3.1 Event Information | Largely present; banner is gradient (not photo); venue-type field exists but is **not shown on detail hero** |
| 3.2 Ticket Information | Types/price/remaining/qty work; **sales window exists on API but not on public `TicketTier`**; **perks not implemented** |
| 3.3 Event Actions | Buy UI wired; checkout depends on payment config; **Save/Share/Calendar/Contact/Report not implemented** on detail |
| 3.4 Event Content | Gallery is **non-interactive label cards**; **Agenda API exists, FE missing**; Speakers/Sponsors/FAQs **not implemented** |
| 3.5 Location | Text venue works; **coords on model unused**; no map/directions |
| 3.6 Related Events | Similar/Recommended engines exist on **Discover only** — **not wired to detail** |
| 3.7 Technical Quality | Basic loading/error; no offline; minimal empty/responsive polish |

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | Present and wired on attendee detail (or its commerce sub-flow) |
| **Implemented but Hidden** | Built but only under rare/conditional UI |
| **Implemented but Not Wired** | Exists elsewhere; not connected to Event Details |
| **Backend Complete / Frontend Missing** | API/DB ready; attendee UI does not consume |
| **Frontend Complete / Backend Missing** | UI pattern exists; backend/product support missing |
| **Partially Implemented** | Incomplete across layers or degraded |
| **Not Implemented** | No meaningful product implementation |

---

## Primary architecture (evidence)

```
AttendeeEventDetailScreen
  → attendeeEventCommerceProvider(eventId)
  → publicEventProvider → EventsApi.getPublicEvent → GET /v1/events/:eventId
  → (optional mock) OrganizerEventStore → galleryLabels, venueAddress
  → PublicEventHero + sections
  → CTA → AttendeeRoutes.eventTickets → cartProvider → AttendeeCheckoutScreen
  → TicketCommerceApi → POST events/:eventId/ticket-orders
                      → POST ticket-orders/:orderId/payments
```

| Layer | Path |
|-------|------|
| Detail UI | `mobile/lib/portals/attendee/screens/attendee_event_detail_screen.dart` |
| Commerce view | `mobile/lib/portals/attendee/providers/attendee_event_commerce_provider.dart` |
| Hero | `mobile/lib/features/public/widgets/public_event_hero.dart` |
| Ticket select | `mobile/lib/portals/attendee/screens/attendee_ticket_select_screen.dart` |
| Checkout | `mobile/lib/portals/attendee/screens/attendee_checkout_screen.dart` |
| Payment client | `mobile/lib/core/api/ticket_commerce_api.dart` |
| Public model | `mobile/lib/features/public/models/public_models.dart` |
| Mapper | `mobile/lib/core/api/events_api.dart` (`mapPublicEvent`) |
| Events API | `services/api/src/modules/events/events.controller.ts` / `events.service.ts` |
| Commerce API | `services/api/src/modules/commerce/ticket-commerce.controller.ts` |
| Orders / payments | `ticket-orders.service.ts` / `ticket-payments.service.ts` |
| Program (agenda) | `GET events/:eventId/program` → `program.service.ts` |

**Providers involved:** `attendeeEventCommerceProvider`, `publicEventProvider`, `attendeeHasTicketProvider`, `attendeeEventsProvider`, `cartProvider`, Discover recommendation providers (not consumed by detail).

---

## 3.1 Event Information (QA: PASS)

| Feature | Classification | Evidence | Effort if gap |
|---------|----------------|----------|---------------|
| Event Banner / Cover | **Partially Implemented** | `PublicEventHero` uses **gradient** (`coverGradientStart`/`End`), not a cover photo. `celebrantImageUrl` exists on organizer/API path but is **not** on `PublicEvent` / hero. | Medium (map image URL + hero media) |
| Event Title | **Implemented and Working** | `PublicEventHero` → `event.title` | — |
| Event Description | **Implemented and Working** | “About this event” section | — |
| Date & Time | **Implemented and Working** | Hero + `_InfoRow` / `_when()` | — |
| Venue / Location | **Implemented and Working** | Venue + city; optional `commerce.venueAddress` | — |
| Physical / Virtual Badge | **Partially Implemented** | `PublicEvent.venueType` mapped in `mapPublicEvent`; shown on Discover rails; **not rendered on detail hero** (only status + category chips). QA may have inferred type from elsewhere. | Small |
| Event Category | **Implemented and Working** | Hero `Chip` + details row | — |
| Organizer Information | **Partially Implemented** | Details row shows `commerce.organizerLabel` defaulting to **`'Verified Owambe Organizer'`** — not a resolved organizer display name from API. | Small–Medium (expose organizer name on public event) |
| Event Status | **Implemented and Working** | `EosEventStatusBadge` in hero | — |

**Why QA can still mark PASS:** Core copy and layout are present. Photo banner and true venue-type badge on this page remain incomplete.

---

## 3.2 Ticket Information

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| Ticket Types | **Implemented and Working** | `_TierSummaryRow` lists `event.ticketTiers`; select screen has quantity UI | — | — |
| Ticket Pricing | **Implemented and Working** | `ngnFromMinor(tier.priceMinor)` | — | — |
| Remaining Tickets | **Implemented and Working** | `tier.remaining` / sold-out copy | — | — |
| Quantity Selector | **Implemented and Working** | `AttendeeTicketSelectScreen` + `cartProvider` | — | — |
| **Sales Start Date** | **Backend Complete / Frontend Missing** | API `loadTiersForEvent` returns `salesStartAt` in tier metadata (`events.service.ts`). Organizer mapper reads it (`mapOrganizerTier`). Public `TicketTier` and `mapPublicEvent` **drop** the fields. Detail/select UI never show them. Orders service does not appear to gate on sales window. | Stripped at public Flutter mapping | **Small** |
| **Sales End Date** | **Backend Complete / Frontend Missing** | Same as start (`salesEndAt`) | Same | **Small** |
| **Ticket Benefits / Perks** | **Not Implemented** | No `benefits`/`perks` schema, API field, or UI. Closest is free-text `tier.description`. | Never built | **Medium** |

---

## 3.3 Event Actions

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| **Buy Ticket** | **Partially Implemented** | UI: Hero CTA + bottom “Select tickets” → ticket select → checkout. APIs: `POST events/:eventId/ticket-orders`, `POST ticket-orders/:orderId/payments`. **Not blocked by “missing Buy UI.”** Live payment success depends on Quaser/stub env (`TicketPaymentsService` failure modes such as `PAYMENTS_NOT_CONFIGURED`). | Integration/config depth, not missing screens | **Medium** (prod payments hardening) |
| **Save Event** | **Not Implemented** | No bookmark/save provider, endpoint, or detail action. Unrelated bookmark icons exist in other portals. | Not a product feature yet | **Medium** |
| **Share Event** | **Not Implemented** | No `share_plus` (or equivalent) in `pubspec.yaml`; no share handler on detail. | Not built | **Small** |
| **Add to Calendar** | **Not Implemented** | No ICS/export/`add_2_calendar` on attendee detail. Calendar UIs elsewhere are vendor/organizer scheduling. | Not built | **Small–Medium** |
| **Contact Organizer** | **Not Implemented** | No mailto/chat/route on detail. Checkout “contact” fields are **buyer** info, not organizer. | Not built | **Medium** |
| **Report Event** | **Not Implemented** | Incident/report APIs serve ops/vendor contexts, not attendee trust & safety on public detail. | Wrong domain / no public report UX | **Medium–Large** |

**Checkout vs actions:** Save/Share/Calendar/Contact/Report are **independent of purchase completion**. They fail QA because they are **absent from Event Details**, not because checkout is incomplete.

---

## 3.4 Event Content

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| **Gallery / media click** | **Partially Implemented** | Horizontal cards from `commerce.galleryLabels` (`mediaLabels` via mock/store enrichment). **No `onTap`**, no image URLs, no viewer. `MediaApi` is organizer upload/presign — not a public gallery viewer on detail. | Labels-only; disconnected from media objects | **Medium** |
| **Agenda** | **Backend Complete / Frontend Missing** | Public `GET /v1/events/:eventId/program` (`events.controller.ts` → `ProgramService.getProgram`). Customer portal uses **manage** program APIs. Attendee detail has **no program section / provider**. | FE never calls public program GET | **Medium** |
| **Speakers** | **Not Implemented** | No speaker entity/API for public event detail. Program items may have owner fields, not a speaker catalog. | No product model | **Large** |
| **Sponsors** | **Not Implemented** | No sponsor content model on public detail. | No product model | **Large** |
| **FAQs** | **Not Implemented** | No FAQ section key/schema on attendee detail. | No product model | **Medium–Large** |

---

## 3.5 Location Experience

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| Venue text | **Implemented and Working** | Venue / city / optional address rows | — | — |
| **Map Preview** | **Backend Complete / Frontend Missing** | `PublicEvent.venueLatitude` / `venueLongitude` mapped; unused on detail. No maps package in attendee detail stack. | Coords unused in UI | **Medium** |
| **Get Directions** | **Not Implemented** | Location `_InfoRow` is non-interactive. No directions CTA. | Not wired | **Small** (needs coords + launcher) |
| **External Maps** | **Not Implemented** | No Google/Apple Maps deep link from detail. `url_launcher` not listed in current `pubspec.yaml` dependencies for this app surface. | Not built | **Small** |
| Rich venue info | **Partially Implemented** | Address when enriched; `googlePlaceId` on organizer/API not shown on attendee detail. | Minimal FE | **Medium** |

---

## 3.6 Related Events

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| **Similar Events** | **Implemented but Not Wired** | `discoverSimilarEventsProvider` + `HeuristicDiscoverRecommendationEngine.similar` used on **`attendee_discover_tab.dart`**. Detail only calls `recordEventViewed` (feeds Discover heuristics). **No rail on detail.** | Providers exist; detail omits UI | **Small** |
| **More Events from Organizer** | **Partially Implemented** | `PublicEvent.organizerId` available; similar scoring prefers same organizer. **No dedicated provider/section** on detail. | Filterable from catalog; not productized | **Small** |
| **Recommended Events** | **Implemented but Not Wired** | `discoverPersonalizedEventsProvider` on Discover; Tickets tab has a separate heuristic. **Not on event detail.** | Same | **Small** |

---

## 3.7 Technical Quality

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Loading States | **Partially Implemented** | `CircularProgressIndicator` via `commerceAsync.when` — no skeleton | Small |
| Error States | **Partially Implemented** | Raw `Text('$e')` — no retry/banner | Small |
| Empty States | **Partially Implemented** | “Event not found”; weak empty handling for zero tiers/gallery | Small |
| Responsive Behaviour | **Partially Implemented** | Hero uses `EosResponsive`; body is single-column scroll; attendee checkout less responsive than public checkout | Small |
| Performance Optimizations | **Partially Implemented** | `autoDispose` family providers; no heavy image pipeline (gradients/labels) | Small |
| Offline Handling | **Not Implemented** | No connectivity/offline cache on detail; mock fallback only if allowed when API throws | Medium |

---

## Master matrix (Phase 3 gaps)

| Feature | Classification | Effort |
|---------|----------------|--------|
| Sales Start Date | Backend Complete / Frontend Missing | Small |
| Sales End Date | Backend Complete / Frontend Missing | Small |
| Ticket Benefits / Perks | Not Implemented | Medium |
| Buy / Checkout reliability | Partially Implemented | Medium |
| Save Event | Not Implemented | Medium |
| Share Event | Not Implemented | Small |
| Add to Calendar | Not Implemented | Small–Medium |
| Contact Organizer | Not Implemented | Medium |
| Report Event | Not Implemented | Medium–Large |
| Gallery click / viewer | Partially Implemented | Medium |
| Agenda | Backend Complete / Frontend Missing | Medium |
| Speakers | Not Implemented | Large |
| Sponsors | Not Implemented | Large |
| FAQs | Not Implemented | Medium–Large |
| Map Preview | Backend Complete / Frontend Missing | Medium |
| Get Directions | Not Implemented | Small |
| External Maps | Not Implemented | Small |
| Similar Events (on detail) | Implemented but Not Wired | Small |
| More from Organizer | Partially Implemented | Small |
| Recommended (on detail) | Implemented but Not Wired | Small |
| Offline | Not Implemented | Medium |
| Loading/Error/Empty polish | Partially Implemented | Small |

---

## Single-sprint implementation roadmap

Ordered for one Phase 3 completion sprint — reuse existing catalog/recommendation/commerce stacks; do not rebuild Discover or rewrite checkout screens.

### Wave A — Quick wins (Small)

1. **Sales start/end on public tiers** — extend `TicketTier` + `mapPublicEvent`; show on detail + ticket select; optionally enforce in `ticket-orders.service.ts`.  
2. **Venue-type badge on hero** — use existing `event.venueType`.  
3. **Related rails on detail** — reuse `DiscoverAsyncRail` + `discoverSimilarEventsProvider` / personalized / `organizerId` filter from `publicEventCatalogProvider`.  
4. **Share Event** — add share package + deep link to `AttendeeRoutes.eventDetail`.  
5. **Get Directions / External Maps** — `url_launcher` + lat/lng or address query.  
6. **Add to Calendar** — ICS / calendar intent from `startsAt`/`endsAt`/`venue`.  
7. **Technical polish** — retry on error, clearer empty tiers, light skeletons.

### Wave B — Medium (content & trust)

8. **Agenda section** — new read-only provider calling public `GET events/:eventId/program` (do not use `/manage`).  
9. **Gallery viewer** — public media URLs in event metadata or Media GET; tap → full-screen viewer.  
10. **Map preview** — static map or embed using existing coordinates.  
11. **Ticket perks** — metadata schema + organizer capture + public map + UI chips/list.  
12. **Save Event** — local first (SharedPreferences) + optional API later.  
13. **Contact Organizer** — expose contact on public event/organizer profile + action sheet.  
14. **Checkout hardening** — clearer payment errors; document Quaser/stub; surface `clientActionUrl` if present.

### Wave C — Large (defer if sprint capacity tight)

15. **Report Event** — attendee trust endpoint + moderation queue.  
16. **Speakers / Sponsors / FAQs** — new content models or event-website section keys + attendee renderers.  
17. **True cover image banner** — map `celebrantImageUrl`/cover into `PublicEvent` + hero.  
18. **Offline cached detail** — connectivity-aware provider.

### Explicit non-goals for the sprint

- Do not redesign Event Details layout.  
- Do not rewrite Search or Discover.  
- Do not duplicate recommendation engines — wire existing ones.  
- Do not start Phase 4.

---

## Recommended Phase 3 “PASS” bar for next live QA

Treat as **PASS** when:

- Sales window dates visible (when set) on tiers.  
- Share + Directions + Calendar actions work from detail.  
- Similar / More from organizer / Recommended rails visible on detail.  
- Agenda renders when program data exists.  
- Gallery items open a viewer when media URLs exist (or hide if labels-only).  
- Venue type badge visible on hero.  
- Buy path still reaches checkout; payment failures show actionable errors (not silent).

Treat Speakers/Sponsors/FAQs/Report as **PARTIAL PASS / deferred** only if product explicitly scopes them out of the sprint — otherwise they remain **FAIL** until Wave C.

---

## Bottom line

Event Details is **not empty** — core information and ticket commerce UI exist. Phase 3 is blocked by **unmapped API fields (sales window)**, **non-interactive gallery**, **unused location coordinates**, **Discover-only recommendations**, and **absent secondary actions/content models**. Most high-value gaps are **Small–Medium wirings** against existing Nest endpoints and Flutter providers; Speakers/Sponsors/FAQs/Report are the true **Large** greenfield items.

**No implementation was performed as part of this analysis.**
