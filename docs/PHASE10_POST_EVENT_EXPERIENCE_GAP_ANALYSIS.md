# PHASE 10 — POST-EVENT EXPERIENCE GAP ANALYSIS

**Date:** 2026-07-25  
**Scope:** Attendee Post-Event Experience (summary, feedback, certificates, media, networking follow-up, personal history, recommendations)  
**Method:** Read-only audit of Flutter (`mobile/`) and NestJS (`services/api/`) + DB (`infra/db/`)  
**Constraint:** Audit only — no code changes, no redesign, no fixes  

**Naming note:** Older `docs/phase10-*.md` files refer to **platform launch readiness**, not attendee Post-Event Experience. Attendee Phase 9 completion marked Phase 10 as **Not started**.

---

## Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Live QA** | No dedicated attendee post-event destination (no Recap / Summary / Feedback / Memories hub after an event ends) |
| **Attendee product (Phase 10 target)** | **Mostly not implemented** as a cohesive post-event experience |
| **Related building blocks** | My Events **Past**, ticket orders, Entry attendance history, event detail gallery, Discover recommendations, Phase 8 connections + community wall, Phase 9 service bookings |
| **Organizer-only post-event** | Closing workspace / completed reports — **wrong persona** |
| **Overall classification** | **Partially implemented** |

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | End-to-end usable for the intended persona |
| **Implemented but Hidden** | Built but not discoverable in primary UX |
| **Implemented but Not Wired** | Code exists; not connected to attendee post-event flows |
| **Backend Complete / Frontend Missing** | API/DB ready; no attendee UI |
| **Frontend Complete / Backend Missing** | UI present; API synthetic/stubbed/absent |
| **Partially Implemented** | Meaningful pieces exist; gaps block MVP |
| **Not Implemented** | No meaningful product implementation |

---

## Why Phase 10 is unavailable (Live QA)

| Check | Result |
|-------|--------|
| Route like `/attendee/events/:eventId/recap` | **None** in `AttendeeRoutes` / `attendee_commerce_routes.dart` |
| CTA on My Events **Past** (“View recap”) | **None** — past tiles open Entry / Event Detail only |
| Feedback / certificate / badge APIs | **None** in Nest for attendees |
| Closest surfaces | My Events Past, Orders, Activity, Entry attendance, Event Detail gallery, Discover “Recommended”, People Hub, Services bookings |

Organizer closing is **not** the attendee product:

- `EventCompletedReports` — `portals/customer/workspace/widgets/event_completed_reports.dart`
- `EventClosingWorkspace` — `portals/customer/closing/event_closing_*`

---

## Stack map (reusable building blocks)

### Flutter (attendee-adjacent)

| Asset | Path | Relevance |
|-------|------|-----------|
| My Events Past / History | `attendee_my_events_screen.dart`, `myEventsBundleProvider` | Past events + order history |
| Orders archive | `attendee_orders_screen.dart`, `TicketCommerceApi` | Ticket purchases |
| Activity timeline | `attendee_activity_screen.dart` | Local views/saves/purchases |
| Entry attendance | `attendee_event_entry_screen.dart`, `buildAttendanceTimeline` | Check-in time + pass timeline |
| Event gallery | `event_detail_gallery.dart`, `PublicEvent.resolvedGallery` | Promo / official media URLs |
| Recommendations | `discover_recommendation_engine.dart`, `eventDetailRecommendedProvider`, Tickets “Recommended for you” | Heuristic Discover |
| Preferred categories | Attendee profile `preferredEventCategories` | Preference signal |
| Connections / wall | Phase 8 People Hub | Event-scoped; still openable by `eventId` |
| Service bookings | Phase 9 `/attendee/services/bookings` | Rental history |

### Nest / DB

| Asset | Path | Relevance |
|-------|------|-----------|
| Ticket entitlements + `checked_in_at` | Commerce `GET me/ticket-entitlements` | Attendance yes/no + timestamp |
| `event_check_ins` | `022_phase54_persistence.sql` | Ops audit; not attendee recap API |
| Program / live updates | `program.service.ts` | Schedule — not personal session attendance |
| `galleryMedia` on events | `events.service.ts` | Organizer-supplied gallery |
| Celebration wall | `celebration-wall.service.ts` | Community posts/photos |
| Vendor ratings | `vendors.service.ts` → `ratingAverage: null` | No review tables |
| Feedback / certificate / badge tables | — | **Absent** |
| Connections | `053_attendee_networking.sql` | Event-scoped mutual connections |
| Service bookings | `rental_bookings` + Phase 9 APIs | Post-event service history |

---

## 10.1 Event Summary

