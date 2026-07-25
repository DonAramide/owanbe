# PHASE 5 — ATTENDEE DASHBOARD & MY EVENTS GAP ANALYSIS

**Date:** 2026-07-24  
**Scope:** Attendee Dashboard, My Events, Digital Passes, Registration Management, Personal Activity  
**Surfaces:** Flutter `mobile/`, Nest `services/api/`, DB `infra/db/`  
**Method:** Evidence-only audit — **no code was written or modified**  
**Live QA input:** Dashboard overview sections verified PASS; My Events / digital pass / registration areas not obvious on home

---

## Executive verdict

Phase 5 live QA aligns with the codebase:

| Area | Maturity |
|------|----------|
| Attendee dashboard shell (Discover / Tickets / Schedule) | High — largely wired |
| Dashboard overview sections on Tickets tab | Medium–High — visible sections match QA; several are partial or empty by data gap |
| Dedicated “My Events” for attendees | **Missing** — Schedule + Tickets approximate it; organizer “My Events” is a different product |
| Digital passes | Medium — live via **My Tickets / QR**, not a dedicated dashboard “Passes” module |
| Registration management | Low — ticket purchase implies registration; RSVP/cancel/guest flows unwired or absent |
| Personal activity | Medium — fragments exist (Discover recently viewed, Orders, in-memory purchase alerts) without a unified activity hub |

**Phase 5 is not certification-ready.** The biggest product gap is the absence of an attendee **My Events** management surface. Closest approximations are **Tickets** (passes) and **Schedule** (timeline), neither labeled or structured as the expected Events area (upcoming / past / saved / ticketed / history).

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | Present and wired for the intended attendee path |
| **Implemented but Hidden** | Built but not surfaced on the primary attendee flow |
| **Implemented but Not Wired** | Exists in codebase; wrong provider/route/data contract |
| **Backend Complete / Frontend Missing** | API/DB ready; attendee UI/client missing |
| **Frontend Complete / Backend Missing** | UI or local store exists; no durable backend |
| **Partially Implemented** | Incomplete across layers |
| **Not Implemented** | No meaningful product implementation |

---

## Attendee navigation (current)

| Item | Evidence |
|------|----------|
| Host screen | `mobile/lib/features/public/screens/attendee_dashboard_screen.dart` |
| Route | `/attendee` (`app_router.dart`) |
| Default tab | Tickets (`_tab = 1`) |
| Bottom nav | `EosRoleDestinations.attendee` — Discover · Tickets · Schedule |

**Commerce / secondary routes** (`attendee_routes.dart`, `attendee_commerce_routes.dart`):

| Path | Purpose |
|------|---------|
| `/attendee/find-ticket` | Find ticket |
| `/attendee/profile` | Profile edit |
| `/attendee/events/:eventId` | Event detail |
| `/attendee/events/:eventId/tickets` | Ticket select |
| `/attendee/checkout`, `payment-*` | Purchase |
| `/attendee/orders`, `/attendee/orders/:orderId` | Purchase history |
| `/attendee/onboarding` | Onboarding |

**Important persona distinction:** Customer/Organizer shell tab **“My Events”** at `/events/mine` (`CustomerMyEventsScreen`) lists **owned organizer events** — not attendee registrations. Do not treat it as Phase 5 My Events.

---

## 5.1 Dashboard Overview

**Live QA status:** PASS for welcome, loading, RSVP section presence, check-in section, recommended, recent activity.

### Rendered on Tickets tab (`attendee_tickets_tab.dart`)

