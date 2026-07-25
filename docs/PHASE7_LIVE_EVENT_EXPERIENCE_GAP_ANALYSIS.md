# PHASE 7 — LIVE EVENT EXPERIENCE GAP ANALYSIS

**Date:** 2026-07-24  
**Scope:** Attendee Live Event Dashboard, Agenda & Sessions, Live Engagement, Networking, Event Updates, Live Participation, Technical Quality  
**Surfaces:** Flutter `mobile/`, Nest `services/api/`, DB `infra/db/`  
**Method:** Evidence-only audit — **no code was written or modified**  
**Live QA input:** Attendee app exposes **no** Phase 7 live event / engagement / networking participation experience

---

## Executive verdict

Phase 7 (Attendee Live Event Experience) is **partially implemented at the platform layer** and **not delivered as an attendee product**.

Live QA is correct: there is **no** attendee “live event” shell, join-live flow, engagement suite, or networking suite.

| Layer | Reality |
|-------|---------|
| **Attendee Live Event UX** | **Not implemented** as a dedicated experience |
| **Agenda (read-only)** | **Partial** — public program API + Agenda section on attendee event detail |
| **Schedule tab** | Ticketed-event timeline only — **not** session agenda / live session progress |
| **Check-in / pass live status** | Phase 6A — admission status only, not a live event dashboard |
| **Organizer program / ops feed / wall** | Exist for Event OS / celebration wall — **not** attendee Phase 7 |
| **Polls, Q&A, networking, ratings, gamification** | **Not implemented** |

| Is Phase 7…? | Answer |
|--------------|--------|
| Already implemented but hidden | **No** |
| Partially implemented | **Yes** (fragments only) |
| Backend only | **No** |
| Frontend only | **No** |
| Not implemented | **Mostly** for the attendee live product |

**Note:** `docs/phase7-super-admin-report.md` refers to a **different** Phase 7 (Super Admin Control Tower), not Attendee Live Event Experience.

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | Present and wired for the intended attendee live path |
| **Implemented but Hidden** | Built but not surfaced on the primary attendee flow |
| **Implemented but Not Wired** | Exists in codebase; wrong persona/route/data contract |
| **Backend Complete / Frontend Missing** | API/DB ready; attendee UI missing |
| **Frontend Complete / Backend Missing** | UI exists; no durable backend |
| **Partially Implemented** | Incomplete across layers |
| **Not Implemented** | No meaningful product implementation |

---

## Why Phase 7 is unavailable (Live QA)

| Expected attendee Phase 7 surface | Status | Why unreachable |
|-----------------------------------|--------|-----------------|
| Live event experience | Absent | No `/attendee/live/...` (or equivalent) route or dashboard |
| Live engagement | Absent | No polls/Q&A/surveys/reactions product for attendees |
| Networking | Absent | No attendee directory / connect / DM product |
| Live participation | Absent | No ask-question / ratings / leaderboards for attendees |

Closest existing surfaces are **Event Detail Agenda**, **Schedule tab** (ticketed events), **Phase 6A Event Entry / pass status**, and **organizer** program/ops/wall — none of which constitute Phase 7.

---

## Stack map (shared evidence)

| Area | Evidence |
|------|----------|
| **Program / agenda DB** | `infra/db/035_event_programs.sql` — `event_program_items`, `event_program_reminders`, `event_activity_log` |
| **Program API** | `GET events/:eventId/program` (public); manage CRUD under CommerceAuth — `program.service.ts`, `events.controller.ts` |
| **Attendee agenda UI** | `_AgendaSection` in `attendee_event_detail_screen.dart` via `publicEventProgramProvider` |
| **Celebration wall** | `infra/db/029_celebration_wall.sql`; `celebration-wall.service.ts`; organizer FE `customer_event_wall_screen.dart` |
| **Ops live feed / SSE** | `event_feed_items`; `GET events/:eventId/feed`; `GET events/:eventId/feed/stream` (**organizer-owned**) |
| **Chat schema (legacy)** | `chat_threads`, `chat_participants`, `chat_messages`, `notifications` in `owanbe_core.sql` — **no attendee networking module found** |
| **Phase 6A admission** | Pass live status + Entry polling — check-in visibility only |

---

## 7.1 Live Event Dashboard

### Live Event Status

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Event lifecycle via entitlements + `AttendeeEventLifecycle` / Phase 6A `AttendeePassLiveStatus`; Schedule “Ongoing”; My Events “Happening now.” filter copy |
| **Missing** | Dedicated live-event dashboard; event `status=live` surfaced as attendee “join live” hub |
| **Why unavailable** | Status fragments live under Tickets / Schedule / Entry — not a Phase 7 dashboard |
| **Effort** | **Medium** |

### Event Countdown