| Feature | Classification | Evidence | Why unavailable / incomplete | Effort |
|---------|----------------|----------|------------------------------|--------|
| Event Summary Screen (attendee) | **Not Implemented** | No `/attendee/events/:id/recap` (or equivalent) | Organizer-only: `EventCompletedReports`, `EventClosingWorkspace` | **Medium** |
| Event Completion Status | **Partially Implemented** | `AttendeeEventLifecycle.past` / My Events Past; pass live status “completed” heuristics | No dedicated “event finished — here’s your wrap” surface | **Small** |
| Attendance Summary | **Partially Implemented** | Entry “Attendance history” + `checkedInAt` (`attendee_event_entry_screen.dart`, `GET me/ticket-entitlements`) | Per-pass snippet, not post-event hub | **Medium** |
| Sessions Attended | **Not Implemented** | Local personal schedule prefs only (`attendee_personal_schedule_store.dart`) | No per-session attendance API | **Large** |
| Time Spent | **Not Implemented** | No dwell/time tracking | — | **Large** |
| Personal Event Statistics | **Not Implemented** | No attendee stats endpoint | Organizer KPIs only (`EventSummarySnapshot`) | **Medium** |

---

## 10.2 Feedback & Reviews

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| Event Rating | **Not Implemented** | No feedback routes/APIs/tables | — | **Medium** |
| Session Rating | **Not Implemented** | — | — | **Medium** |
| Speaker Rating | **Not Implemented** | Speakers on event detail are content-only | — | **Medium** |
| Vendor Rating | **Frontend Complete / Backend Missing** (marketplace) / **Not Implemented** (attendee post-event) | Synthetic reviews in `marketplace_models.dart`; API ratings always `null` | Design doc only (`docs/phase40/MARKETPLACE_TRUST_LAYER_DESIGN.md`) | **Large** |
| Written Feedback | **Not Implemented** | No submit endpoint | — | **Medium** |
| Anonymous Feedback | **Not Implemented** | — | — | **Medium** |

Organizer `feedbackCount` in closing models counts **activity feed length**, not real feedback submissions.

---

## 10.3 Certificates & Achievements

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| Attendance Certificate | **Not Implemented** | No certificate entity/API/UI | Check-in exists; no cert generation | **Large** |
| Certificate Download | **Not Implemented** | — | — | **Medium** (after cert) |
| Digital Badge | **Not Implemented** | UI “badge” = status chips / icons only | — | **Large** |
| Achievement Unlocks | **Not Implemented** | — | — | **Large** |
| Participation History | **Partially Implemented** | My Events Past + Entry timeline + Orders | Fragmented across screens | **Medium** |

---

## 10.4 Event Media

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Event Gallery | **Partially Implemented** | `EventDetailGallerySection` on attendee event detail (`resolvedGallery` / `galleryMedia`) | Promotional gallery on detail — **no dedicated post-event Memories destination** | **Medium** |
| Official Photos | **Partially Implemented** | Event metadata `galleryMedia` in `events.service.ts` | Content-dependent; no post-event publish flow | **Medium** |
| Videos | **Partially Implemented** | Gallery viewer supports video (`video_player`) | Same as gallery | **Medium** |
| Shared Community Photos | **Partially Implemented** | Celebration wall `photoUrl` + Phase 8 Community tab | Social wall, not curated Memories | **Medium** |
| Download Media | **Not Implemented** / **Partial** | Preview viewer only; no attendee download/archive | Pass “download” is ticket text | **Medium** |

Organizer `gallery` / `memories` modules in `event_module_registry.dart` are **coming soon / excluded** — **Implemented but Hidden** (no-op) for organizers; still not attendee post-event media.

---

## 10.5 Post-Event Networking

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Continue Conversations | **Not Implemented** | Phase 8 excluded DMs | No messaging API for attendees | **Large** |
| Saved Connections | **Partially Implemented** | Phase 8 `networkingConnectionsProvider(eventId)`, People → Connections | Still event-scoped; **no post-event “keep in touch” hub** | **Medium** |
| Contact History | **Partially Implemented** | Business card share/save (Phase 8) | No share-history ledger | **Medium** |
| Community Follow-up | **Partially Implemented** | Community wall via People Hub for same `eventId` | **Implemented but Not Wired** as post-event prompt | **Small**–**Medium** |

---

## 10.6 Personal History

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Past Events | **Implemented and Working** | `AttendeeMyEventsScreen` → filter **Past** | Not framed as post-event recap | **Small** |
| Event Timeline | **Partially Implemented** | `AttendeeActivityScreen`; Entry attendance timeline | Not a dedicated post-event timeline | **Medium** |
| Booking History | **Partially Implemented** | Phase 9 `/attendee/services/bookings` | Rentals only | **Small** |
| Tickets Archive | **Implemented and Working** | Orders + My Events history + passes | No post-event framing | **Small** |
| Attendance History | **Partially Implemented** | Entry “Attendance history” (`checkedInAt` + timeline) | Per-pass, not cross-event ledger | **Medium** |
| Service History | **Partially Implemented** | Phase 9 service bookings | Rentals only | **Small** |

---