| Feature | Classification | Evidence | Why incomplete |
|---------|----------------|----------|----------------|
| Welcome header | **Implemented and Working** | `HomeWelcomeHero` + identity/avatar | — |
| Dashboard loading | **Implemented and Working** | `attendeeEventsProvider` → `AsyncValue.when` spinner | — |
| KPI row (tickets / upcoming / checked-in) | **Partially Implemented** | `_KpiRow` + `attendeeDashboardStatsProvider` | Checked-in KPI stays 0 — entitlement `status` not mapped to `AttendeeTicket.checkedIn` |
| Next-up banner | **Implemented and Working** | Conditional on `stats.nextEvent` | — |
| Purchase alerts | **Implemented and Working** | `purchaseNotificationsProvider` (session memory) | Lost on restart |
| My tickets + QR CTA | **Implemented and Working** | `AttendeeEventCard` → `showAttendeeQrSheet` | — |
| Pending invitations | **Partially Implemented** | UI filters `CustomerInvitationKind.ticket` | Provider builds invitations **only from entitlements** → duplicates “My tickets”, not true pending invites |
| RSVP requests section | **Implemented but Not Wired** | UI filters `CustomerInvitationKind.rsvp` | `customerTicketInvitationsProvider` **never emits `rsvp`** → always empty (matches “section exists but empty”) |
| Check-in status section | **Partially Implemented** | Chip row from `event.checkedIn` | Sync path omits `checkedIn` mapping (`attendee_events_provider.dart`) |
| Recommended for you | **Partially Implemented** | `publicEventsProvider` featured/upcoming take(4) | Not the Discover personalization engine |
| Recent activity | **Partially Implemented** | Synthetic from ticket list | Not a durable activity/audit feed |
| Quick actions | **Implemented and Working** | Discover, Find ticket, Purchase history, Schedule, Profile | Orders entry exists but easy to miss vs expected “My Events” |

### Hidden / unused dashboard widgets

| Widget | Classification | Evidence |
|--------|----------------|----------|
| `AttendeeHomeHubContent` | **Implemented but Not Wired** | `attendee_home_hub_content.dart` — comment: legacy; **zero call sites**; smaller hub (welcome + invitations only) |
| `seedDemoAttendeeTicketsIfEmpty` | **Not Implemented** | Deprecated empty stub in `attendee_events_provider.dart` |

### Providers

| Provider | File |
|----------|------|
| `attendeeTicketsSyncProvider` | `features/public/providers/attendee_events_provider.dart` → `GET me/ticket-entitlements` |
| `attendeeEventsProvider` | same (N× `publicEventProvider`) |
| `attendeeDashboardStatsProvider` | same |
| `attendeeHomeSnapshotProvider` | `portals/customer/providers/customer_home_providers.dart` |
| `customerTicketInvitationsProvider` | same (entitlement → ticket-kind only) |
| `publicEventsProvider` | `public_providers.dart` |
| `purchaseNotificationsProvider` | `portals/attendee/commerce/purchase_notifications_provider.dart` |

### Check-in mapping gap (drives KPI / chips / activity)

| Layer | Status |
|-------|--------|
| Backend | **Complete** — `TicketEntitlementsService.listForUser` returns `status` (`issued` / `checked_in` / …); table `ticket_entitlements` (`016_phase5_ticket_commerce_foundation.sql`) |
| Frontend | **Missing mapping** — `AttendeeTicket` supports `checkedIn` but sync `map` never sets it from `e.status` |

---

## 5.2 My Events

**Live QA observation:** No obvious “My Events” / “Events” entry on attendee home; only “Recommended for you” as a prominent event rail. Discover opens marketplace rails (upcoming / recommended / trending / etc.).

| Expected capability | Classification | Evidence | Why incomplete |
|---------------------|----------------|----------|----------------|
| Dedicated “My Events” / “Events” entry | **Not Implemented** | Attendee nav labels: Discover · Tickets · Schedule only | No attendee route or tab named My Events / Events |
| Attendee event management screen | **Not Implemented** | No screen composing upcoming / past / saved / ticketed / history | Product gap |
| Upcoming registered | **Partially Implemented** | Schedule “Upcoming”; Tickets list; KPIs | Ticket-entitlement based only; no RSVP-only registrations |
| Past attended | **Partially Implemented** | Schedule “Past” via `!isUpcoming` (time heuristic) | Not attendance/check-in based |
| Saved events | **Frontend Complete / Backend Missing** | Save toggle on detail (`saved_events_store.dart`, SharedPreferences) | **No saved-events list screen**; no Nest persistence |
| Ticketed events | **Implemented and Working** | Entitlements → Tickets / Find ticket / Schedule | Surfaced as “My tickets”, not “My Events” |
| Event / purchase history | **Implemented and Working** | `/attendee/orders` (Phase 4) | Reachable via Quick actions, not Events hub |
| Organizer “My Events” `/events/mine` | **Implemented and Working** (wrong persona) | `CustomerMyEventsScreen`, `customerOwnedEventsProvider` | Must not be reused as attendee My Events without redesign |

