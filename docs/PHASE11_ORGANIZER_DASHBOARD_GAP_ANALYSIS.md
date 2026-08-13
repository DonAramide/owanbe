# PHASE 11 — ORGANIZER DASHBOARD & COMMAND CENTER GAP ANALYSIS

**Date:** 2026-07-27  
**Scope:** Organizer Workspace starting from Dashboard / Command Center  
**Method:** Read-only audit of Flutter (`mobile/`) and NestJS (`services/api/`) + DB (`infra/db/`)  
**Constraint:** Audit only — no code changes, no redesign, no fixes  

---

## Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Live organizer landing** | `OrganizerHomeHubScreen` at `/home` (customer shell) — welcome hero, active events, quick actions, portfolio teaser |
| **Full EOS Organizer shell** | `OrganizerHomeScreen` + 7-tab rail (Dashboard → Live Ops) — **built but not routed** (`/organizer` redirects to `/home`) |
| **Per-event Command Center** | Strong — V3 tabs + customer event workspace adapter |
| **Dashboard KPI API** | `GET /organizers/me/dashboard` — wired to `organizerDashboardStatsProvider` when EOS dashboard is shown |
| **Overall classification** | **Partially implemented** |

Organizer product is split across two UX generations: a **live hub** (customer portal) and a **hidden EOS command-center shell**. Completing Phase 11 is mostly about **surfacing and finishing** what exists, plus a short list of true gaps (import, marketing/reports IA, calendar, real trend APIs).

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | End-to-end usable for organizers on the live path |
| **Implemented but Hidden** | Built; not reachable via current primary routing |
| **Implemented but Not Wired** | UI or model exists; not connected |
| **Backend Complete / Frontend Missing** | API/DB ready; no (or insufficient) organizer UI on live path |
| **Frontend Complete / Backend Missing** | UI present; API synthetic/stubbed/absent |
| **Partially Implemented** | Meaningful pieces; gaps block MVP completeness |
| **Not Implemented** | No meaningful product implementation |

---

## Architecture map (reusable building blocks)

### Flutter

| Asset | Path | Role |
|-------|------|------|
| Live landing | `portals/organizer/screens/organizer_home_hub_screen.dart` | Current organizer home |
| EOS shell (hidden) | `features/organizer/screens/organizer_home_screen.dart` | 7-tab nav rail host |
| EOS dashboard | `features/organizer/screens/organizer_dashboard_screen.dart` | KPI + attention + recent events |
| Events list | `features/organizer/screens/event_management_screen.dart` | Create / publish / open workspace |
| Tickets / Vendors / Attendees / Analytics | `ticket_management_screen.dart`, `vendor_management_screen.dart`, `attendee_management_screen.dart`, `event_analytics_screen.dart` | EOS tabs |
| Live Ops | `features/operations/screens/operations_shell.dart` | Ops shell tab |
| Wizard V2 | `features/organizer/wizard_v2/event_create_wizard_v2_screen.dart` | Create / duplicate seed |
| Command Center V3 | `features/organizer/command_center_v3/tabs/*` | Per-event overview…settings |
| Event workspace | `features/organizer/screens/event_workspace_screen.dart` | Adapter into customer event portal |
| Portfolio | `portals/customer/screens/organizer_portfolio_workspace_screen.dart` | Portfolio intelligence |
| Providers | `features/organizer/providers/organizer_providers.dart` | Dashboard, events, analytics, attention |
| Destinations | `eos/navigation/eos_role_destinations.dart` | `EosRoleDestinations.organizer` (7 items) |
| Routing | `router/app_router.dart` | `/organizer` → redirect `/home` |

### Nest / DB