## 10.7 Recommendations

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Similar Events | **Implemented and Working** | `HeuristicDiscoverRecommendationEngine.similar`; Event Detail rails | Pre-event discover, not “because you attended” | **Small** |
| Recommended Events | **Implemented and Working** | Tickets tab “Recommended for you”; Discover rails | Heuristic catalog | **Small** |
| Favourite Categories | **Partially Implemented** | Profile `preferredEventCategories` used by engine | No post-event favourites UX | **Small** |
| Favourite Organizers | **Not Implemented** | No favourite-organizer store/API | — | **Medium** |
| Personalised Suggestions | **Partially Implemented** | Interests + categories + recently viewed + purchased IDs | No attendance-based post-event model | **Medium** |

---

## 10.8 Technical Quality

| Concern | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Loading / Error / Empty | **Implemented and Working** on existing history/discover/gallery | My Events, Activity, Orders, Event Detail | **Small** to reuse |
| Offline | **Partially Implemented** | Offline banners on My Events / Activity / passes / services | **Medium** for new recap |
| Responsive / Performance | **Partially Implemented** | EOS patterns elsewhere | **Small**–**Medium** |

**Dedicated post-event surface quality:** **Not Implemented** (no recap destination yet).

---

## Organizer-only (exclude from attendee Phase 10)

| Surface | Path | Notes |
|---------|------|-------|
| Event completed reports | `event_completed_reports.dart` | Organizer KPIs |
| Closing workspace | `event_closing_*` | Financial/ops closure |
| Gallery / Memories modules | `event_module_registry.dart` | Coming soon / excluded |

---

## Effort summary (attendee Phase 10 lens)

| Area | Dominant effort |
|------|-----------------|
| 10.1 Event Summary / Recap | **Medium** |
| 10.2 Feedback MVP | **Medium** |
| 10.3 Certificates / badges | **Large** (defer) |
| 10.4 Event Memories | **Medium** |
| 10.5 Continue networking | **Small**–**Medium** |
| 10.6 Personal History unify | **Small**–**Medium** |
| 10.7 Recommendations reframing | **Small**–**Medium** |
| 10.8 Technical quality | **Small**–**Medium** |

---

## Prioritized implementation roadmap (single Phase 10 completion sprint)

Goal: **minimum viable post-event wrap-up** — revisit, recap, feedback, reconnect, discover what’s next. **No certificates / achievements / multi-entity ratings.**

### P0 — Post-Event Hub (must ship)

1. **`/attendee/events/:eventId/recap`** with banner, completed badge, attendance status, check-in time, date, quick stats, quick actions  
   - **Effort: Medium**
2. Wire CTA from **My Events → Past** and Event Detail when `lifecycle == past`  
   - **Effort: Small**
3. **Event Recap** cards composing: check-in, ticket, Phase 9 bookings count, Phase 8 connections count, gallery/wall photo count (best-effort)  
   - **Effort: Medium**

### P1 — Feedback MVP (recommended engagement)

4. Overall event rating + written feedback + optional anonymous flag; one submission per attendee; confirmation  
   - New thin table + Nest endpoints + Flutter form on recap  
   - **Effort: Medium**

### P1b — Event Memories + Continue Networking (same sprint if capacity)

5. **Event Memories** section reusing `resolvedGallery` + gallery viewer; optional wall photo shortcut  
   - **Effort: Medium**
6. **Continue Networking** panel: connections made, link to People Hub / Community wall; prompt copy only — **no messaging**  
   - **Effort: Small**

### P2 — Discover what’s next + unified history

7. **Because you attended…** rail via existing `HeuristicDiscoverRecommendationEngine` + past/purchased event IDs  
   - **Effort: Small**–**Medium**
8. **Personal History** section on recap or Activity: past events, tickets, bookings, attendance, connections, services shortcuts  
   - **Effort: Small**–**Medium**

### P3 — Explicitly defer (Phase 10B+)

9. Certificates, digital badges, achievements, leaderboards  
10. Session / speaker / vendor ratings  
11. Complex surveys  
12. Time-spent / sessions-attended telemetry  
13. Continue DM conversations  

### Suggested COMPLETE definition (sprint)

Phase 10 **COMPLETE** when an attendee with a **past** ticketed event can:

1. Open a dedicated **post-event recap** for that event  
2. See a **personal summary** (attendance + ticket + bookings/connections counts)  
3. **Submit overall event feedback** (once)  
4. Open **Event Memories** (gallery) and **Continue Networking** (People/Wall)  
5. See **Because you attended…** recommendations  

Certificates and multi-entity ratings remain deferred.

---

## Final determination

| Verdict | **Partially implemented** |
|---------|---------------------------|
| Dedicated attendee Post-Event Experience | **Not implemented** (no recap/feedback destination) |
| Reusable history / media / recommend / social / services blocks | **Partially / working** across Phases 2–9 |
| Organizer post-event closing | **Working** for organizers only |
| Strongest reuse | My Events Past + check-in + galleryMedia + Discover engine + Phase 8 People/Wall + Phase 9 bookings |
| Next step | Implementation sprint per P0–P2 roadmap above |

**STOP — audit only. No implementation performed. Do not begin Phase 10 build until explicitly requested.**