**Verdict for QA:** My Events is **not implemented** for attendees. Schedule is a **partial timeline substitute**; Discover is **marketplace**, not management.

---

## 5.3 Digital Event Passes

**Live QA observation:** No dedicated digital pass section on dashboard.

| Capability | Classification | Evidence | Why incomplete |
|------------|----------------|----------|----------------|
| Digital pass via Tickets | **Implemented and Working** | Tickets tab “My tickets” + QR sheet (`attendee_event_card.dart`, `qr_flutter`) | Exists under Tickets, not a Passes section |
| QR validation payload | **Implemented and Working** | Server `OWANBE:{eventId}:{tierId}:{ticketCode}` on capture; sheet renders payload | Phase 4 |
| Dashboard integration of QR | **Implemented and Working** | Primary CTA on ticket cards; also event detail | Not a separate “Digital Passes” module |
| Ticket wallet / pass screen | **Not Implemented** | No attendee wallet route | Apple/Google Wallet deferred (Phase 4) |
| Resend ticket | **Implemented and Working** | QR sheet → `POST ticket-entitlements/:id/resend` | — |
| Re-download tickets | **Implemented and Working** | Order detail refreshes entitlements | Entitlement refresh, not PDF/file |
| Share **event** | **Implemented and Working** | Event detail `EventDetailActions.shareEvent` | Shares event link, not pass |
| Share / download ticket image or PDF | **Not Implemented** | QR sheet has no share/download of QR asset | — |
| Apple / Google Wallet | **Not Implemented** | Intentionally deferred | Keep architecture compatible |

**API / DB:** `GET me/ticket-entitlements`, `POST ticket-entitlements/:id/resend`, `ticket_entitlements` table; Flutter `TicketCommerceApi`.

**Verdict:** Passes **exist through Tickets**, not as a first-class dashboard section. Gap is **discovery/IA**, plus wallet/share-PDF.

---

## 5.4 Registration Management

**Live QA observation:** No visible registration management area.

| Capability | Classification | Evidence | Why incomplete |
|------------|----------------|----------|----------------|
| Registration via ticket purchase | **Implemented and Working** | Phase 4 commerce → entitlements | Implicit registration only |
| Registration status UI | **Partially Implemented** | Ticket presence / order status | No dedicated registration-status screen |
| RSVP requests on dashboard | **Implemented but Not Wired** | UI section always empty | No RSVP invitation feed |
| RSVP confirm/decline API | **Backend Complete / Frontend Missing** | `POST invitations/rsvp` → `EventInvitationsService.rsvpByToken` (`events.controller.ts`) | Token RSVP; no attendee Flutter client |
| Invitation lookup | **Backend Complete / Frontend Missing** (attendee) | `identity.controller` `lookupInvitations` | Not driving dashboard RSVP section |
| Update registration | **Not Implemented** | No attendee update-registration flow | — |
| Cancel registration | **Not Implemented** | Buyer refund on order ≠ cancel registration | — |
| Guest / plus-one management (attendee) | **Not Implemented** | `event_guests` APIs are organizer-scoped | — |
| Dietary / accessibility | **Implemented and Working** (profile-level) | `AttendeeProfileEditScreen` + `GET/PUT me/attendee-profile`; `attendee_profiles` (`050_attendee_workspace_profile.sql`) | Not per-event registration fields |
| Organizer guest RSVP tooling | **Implemented and Working** (organizer) | Guests hub / `event_guests` | Out of attendee Phase 5 |

**DB:** `038_event_guests_invitations.sql`, `event_guests.rsvp_status`, invitation tokens.

**Verdict:** Backend RSVP/invitation capability exists; **attendee registration management UI is missing**. Dietary/accessibility live on **profile**, not event registration.

---

## 5.5 Personal Activity

**Live QA observation:** Only limited activity visible (dashboard “Recent activity” synthetic list).