| Asset | Path | Role |
|-------|------|------|
| Portal KPIs | `organizer-portal.service.ts` | `GET organizers/me`, `/dashboard`, `/events` |
| Events CRUD | `events.service.ts` / `events.controller.ts` | Create, patch, publish, go-live, list |
| Finance | `organizer-finance.service.ts` | Per-event summary + transactions |
| Ops | `event-operations.service.ts` | Check-ins, incidents, feed |
| Templates config | `event-config.service.ts` | Categories, event/budget templates |
| Program | `program.service.ts` | Run-sheet + reminders table |
| Vendor CRM | `vendor-crm.service.ts` | Requests pipeline |
| Tables | `events`, `ticket_*`, `event_check_ins`, `vendor_event_*`, `tenant_event_templates`, `event_program_*`, ledger/payouts | Persistence |

---

## 11.1 Dashboard Home

| Feature | Classification | Evidence | Why available / not | Effort |
|---------|----------------|----------|---------------------|--------|
| Organizer landing page | **Implemented and Working** | `OrganizerHomeHubScreen`; `customer_shell_route.dart` home builder | Live path is hub, not EOS dashboard | Small (IA polish) |
| Welcome header | **Implemented and Working** | `HomeWelcomeHero` on hub | Uses session display name + nearest event | Small |
| Organization switcher | **Partially Implemented** | `WorkspaceSwitcher` on living home / experience shell | Workspace switch (attendee/organizer/vendor), not multi-org account picker | Medium |
| Workspace selector | **Implemented and Working** | `WorkspaceExperienceShell` + `WorkspaceSwitcher` | Experience workspace switching works | Small |
| Event summary cards | **Partially Implemented** | Hub: active event cards + upcoming banner; EOS: KPI “Active/Upcoming” on `OrganizerDashboardScreen` (**hidden**) | Live hub lacks full KPI strip; EOS has it but unreachable | Small |
| Revenue summary | **Partially Implemented** | API `GET organizers/me/dashboard` → `revenueMinor`; FE `organizerDashboardStatsProvider` + EOS dashboard KPI (**hidden**); portfolio teaser on hub | Live hub does not show revenue KPI prominently | Small |
| Ticket sales summary | **Partially Implemented** | Same dashboard API `ticketsSold` + EOS KPI (**hidden**) | Same routing gap | Small |
| Attendee summary | **Partially Implemented** | Dashboard API `attendeeCount` + EOS KPI (**hidden**) | Same | Small |
| Vendor summary | **Partially Implemented** | Dashboard API `vendorCount` + EOS KPI (**hidden**); hub vendor carousel | Count exists; spend summary not on home | Small |
| Recent activity | **Partially Implemented** | EOS Attention Center (`organizerAttentionProvider` — drafts/low sales); per-event feed `GET events/:id/feed` | No organizer-wide activity feed API or hub timeline | Medium |
| Quick actions | **Implemented and Working** | Hub `HomeQuickActionsRow`; EOS `OrganizerQuickActions` (**hidden**) | Create / navigate actions on live hub | Small |

**11.1 sub-verdict:** **Partially implemented** (live hub OK; full dashboard KPIs **Implemented but Hidden** behind `/organizer` → `/home`).

---

## 11.2 Event Overview

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Upcoming events | **Partially Implemented** | Hub upcoming banner + active list; dashboard KPI “Upcoming”; statuses on event cards | No dedicated filtered “Upcoming” list UX | Small |
| Live events | **Partially Implemented** | Status chip / go-live; Live Ops tab | No dedicated Live filter bucket on list | Small |
| Draft events | **Implemented and Working** | `EventManagementScreen` draft accent + Publish; attention unpublished draft | Visible when EOS Events tab shown; also in API list all statuses | Small |
| Completed events | **Partially Implemented** | API returns `completed` status events in `listForOrganizer`; closing/reports widgets exist | No dedicated Completed filter on organizer list UI | Small |
| Event cards | **Implemented and Working** | `_EventManageCard`; hub `HomeActiveEventCard` | Open workspace / publish / go-live | Small |
| Search | **Implemented but Not Wired** (EOS) / **Not Implemented** (hub list) | `EosSearchField` in `_OrganizerTopBar` without filter callback; `listForOrganizer` has no `?q=` | Search UI decorative on hidden shell | Small |
| Filters | **Not Implemented** | No status/date chips on `EventManagementScreen`; API no `?status=` | Client could filter locally as interim | Small–Medium |
| Sorting | **Not Implemented** | Fixed `ORDER BY created_at DESC` in `listForOrganizer` | No sort UI or API params | Small |