| Field | Value |
|-------|--------|
| **Classification** | **Implemented but Not Wired** (wrong persona) / **Partially** for attendees |
| **Evidence** | Organizer/customer: `HomeWelcomeHero` countdown, `formatCountdown`, program day `countdownLabel`; Command Center / workspace reminder countdown |
| **Attendee** | No live-event countdown widget on attendee dashboard; Schedule shows dates only |
| **Effort** | **Small** to compose onto attendee live hub |

### Happening Now

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Schedule / My Events filter ongoing ticketed events (`AttendeeEventLifecycle.ongoing`) |
| **Missing** | Current **session** “happening now”; live stage indicator |
| **Effort** | **Medium** (needs session clock from program statuses) |

### Join Live Event

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** |
| **Evidence** | No Join Live CTA / route under `AttendeeRoutes` |
| **Effort** | **Medium** (product shell + deep link into agenda/engagement) |

### Live Attendance Status

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Phase 6A live pass statuses + Entry attendance summary; entitlement `checked_in` |
| **Missing** | Live-event-dashboard attendance panel (cohort presence, session attendance) |
| **Effort** | **Small** to surface existing pass status on a live hub |

### Live Check-in Indicator

| Field | Value |
|-------|--------|
| **Classification** | **Implemented and Working** (Phase 6A; not Phase 7 shell) |
| **Evidence** | Pass chips, Entry eligibility, dashboard check-in ActionChips → Entry |
| **Why not Phase 7** | Indicator exists; Phase 7 dashboard that hosts it does not |
| **Effort** | **Small** to embed in live dashboard |

---

## 7.2 Agenda & Sessions

### Full Event Agenda

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | `GET events/:eventId/program` public; Flutter `_AgendaSection` lists items (title, time, owner) |
| **Organizer** | Full run sheet: `customer_event_program_screen.dart`, `program_providers.dart`, manage APIs |
| **Gap** | No dedicated attendee agenda module; no status/progress UI beyond flat list |
| **Effort** | **Medium** |

### Session List / Session Details

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** (list) / **Not Implemented** (rich details) |
| **Evidence** | Program items ≈ sessions; ListTile only — no detail route, room, speakers link, materials |
| **Effort** | **Medium** |

### Personal Schedule

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | `AttendeeScheduleTab` — **ticketed events** upcoming/ongoing/past, not personal session picks |
| **Missing** | “My sessions” / starred agenda items |
| **Effort** | **Medium–Large** |

### Session Reminders

| Field | Value |
|-------|--------|
| **Classification** | **Backend Complete / Frontend Missing** (attendee) |
| **Evidence** | DB `event_program_reminders`; `ProgramService` reminder send path (organizer ops) |
| **Missing** | Attendee push/in-app session reminders |
| **Effort** | **Medium** |

### Current / Upcoming Session

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** (data can support; UI missing) |
| **Evidence** | Item `status` includes `in_progress`, `planned`, etc.; attendee Agenda does **not** highlight current/upcoming |
| **Effort** | **Small–Medium** |

### Live Session Progress

| Field | Value |
|-------|--------|
| **Classification** | **Frontend Complete / Backend Missing** for attendees — actually **organizer FE + BE**, attendee missing |
| **Evidence** | Organizer can set status via `POST …/program/items/:itemId/status`; attendee UI ignores status |
| **Classification (attendee)** | **Not Implemented** |
| **Effort** | **Medium** |

---

## 7.3 Live Engagement

### Live Announcements

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** (ops feed) / **Not Implemented** (attendee) |
| **Evidence** | `event_feed_items` + ops `listFeed`; SSE stream organizer-only |
| **Effort** | **Medium** |

### Push Announcements

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** (attendee live announcements) |
| **Evidence** | `NotificationService` used for tickets/invites/email — not live event announcement channel to attendees |
| **Effort** | **Large** |

### Polls / Voting / Surveys

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** |
| **Evidence** | No poll/survey tables, modules, or Flutter screens found |
| **Effort** | **Large** |

### Live Q&A / Ask Questions

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** |
| **Evidence** | Program template text mentions “Q&A session” as agenda title only (`program.service.ts` templates) |
| **Effort** | **Large** |

### Audience Reactions

| Field | Value |
|-------|--------|
| **Classification** | **Implemented but Not Wired** (wrong product surface) |
| **Evidence** | Celebration wall reactions API + organizer wall UI (`POST …/wall/posts/:postId/reactions`); **not** in-session audience reactions for attendees |
| **Effort** | **Medium** to adapt; **Large** for true live-reaction channel |

### Live Feedback

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** (attendee live feedback stream) |
| **Effort** | **Medium–Large** |

---