| Capability | Classification | Evidence | Why incomplete |
|------------|----------------|----------|----------------|
| Recently viewed events | **Implemented and Working** (Discover) | `recently_viewed_events_store.dart` + Discover rails; recorded on event detail | **Not on Tickets dashboard** |
| Saved events | **Partially Implemented** | Local toggle only | No list UI; no backend |
| Purchase history | **Implemented and Working** | `/attendee/orders`, `GET me/ticket-orders` | Not framed as “Activity” |
| Notifications feed (purchase) | **Partially Implemented** | In-memory `purchaseNotificationsProvider` on Tickets | Not durable; no full inbox |
| Messages | **Implemented but Hidden** (cross-workspace) | Living Home `home_messages_tab.dart` | Not under `/attendee` |
| Hub alerts / activity | **Implemented but Hidden** | `home_alerts_tab.dart`, `home_activity_tab.dart` | Hub, not attendee shell |
| Rewards / loyalty history | **Not Implemented** | No attendee rewards module found | — |
| Dashboard recent activity | **Partially Implemented** | Derived from tickets | Limited fidelity |

---

## Technical audit

| Concern | Classification | Evidence | Why incomplete |
|---------|----------------|----------|----------------|
| Loading states | **Implemented and Working** | Tickets / Schedule / Discover / Orders | — |
| Empty states | **Implemented and Working** | Empty cards + CTAs on tabs and orders | — |
| Error states | **Partially Implemented** | Tickets/Schedule raw `$e`; Orders banner+Retry; Discover often shrinks errors | Soft-fail entitlements → local cache without clear error |
| Offline behaviour | **Partially Implemented** | `attendeeOfflineProvider` on detail/checkout/pending | **Not** on Tickets / Discover / Schedule tabs |
| Responsive layout | **Implemented and Working** | KPI width clamp; top bar compact/wide | — |
| Performance | **Partially Implemented** | N+1 `publicEventProvider` per entitlement in `attendeeEventsProvider` | Known Phase 4 carry-over |
| Pull-to-refresh | **Implemented and Working** | Tickets / Discover / Schedule / Orders | — |

---

## Findings matrix (compact)

| ID | Finding | Classification |
|----|---------|----------------|
| F1 | Dashboard 3-tab shell | Implemented and Working |
| F2 | Welcome / loading / quick actions | Implemented and Working |
| F3 | KPI + check-in chips fidelity | Partially Implemented |
| F4 | RSVP requests UI | Implemented but Not Wired |
| F5 | Pending invitations = duplicate tickets | Partially Implemented |
| F6 | Recommended on Tickets (generic) | Partially Implemented |
| F7 | Recent activity (synthetic) | Partially Implemented |
| F8 | `AttendeeHomeHubContent` legacy | Implemented but Not Wired |
| F9 | Attendee My Events screen / nav entry | Not Implemented |
| F10 | Schedule upcoming/past timeline | Partially Implemented (My Events substitute) |
| F11 | Saved events list + sync | Frontend Complete / Backend Missing |
| F12 | Digital pass via Tickets/QR | Implemented and Working |
| F13 | Dedicated passes / wallet / ticket share-PDF | Not Implemented |
| F14 | RSVP token API | Backend Complete / Frontend Missing |
| F15 | Cancel registration / guest management | Not Implemented |
| F16 | Dietary/accessibility on profile | Implemented and Working |
| F17 | Purchase history | Implemented and Working |
| F18 | Durable notifications / rewards | Partially Implemented / Not Implemented |
| F19 | Offline on dashboard tabs | Partially Implemented |
| F20 | Entitlement→event N+1 | Partially Implemented |

---

## Key file index

**Flutter — dashboard**
- `mobile/lib/features/public/screens/attendee_dashboard_screen.dart`
- `mobile/lib/portals/attendee/widgets/attendee_tickets_tab.dart`
- `mobile/lib/portals/attendee/widgets/attendee_discover_tab.dart`
- `mobile/lib/portals/attendee/widgets/attendee_schedule_tab.dart`
- `mobile/lib/portals/attendee/screens/attendee_home_hub_content.dart` (unwired)
- `mobile/lib/features/public/providers/attendee_events_provider.dart`
- `mobile/lib/features/public/widgets/attendee_event_card.dart`
- `mobile/lib/eos/navigation/eos_role_destinations.dart`