**Backend list:** `GET organizers/me/events` / `EventsService.listForOrganizer` — all events, no query params → **Partially Implemented**.

**11.2 sub-verdict:** **Partially implemented**.

---

## 11.3 Command Center (create / templates / drafts)

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Create Event | **Implemented and Working** | `/organizer/events/new`, `/events/create` → `EventCreateWizardV2Screen`; `POST /events` | Live | Small |
| Duplicate Event | **Frontend Complete / Backend Missing** (client seed) | `eventDuplicateSeedProvider` + wizard `_applyDuplicateSeed`; closing actions set seed | No `POST /events/:id/duplicate`; client-side draft only | Small |
| Import Event | **Not Implemented** | No import UI/API/CSV | — | Large |
| Templates | **Partially Implemented** | `GET event-config/templates`; `event_template_catalog.dart`; portfolio template quick-start; program `apply-template` | Catalog/API exist; no first-class template picker on create entry; create stores slug but does not auto-seed checklist | Medium |
| Event Wizard | **Implemented and Working** | Wizard V2 5-step; legacy wizard superseded | Primary create path | Small |
| Draft management | **Implemented and Working** | Draft status, publish, attention; wizard saves draft | Resume via events list / workspace | Small |

**Per-event Command Center V3** (Overview, Tickets, Attendees, Vendors, Marketplace, Finance, Operations, Analytics, Settings): **Implemented and Working** under event workspace (`command_center_v3/tabs/*`), surfaced via `EventWorkspaceScreen` adapter.

**11.3 sub-verdict:** **Partially implemented** (create/wizard/drafts strong; import missing; duplicate client-only; templates incomplete).

---

## 11.4 Organizer Insights

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Revenue charts | **Partially Implemented** | Per-event finance charts (`cc_v3_finance_charts.dart`); `GET events/:id/finance/summary` | Org-wide revenue chart not on live home; EOS Analytics tab **hidden** | Medium |
| Ticket charts | **Frontend Complete / Backend Missing** | `EventAnalyticsScreen` sparklines / tier table; `organizerAnalyticsProvider` synthesizes trends from sold counts / mock store | No time-series ticket sales API | Medium |
| Registration trends | **Frontend Complete / Backend Missing** | Synthetic `dailySales` / `salesTrend` in provider | Not ledger/time-bucketed | Medium |
| Attendance trends | **Partially Implemented** | Check-in rate from attendees; `GET events/:id/check-ins` | Point-in-time, not trend series | Medium |
| Vendor metrics | **Partially Implemented** | Dashboard vendor count; CRM pipeline APIs; finance vendor spend charts per-event | No org-level vendor KPI home; no spend summary endpoint | Small–Medium |
| Check-in metrics | **Partially Implemented** | Ops check-ins API + analytics checkIns/noShows | Strong per-event; weak org dashboard surfacing | Small |
| Notifications | **Partially Implemented** | In-app attention banners; email for tickets/invites; push log-only | No organizer sale/RSVP push feed or prefs API | Medium–Large |

**Hardcoded trend example:** `EosTrendBadge(deltaPercent: 12.4)` on analytics page views — not API-backed.

**11.4 sub-verdict:** **Partially implemented** (per-event depth; org insights / real trends weak).

---

## 11.5 Productivity

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Recent drafts | **Implemented and Working** | Drafts in event list + attention unpublished | — | Small |
| Tasks | **Partially Implemented** | Planning checklist / ops `CheckboxListTile` (`onChanged: null` in places); template checklist JSONB | Not a real assignable task system with due dates | Large |
| Calendar widget | **Not Implemented** | Vendor calendar exists; no organizer multi-event calendar | — | Large |
| Upcoming deadlines | **Partially Implemented** | Reminders panel (`CcV3RemindersPanel`); program items | Per-event only; no org deadline rollup | Medium |
| Event reminders | **Partially Implemented** | `event_program_reminders` table + UI panel | No delivery worker; push not real | Medium |