## 7.4 Networking

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Attendee Directory | **Not Implemented** | Organizer guest list only (`customer_event_guests_screen.dart`) — not peer directory | Large |
| Search Attendees | **Not Implemented** | — | Large |
| Attendee Profiles (peer) | **Partially Implemented** | Own profile edit exists; no public peer profiles for networking | Medium |
| Connect with Attendees | **Not Implemented** | — | Large |
| Private Messaging | **Frontend Complete / Backend Missing** at hub for **other** personas; attendee-to-attendee **Not Implemented**. Legacy `chat_*` tables unused for this product | Large |
| Meeting Requests | **Not Implemented** | — | Large |
| Digital Business Cards | **Not Implemented** | — | Medium |
| Connection Management | **Not Implemented** | — | Large |

**Why unavailable:** No attendee networking routes, providers, or APIs. Hub Messages (`home_messages_tab.dart`) are organizer/vendor/home previews — not live-event networking.

---

## 7.5 Event Updates

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Schedule Change Notifications | **Partially Implemented** | Organizer program auto-shift + activity log; attendee not notified | Medium |
| Speaker Updates | **Partially Implemented** | Speakers on public event metadata / detail section; no delta notifications | Medium |
| Venue Updates | **Partially Implemented** | Venue on event detail / Entry; no change alerts | Medium |
| Emergency Announcements | **Not Implemented** | Attendee profile stores **emergency contact** fields — not emergency broadcast | Large |
| Live Alerts | **Implemented but Not Wired** | Ops feed + SSE organizer-only; Flutter does not consume SSE even for ops | Medium |

---

## 7.6 Live Participation

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Ask Questions | **Not Implemented** | — | Large |
| Session Feedback | **Not Implemented** | — | Medium |
| Event Feedback | **Not Implemented** | — | Medium |
| Session / Event Ratings | **Not Implemented** | Vendor `ratingAverage` stub only — unrelated | Medium |
| Activities | **Not Implemented** | `event_activity_log` is program ops audit, not attendee activities | Large |
| Leaderboards | **Not Implemented** | — | Large |
| Gamification | **Not Implemented** | — | Large |

---

## 7.7 Technical Quality (for Phase 7 surfaces)

| Concern | Classification | Notes | Effort |
|---------|----------------|-------|--------|
| Loading / Error / Empty | **Partially Implemented** | Present on Agenda section, Schedule, Entry; N/A for missing Phase 7 modules | Small when building shell |
| Offline Behaviour | **Partially Implemented** | Pass offline cache (6A); no offline live engagement | Medium |
| Live Refresh | **Partially Implemented** | Entry/Pass poll (6A); Agenda does not auto-refresh on program status changes | Medium |
| Real-time Updates | **Implemented but Not Wired** | SSE organizer-only; no attendee client | Medium–Large |
| Responsive Layout | **Partially Implemented** | Existing attendee screens follow EOS; no live shell | Small |
| Performance | **N/A / Partial** | No Phase 7 realtime load yet | — |

---

## Feature scorecard

| # | Feature | Classification | Effort |
|---|---------|----------------|--------|
| 7.1 | Live Event Status | Partially Implemented | Medium |
| 7.1 | Event Countdown | Partially / Not Wired | Small |
| 7.1 | Happening Now | Partially Implemented | Medium |
| 7.1 | Join Live Event | Not Implemented | Medium |
| 7.1 | Live Attendance Status | Partially Implemented | Small |
| 7.1 | Live Check-in Indicator | Implemented and Working (6A) | Small embed |
| 7.2 | Full Agenda | Partially Implemented | Medium |
| 7.2 | Session List / Details | Partial / Not Implemented | Medium |
| 7.2 | Personal Schedule | Partially Implemented | Medium–Large |
| 7.2 | Session Reminders | Backend Complete / FE Missing | Medium |
| 7.2 | Current / Upcoming Session | Partially Implemented | Small–Medium |
| 7.2 | Live Session Progress | Not Implemented (attendee) | Medium |
| 7.3 | Announcements / Push | Partial / Not Implemented | Medium–Large |
| 7.3 | Polls / Surveys / Voting | Not Implemented | Large |
| 7.3 | Q&A | Not Implemented | Large |
| 7.3 | Audience Reactions | Implemented but Not Wired | Medium–Large |
| 7.4 | Networking suite | Not Implemented | Large |
| 7.5 | Event Updates / Alerts | Partial / Not Wired | Medium |
| 7.6 | Participation / ratings / gamification | Not Implemented | Medium–Large |
| 7.7 | Live technical quality | Partial | Medium |

---

## Key file index

### Attendee (limited Phase 7-adjacent)

| Path | Role |
|------|------|
| `mobile/lib/portals/attendee/widgets/attendee_schedule_tab.dart` | Ticketed-event schedule |
| `mobile/lib/portals/attendee/screens/attendee_event_detail_screen.dart` | Agenda + speakers sections |
| `mobile/lib/features/public/providers/event_detail_providers.dart` | `publicEventProgramProvider` |
| `mobile/lib/core/api/events_api.dart` | `fetchPublicProgram` |
| Phase 6A Entry / pass status | Live check-in indicator only |