**Flutter — My Events (organizer) / commerce / stores**
- `mobile/lib/portals/customer/screens/customer_my_events_screen.dart` (organizer-owned)
- `mobile/lib/portals/attendee/screens/attendee_orders_screen.dart`
- `mobile/lib/features/public/data/saved_events_store.dart`
- `mobile/lib/features/public/data/recently_viewed_events_store.dart`
- `mobile/lib/core/api/ticket_commerce_api.dart`

**Nest / DB**
- `services/api/src/modules/commerce/ticket-entitlements.service.ts`
- `services/api/src/modules/commerce/ticket-commerce.controller.ts`
- `services/api/src/modules/events/events.controller.ts` (`POST invitations/rsvp`)
- `services/api/src/modules/events/event-invitations.service.ts`
- `services/api/src/modules/identity/attendee-profile.service.ts`
- `infra/db/016_phase5_ticket_commerce_foundation.sql` (`ticket_entitlements`)
- `infra/db/038_event_guests_invitations.sql`
- `infra/db/050_attendee_workspace_profile.sql`

---

## Implementation sprint roadmap (single sprint)

Goal: make Phase 5 certify without redesigning Discover/commerce. Prefer wire + compose existing surfaces.

### Wave A — High priority (unblocks QA “My Events” + fidelity)

1. **Attendee My Events surface**
   - Add entry (nav item **or** dashboard section + route) labeled **My Events** / **Events**.
   - Compose existing data: ticketed (`attendeeEventsProvider`), Schedule upcoming/past, saved IDs, link to `/attendee/orders`.
   - Do **not** reuse organizer `/events/mine` without a separate attendee screen.

2. **Fix entitlement → UI mapping**
   - Map `status == checked_in` → `AttendeeTicket.checkedIn`.
   - Fixes KPI, check-in chips, Schedule icons, Recent activity.

3. **Wire RSVP / invitations correctly**
   - Stop treating entitlements as “pending invitations.”
   - Connect invitation lookup / RSVP token API to RSVP requests UI (or hide section until wired).

4. **Digital passes dashboard visibility**
   - Explicit “Digital passes” / primary QR entry on My Events or Tickets header (reuse QR sheet; no new payment path).

### Wave B — Registration management (reuse backend)

5. Attendee RSVP confirm/decline client for `POST invitations/rsvp`.
6. Registration status on event/ticket detail (issued / checked_in / refunded).
7. Cancel path policy: refund vs void entitlement — wire only what backend already allows.
8. Surface profile dietary/accessibility as read-only context on registration where relevant (no per-event schema unless already present).

### Wave C — Personal activity & saved events

9. Saved events list screen (local first); optional backend sync only if required for certification.
10. Surface recently viewed on Tickets/My Events (reuse Discover store).
11. Durable or clearer purchase notification retention (or persist last N in prefs).
12. Do not build rewards unless already present (currently Not Implemented — defer if out of sprint scope).

### Wave D — Technical quality

13. Offline banners on Tickets / Schedule / My Events tabs (`attendeeOfflineProvider`).
14. Stronger error + retry on tickets sync failures.
15. Reduce N+1 event enrichment for My Events / Schedule (batch or use entitlement fields first).

### Explicitly out of sprint (unless product expands scope)

- Apple Wallet / Google Wallet  
- Organizer guest management UI in attendee shell  
- Redesign of Discover marketplace  
- Parallel checkout / payment services  

---

## Sprint success criteria (for later certification)

| Criterion | Target |
|-----------|--------|
| My Events entry visible from attendee home | Required |
| Upcoming / past / ticketed / saved / history reachable from My Events | Required |
| Check-in status reflects backend entitlement status | Required |
| RSVP section either working or removed/hidden until wired | Required |
| Digital pass reachable without hunting (Tickets or My Events) | Required |
| Registration actions that claim support are wired to existing APIs | Required |
| Loading / empty / error / offline on new surfaces | Required |
| Wallet | Deferred OK |

---

## Phase 5 audit status

**COMPLETE — audit only.**  
No implementation performed. Ready for a single focused implementation sprint using the roadmap above.