**11.5 sub-verdict:** **Partially implemented**.

---

## 11.6 Organizer Navigation

| Destination | Classification | Evidence | Why | Effort |
|-------------|----------------|----------|-----|--------|
| Dashboard | **Partially Implemented** | Live = hub; EOS Dashboard **hidden** | Redirect `/organizer` → `/home` | Small |
| Events | **Partially Implemented** | Hub “See all” → `/events/mine`; EOS Events tab **hidden** | Dual paths | Small |
| Attendees | **Implemented but Hidden** (global) / **Implemented and Working** (per-event) | EOS `AttendeeManagementScreen`; CC Attendees tab | Global tab only on hidden shell | Small |
| Tickets | **Implemented but Hidden** (global) / **Working** (per-event) | EOS `TicketManagementScreen`; CC Tickets | Same | Small |
| Vendors | **Partially Implemented** | Hub carousel + marketplace; EOS Vendors **hidden**; CC Vendors + CRM APIs | Fragmented | Small–Medium |
| Finance | **Implemented and Working** (per-event) / **Not Implemented** (top-level nav) | `FinanceTabV3` + finance APIs; not in `EosRoleDestinations.organizer` | No org-wide Finance destination | Medium |
| Marketing | **Not Implemented** | No nav item, screen, or marketing module | — | Large |
| Operations | **Partially Implemented** | Live Ops tab + CC Operations + ops APIs | Live-event oriented, not general ops IA | Medium |
| Reports | **Partially Implemented** | Closing `EventCompletedReports` / export panels per-event | No top-level Reports hub | Medium |
| Settings | **Partially Implemented** | Profile edit sheets; CC `SettingsTabV3`; no org Settings nav | — | Medium |

**Verify navigation / routes / empty states**

| Check | Result |
|-------|--------|
| Navigation works (live hub) | **Yes** — create, overview, my events, portfolio, marketplace |
| Full EOS rail routes | **No** — shell not mounted |
| Empty states | **Yes** on hub (first event), events/attendees/vendors screens |
| Routes exist | Wizard, event workspace, portfolio, my events — **yes**; Marketing/Reports top-level — **no** |

**11.6 sub-verdict:** **Partially implemented**.

---

## 11.7 Technical Quality

| Concern | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Loading states | **Implemented and Working** | Hub skeletons; `.when(loading:)` on EOS screens | Small |
| Error states | **Partially Implemented** | Hub retry empty card; many EOS screens plain `Text('$err')` without retry | Small |
| Empty states | **Implemented and Working** | Hub / events / attendees / vendors empties | Small |
| Offline behaviour | **Partially Implemented** | Hub cloud_off retry; mock fallback flags on providers; not systematic offline cache for organizer | Medium |
| Responsive layout | **Partially Implemented** | CC Overview `LayoutBuilder` ≥900; hub scroll; EOS scaffolds vary | Small–Medium |
| Performance | **Partially Implemented** | `listForOrganizer` loads all events + tiers (no pagination); analytics synthesizes client-side | Medium |

**11.7 sub-verdict:** **Partially implemented**.

---

## Cross-cutting routing finding (highest impact)

```487:490:mobile/lib/router/app_router.dart
      GoRoute(
        path: '/organizer',
        redirect: (context, state) {
          if (state.uri.path == '/organizer') return '/home';
```

`OrganizerHomeScreen` (Dashboard, Events, Tickets, Vendors, Attendees, Analytics, Live Ops) is **Implemented but Hidden**. Live organizers use `OrganizerHomeHubScreen` inside the customer `/home` shell instead.

This single fact explains why many “dashboard KPIs / analytics / global attendees” features look “missing” in Live QA even though screens and `GET /organizers/me/dashboard` exist.