### Organizer / Ops (not attendee Phase 7)

| Path | Role |
|------|------|
| `mobile/lib/portals/customer/screens/customer_event_program_screen.dart` | Program run sheet |
| `mobile/lib/features/operations/screens/live_event_feed_screen.dart` | Ops live feed UI |
| `mobile/lib/portals/customer/screens/customer_event_wall_screen.dart` | Celebration wall |
| `services/api/src/modules/events/program.service.ts` | Program + reminders |
| `services/api/src/modules/events/celebration-wall.service.ts` | Wall posts/reactions |
| `services/api/src/integrations/realtime/event-feed-sse.controller.ts` | Organizer SSE |

### API endpoints (relevant)

| Method | Path | Persona |
|--------|------|---------|
| `GET` | `events/:eventId/program` | Public / attendee-usable |
| `POST/PATCH…` | `events/:eventId/program/...` | Organizer |
| `GET` | `events/:eventId/wall` | Public wall |
| `POST` | `events/:eventId/wall/posts` (+ reactions) | Public post/react |
| `GET` | `events/:eventId/feed` | Organizer |
| `GET` | `events/:eventId/feed/stream` | Organizer SSE |

### DB

| Table | Relevance |
|-------|-----------|
| `event_program_items` | Agenda / sessions |
| `event_program_reminders` | Session reminders (ops) |
| `event_activity_log` | Program audit |
| `event_feed_items` | Ops announcements stream |
| `event_wall_posts` | Celebration wall |
| `chat_*` / `notifications` | Legacy schema — unused for attendee networking |

---

## Overall determination

**Phase 7 is partially implemented** — specifically:

- **Reusable building blocks:** public program/agenda read API + attendee Agenda list; speakers on detail; Schedule of ticketed events; Phase 6A check-in/live pass status; organizer program management; ops feed/SSE; celebration wall reactions.
- **Missing attendee product:** Live Event Dashboard, Join Live, session-centric personal schedule, live engagement (polls/Q&A/surveys), networking, emergency/live alerts to attendees, ratings/gamification, attendee realtime client.

It is **not** “already built but hidden,” **not** backend-only, and **not** frontend-only.

---

## Prioritized roadmap — single Phase 7 completion sprint

Focus on **compose-first** delivery using existing program + 6A + feed patterns. Defer true networking/gamification if sprint capacity is limited.

### P0 — Live Event Hub (must ship)

1. **Attendee Live Event Dashboard** for ticketed ongoing/upcoming events  
   - Status, countdown, happening now, embed check-in/pass status, CTA into Entry + Agenda  
   - **Effort: Medium**
2. **Join Live Event** entry point from Schedule / My Events / Tickets  
   - **Effort: Small–Medium**
3. **Agenda upgrade** — current/upcoming/in-progress from `event_program_items.status`; session detail sheet  
   - **Effort: Medium**

### P1 — Live updates & session awareness

4. **Attendee-safe announcements** — read curated feed items or program activity (no organizer SSE required initially); poll while Live Hub open  
   - **Effort: Medium**
5. **Session reminders** — wire existing reminder model to attendee notifications / in-app  
   - **Effort: Medium**

### P2 — Engagement MVP (one vertical)

6. Pick **one**: Live Q&A **or** Polls **or** Session feedback/ratings  
   - Prefer session feedback/ratings first (smaller schema)  
   - **Effort: Medium–Large**

### P3 — Explicitly defer (post-sprint / Phase 7B)

7. Full networking (directory, DM, meeting requests, business cards) — **Large**  
8. Audience live reactions / gamification / leaderboards — **Large**  
9. Push emergency broadcast channel — **Large**  
10. Attendee SSE subscription — only after P0–P1 polling proves UX

### Suggested sprint outcome definition

Phase 7 **COMPLETE** when an attendee with a ticket can:

1. Open a **Live Event** hub for an ongoing/upcoming event  
2. See **countdown / happening now / check-in status**  
3. Browse **agenda with current/upcoming session**  
4. Receive **at least one** live update path (announcements or program status refresh) without manual navigation hunting  
5. Complete **one** participation action (feedback/rating **or** Q&A/poll)

Networking and gamification may remain **PARTIAL / deferred** if called out in the completion report.

---

## Final determination

| Verdict | **Partially implemented** |
|---------|---------------------------|
| Attendee Live Event Experience | **Mostly not implemented** |
| Live QA explanation | Correct — no Phase 7 attendee surfaces |
| Next step | Implementation sprint per roadmap above |

**STOP — audit only. No implementation performed.**
