# PHASE 8 — NETWORKING & SOCIAL EXPERIENCE COMPLETION REPORT

**Date:** 2026-07-25  
**Scope:** Attendee event-scoped networking MVP (directory, peer profiles, connections, business card, discover, community wall, notifications)  
**Out of scope:** Organizer tools, DMs, group chat, meetings, calendar sync, voice/video, advanced social graph, event-wide chat rooms  
**Method:** New event-scoped connections table + Nest networking service; Flutter People Hub reusing peer profile card API + celebration wall

---

## Verdict

**Phase 8 is COMPLETE** for the Attendee Networking & Social Experience defined in this sprint.

Attendees with a ticket for an event can browse opted-in peers, open peer profiles, send/accept/decline/remove mutual connections, share a digital business card, see deterministic suggestions, post/react on a lightweight community wall, and receive in-app networking notifications — without building a full social network or organizer surfaces.

---

## Certification checklist

| Item | Result | Evidence |
|------|--------|----------|
| Event Attendee Directory | **PASS** | `/attendee/event/:eventId/people` — photo, name, company, role, interests, mutual tags, connection status; search + company/interest filters; alphabetical; respects `privacyShowToAttendees` |
| Peer Profiles | **PASS** | `/attendee/event/:eventId/people/:userId` — `GET users/:userId/attendee-profile-card` (+ social links when visible); connection actions; privacy indicators |
| Connections MVP | **PASS** | Send / accept / decline / remove; pending / connected / not connected; mutual & event-scoped (`event_attendee_connections`); no followers |
| Digital Business Card | **PASS** | `/attendee/business-card` — photo, name, company, role, email/phone, social links, QR (vCard), share, save contact |
| Discover People | **PASS** | Suggestions tab — shared interests, same company, same ticket tier, pending incoming; deterministic scoring |
| Community MVP | **PASS** | Community tab reuses celebration wall: short posts + reactions + recent activity (not a full feed) |
| Notifications | **PASS** | `connection_request`, `connection_accepted`, `profile_shared`, `business_card_shared` (+ community kind reserved); inbox at `/attendee/networking-notifications` |
| Technical Quality | **PASS** | Loading skeletons, error/retry, offline banners, pull-to-refresh, responsive EOS layout, 2‑minute provider keepAlive cache |

---

## Routes & entry points

| Route | Screen |
|-------|--------|
| `/attendee/event/:eventId/people` | People Hub (Directory / Discover / Connections / Community) |
| `/attendee/event/:eventId/people/:userId` | Peer profile |
| `/attendee/business-card` | My business card |
| `/attendee/networking-notifications` | Networking notifications |

**Entry points:** Live Event Hub “People”; Event Detail agenda “People & networking”.

---

## Backend

| Change | File |
|--------|------|
| Migration `event_attendee_connections` | `infra/db/053_attendee_networking.sql` |
| Directory, suggestions, connections, business card, notifications | `attendee-networking.service.ts` |
| HTTP routes under Events controller | `events.controller.ts` |
| Peer card social links when visible | `users.service.ts` |

### API surface

- `GET events/:eventId/people`
- `GET events/:eventId/people/suggestions`
- `GET|POST events/:eventId/connections`
- `POST networking/connections/:id/accept|decline`
- `DELETE networking/connections/:id`
- `GET me/business-card`
- `GET me/networking-notifications`
- `POST me/networking-share-notify`

**Deploy note:** apply `053_attendee_networking.sql` before exercising connections in an environment that has not yet run it.

---

## Flutter key files

| Path | Role |
|------|------|
| `networking_api.dart` | HTTP client + models |
| `attendee_networking_providers.dart` | Riverpod providers + cache |
| `attendee_people_hub_screen.dart` | Directory / Discover / Connections / Community |
| `attendee_peer_profile_screen.dart` | Peer profile + connect/share card |
| `attendee_business_card_screen.dart` | QR card, share, save contact |
| `attendee_networking_notifications_screen.dart` | Notifications inbox |
| `attendee_networking_widgets.dart` | Tiles, skeletons, connection actions |
| `celebration_wall_providers.dart` | Reused for Community MVP |

---

## Explicitly not built (future phases)

- Private messaging / group chats  
- Meeting scheduling / calendar sync  
- Voice / video calls  
- Advanced social graph / followers  
- Event-wide chat rooms  
- Organizer networking admin  

---

## Regression

| Area | Status |
|------|--------|
| Auth / Dashboard / Discover / Event Details / Purchase / Passes / Live | Additive routes & CTAs only; no flow rewrites |
| Organizer Event Operations | Untouched |

---

## Known partials (acceptable)

| Item | Note |
|------|------|
| Mutual connections in suggestions | Requires accepted graph walk; MVP uses interests/company/tier/pending |
| Session “recently attended” signal | Not in program attendance API for attendees; deferred |
| Community activity fan-out | Kind supported in inbox; wall posts do not auto-notify all connections |
| Email/phone on peer card | Shown on **own** business card; peer card stays privacy-filtered (no contact dump) |

These do **not** block Phase 8 certification for the scoped attendee networking MVP.

---

## Phase gate

| Phase | Status |
|-------|--------|
| Phase 8 Attendee Networking & Social Experience | **COMPLETE** |
| Phase 9 | **Not started** |

**STOP — do not begin Phase 9.**