---

## Backend endpoint snapshot (organizer-relevant)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/organizers/me` | Profile |
| GET | `/organizers/me/dashboard` | KPI aggregates |
| GET | `/organizers/me/events` | All events, **no filter/sort/pagination** |
| POST/PATCH | `/events`, `/events/:id` | Create / update |
| POST | `/events/:id/publish`, `/go-live` | Lifecycle |
| GET | `/events/:id/finance/summary` | Per-event finance |
| GET | `/events/:id/check-ins`, `/feed`, `/incidents` | Ops |
| GET | `/event-config/templates` | Templates catalog |
| — | `/events/:id/duplicate` | **Missing** |
| — | Organizer time-series analytics | **Missing** |
| — | Organizer calendar / task CRUD | **Missing** |

---

## Effort summary

| Area | Dominant effort |
|------|-----------------|
| 11.1 Dashboard Home | **Small** (unhide/wire KPIs onto live path) |
| 11.2 Event Overview | **Small**–**Medium** (filters/search/sort) |
| 11.3 Command Center create flows | **Small**–**Medium** (duplicate API, templates); Import **Large** |
| 11.4 Insights | **Medium** (real trends) |
| 11.5 Productivity | **Medium**–**Large** (calendar/tasks/reminders delivery) |
| 11.6 Navigation IA | **Small**–**Medium** (expose shell / add Finance); Marketing **Large** |
| 11.7 Technical quality | **Small**–**Medium** |

---

## Overall conclusion

### Partially implemented

Substantial organizer capability already exists (hub landing, wizard, per-event command center, finance/ops/CRM APIs, dashboard KPI API, portfolio). Gaps are driven by **dual architecture + hidden EOS shell**, missing **list filters**, **true insights time-series**, **import/marketing/org calendar**, and incomplete **templates/duplicate/reminders** wiring — not a greenfield dashboard.

---

## Prioritized implementation roadmap (single Phase 11 completion sprint)

Goal: one coherent Organizer Dashboard & Command Center on the **live** path — without redesigning Event OS architecture.

### P0 — Make the command center reachable (must ship)

1. **Resolve organizer home IA** — mount `OrganizerHomeScreen` (or equivalent KPI dashboard) as the organizer landing **or** port EOS dashboard KPIs/attention/recent events onto `OrganizerHomeHubScreen`  
   - **Effort: Small**  
2. **Stop treating `/organizer` as a dead redirect** for the shell entry (keep wizard/event child routes)  
   - **Effort: Small**  
3. **Wire dashboard summaries** users expect on first paint: revenue, tickets, attendees, vendors, event counts + quick actions  
   - **Effort: Small** (API already exists)

### P1 — Event overview completeness

4. **Status buckets / filters** on events list: Upcoming, Live, Draft, Completed (client filter OK; prefer `?status=` on `listForOrganizer`)  
   - **Effort: Small**  
5. **Search + sort** on organizer events  
   - **Effort: Small**  
6. **Empty/error retry** parity on EOS list screens  
   - **Effort: Small**

### P1b — Create / templates / duplicate

7. **`POST /events/:eventId/duplicate`** (or document client-seed as official) + entry CTA from event list/workspace  
   - **Effort: Small**  
8. **Template picker** on create entry using `event-config/templates` + portfolio catalog  
   - **Effort: Medium**  
9. **Do not** build Import Event in this sprint (**Large** — defer)

### P2 — Insights & productivity (scoped)

10. **Org insights strip** reusing dashboard + per-event finance/check-in (honest empty if no series)  
    - **Effort: Medium**  
11. **Defer** full time-series analytics API, push notifications, marketing module, org calendar, assignable task board to follow-on  
    - **Effort: Large** each

### Explicitly out of this sprint

- Marketing suite  
- Global Reports product  
- Event import  
- Push / in-app notification platform  
- Full organizer calendar & task board  

---

## STOP

Phase 11 gap analysis complete. No implementation performed. Await Phase 11 Completion Sprint assignment.
