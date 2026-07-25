# PHASE 8 — NETWORKING & SOCIAL EXPERIENCE GAP ANALYSIS

**Date:** 2026-07-25  
**Scope:** Attendee Directory, Profiles, Connections, Messaging, Meetings, Business Cards, Social Interaction, Discover People, Notifications, Technical Quality  
**Surfaces:** Flutter `mobile/`, Nest `services/api/`, DB `infra/db/`  
**Method:** Evidence-only audit — **no code was written or modified**  
**Live QA input:** No dedicated attendee networking / social experience is visible

---

## Executive verdict

Phase 8 (Attendee Networking & Social Experience) is **partially implemented** as **foundational identity/profile primitives only**. There is **no** attendee networking product surface.

Live QA is correct: no directory, connections, DMs, meetings, business cards, or social graph UX under the attendee shell.

| Layer | Reality |
|-------|---------|
| **Attendee networking UX** | **Not implemented** |
| **Own profile + privacy flags** | **Working** (edit + card sheet) |
| **Peer profile card API** | **Backend ready** (privacy-filtered); **no discovery UI** to reach peers |
| **Legacy chat / notifications tables** | Schema exists (booking-bound chat); **no attendee networking module** |
| **Celebration wall** | Organizer social wall (posts/reactions) — **not** attendee networking |
| **Connections / meetings / business cards** | **Not implemented** |

| Is Phase 8…? | Answer |
|--------------|--------|
| Already implemented but hidden | **No** |
| Partially implemented | **Yes** (profile foundations only) |
| Backend only | **No** (only profile-card API; not a networking backend) |
| Frontend only | **No** |
| Not implemented | **Mostly** for the networking product |

**Note:** Docs such as `docs/phase8-compliance-report.md` refer to a **different** Phase 8 (compliance/rate-limiting), not Attendee Networking.

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | Present and wired for the intended attendee networking path |
| **Implemented but Hidden** | Built but not surfaced on the primary attendee flow |
| **Implemented but Not Wired** | Exists in codebase; wrong persona/route/data contract |
| **Backend Complete / Frontend Missing** | API/DB ready; attendee UI missing |
| **Frontend Complete / Backend Missing** | UI exists; no durable backend |
| **Partially Implemented** | Incomplete across layers |
| **Not Implemented** | No meaningful product implementation |

---

## Why Phase 8 is unavailable (Live QA)

| Expected surface | Status | Why unreachable |
|------------------|--------|-----------------|
| Networking / social experience | Absent | No `/attendee/network…` (or equivalent) routes |
| Directory / discover people | Absent | No listing API of event attendees for peers |
| Connections / DMs / meetings | Absent | No modules, tables, or screens |
| Peer profiles in context | Blocked | Peer card API exists but nothing lists people to open |

Closest existing pieces: **self profile edit**, **privacy toggles** (`privacyShowToAttendees`), **peer profile-card GET**, **celebration wall** (organizer), **hub Messages** (organizer/vendor previews), **legacy `chat_*`** (booking threads).

---

## Stack map (shared evidence)

| Area | Evidence |
|------|----------|
| **Attendee profile DB** | `infra/db/050_attendee_workspace_profile.sql` — interests, privacy flags |
| **Attendee profile API** | `identity.controller.ts` `GET/PUT/PATCH me/attendee-profile`; `attendee-profile.service.ts` |
| **Peer profile card** | `GET me/attendee-profile-card`, `GET users/:userId/attendee-profile-card` — `public-profile.controller.ts`, `UsersService.getPublicAttendeeProfile` |
| **Flutter profile** | `attendee_profile_edit_screen.dart`, `attendee_profile_card_sheet.dart`, global hub profile sheet |
| **Organizer guests** | `event_guests` + organizer guest screens — **not** peer directory |
| **Celebration wall** | `event_wall_posts`; organizer FE `customer_event_wall_screen.dart` |
| **Legacy chat** | `chat_threads` (tied to `booking_id`), `chat_participants`, `chat_messages` — **no Nest chat controller found** |
| **Notifications table** | `notifications` in `owanbe_core.sql` — generic inbox schema; not wired to connection/social kinds for attendees |

---

## 8.1 Attendee Directory

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| Attendee Directory | **Not Implemented** | No event-scoped peer directory endpoint or Flutter screen | Organizer guest list is ops-only | **Large** |
| Browse Attendees | **Not Implemented** | — | — | **Large** |
| Search Attendees | **Not Implemented** | — | — | **Medium** (after directory) |
| Filter Attendees | **Not Implemented** | — | — | **Medium** |
| View Profiles | **Partially Implemented** | Peer card API + `AttendeeProfileCardSheet` / `fetchAttendeeProfileCard(userId)` | No directory to discover `userId`s; sheet used for self | **Small** once directory exists |

---

## 8.2 Attendee Profile

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Public Event Profile | **Partially Implemented** | Privacy-filtered peer card (`getPublicAttendeeProfile`); self always visible | Not event-scoped “public at this event” listing; visibility flag only | **Medium** |
| Profile Photo | **Implemented and Working** | Global / identity `avatarUrl`; sheet + hub avatar | Own profile; peer if visible | — |
| Bio | **Implemented and Working** | Global profile `bio` on card | — | — |
| Company | **Implemented and Working** | Global `company` on card / hub edit | — | — |
| Role / Title | **Partially Implemented** | `occupation` on profile card | Field exists; not a networking “title at event” product | **Small** |
| Social Links | **Implemented but Not Wired** (wrong persona for Phase 8) | Organizer/vendor workspace `social_links`; shared `profile_social_links_form.dart` | Not exposed as attendee networking card links in peer directory | **Medium** |
| Interests | **Implemented and Working** | Attendee profile + card interests; used for Discover recommendations | Not used for “people like you” yet | — |
| Privacy Controls | **Implemented and Working** | `privacyShowToOrganizers` / `privacyShowToAttendees` edit UI + DB + card visibility logic | Directory does not yet honor list-building | **Small** to wire into directory query |

---

## 8.3 Connections

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Send Connection Request | **Not Implemented** | No connection tables/APIs/UI | **Large** |
| Accept / Reject | **Not Implemented** | — | **Medium** |
| Remove Connection | **Not Implemented** | — | **Small** (after model) |
| View Connections | **Not Implemented** | — | **Medium** |
| Mutual Connections | **Not Implemented** | — | **Medium** |

---

## 8.4 Private Messaging

| Feature | Classification | Evidence | Why unavailable | Effort |
|---------|----------------|----------|-----------------|--------|
| One-to-One Messaging | **Not Implemented** (attendee) | Legacy `chat_*` is **booking-centric**; no Nest chat module found | Hub Messages are synthetic organizer/vendor previews (`homeMessagePreviewsProvider`) | **Large** |
| Conversation List | **Frontend Complete / Backend Missing** for hub previews only — **Not Implemented** for attendee DMs | `home_messages_tab.dart` | Wrong persona | **Large** |
| Message Notifications | **Not Implemented** | Generic `notifications` table unused for DM kinds | **Medium** |
| Read Status | **Partially** at schema level (`notifications.read_at`); **Not Implemented** for chat | Chat messages lack read receipts | **Medium** |
| Attachments / Media | **Backend Complete / Frontend Missing** (schema only) | `chat_messages.attachments JSONB` | No API/UI | **Medium–Large** |

---

## 8.5 Meeting Requests

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Request / Accept / Decline Meeting | **Not Implemented** | — | **Large** |
| Meeting Schedule / Location | **Not Implemented** | — | **Medium** |
| Calendar Integration | **Not Implemented** | — | **Large** |
| Meeting History | **Not Implemented** | — | **Medium** |

(Negotiation “sessions/messages” are vendor–organizer AI negotiation — **not** attendee meetings.)

---

## 8.6 Digital Business Cards

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| My Business Card | **Partially Implemented** | `AttendeeProfileCardSheet` is a personal card preview (name, avatar, bio, company, interests, privacy) | **Medium** to productize as shareable card |
| QR Business Card | **Not Implemented** | Ticket QR exists (Phase 4–6); not a contact/vCard QR | **Medium** |
| Share / Save / Export Contact | **Not Implemented** | Pass share is ticket text, not contact | **Medium** |

---

## 8.7 Social Interaction

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Activity Feed (social) | **Implemented but Not Wired** | Ops/live `event_feed_items` + Phase 7 attendee live-updates — **event ops/program**, not peer social feed | **Large** for social feed |
| Reactions | **Implemented but Not Wired** | Celebration wall reactions (organizer wall UI + public API) | **Medium** to surface to attendees |
| Comments | **Partially Implemented** | Wall posts are guestbook-style messages — not threaded comments on people | **Medium–Large** |
| Mentions | **Not Implemented** | — | **Large** |
| Follow Attendees | **Not Implemented** | — | **Large** |
| Event Community | **Partially Implemented** | Celebration wall + Live Hub announcements | **Medium** to position as community |

---

## 8.8 Discover People

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Suggested Connections | **Not Implemented** | — | **Large** |
| Similar Interests | **Frontend Complete / Backend Missing** for **events** only | Discover recommendation uses interests for **events**, not people | **Medium** (reuse interest vectors) |
| Same Company / Industry | **Not Implemented** | Company on profile; no peer matching API | **Medium** |
| Recommended People | **Not Implemented** | — | **Large** |

---

## 8.9 Notifications

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Connection Requests / Accepted | **Not Implemented** | — | **Medium** |
| New Messages | **Not Implemented** | Hub “messages” are not DMs | **Medium** |
| Meeting Invitations | **Not Implemented** | — | **Medium** |
| Social Notifications | **Not Implemented** | `notifications` table + email/ticket notify paths exist; no social kinds | **Medium** |

Attendee profile has `notifyEmail` / `notifySms` / `notifyPush` prefs — **channel prefs only**, not social notification product.

---

## 8.10 Technical Quality (for Phase 8 surfaces)

| Concern | Classification | Notes | Effort |
|---------|----------------|-------|--------|
| Loading / Error / Empty | **Partially Implemented** | Present on profile card/edit; N/A for missing networking modules | Small when building |
| Offline Behaviour | **Not Implemented** for networking | Pass/live offline exists elsewhere | Medium |
| Responsive Layout | **Partially Implemented** | Profile sheets follow EOS | Small |
| Performance | **N/A** | No directory/chat load yet | — |

---

## Feature scorecard

| # | Feature area | Dominant classification | Effort to finish |
|---|--------------|-------------------------|------------------|
| 8.1 | Directory | Not Implemented (+ partial view profile) | Large |
| 8.2 | Profile | Partially / Working foundations | Medium |
| 8.3 | Connections | Not Implemented | Large |
| 8.4 | Private Messaging | Not Implemented (legacy schema only) | Large |
| 8.5 | Meetings | Not Implemented | Large |
| 8.6 | Business Cards | Partially Implemented | Medium |
| 8.7 | Social Interaction | Partial / Not Wired | Medium–Large |
| 8.8 | Discover People | Not Implemented | Large |
| 8.9 | Social Notifications | Not Implemented | Medium |
| 8.10 | Technical quality | Partial | Small–Medium |

---

## Key file index

### Flutter (profile foundations — not networking product)

| Path | Role |
|------|------|
| `mobile/lib/portals/attendee/screens/attendee_profile_edit_screen.dart` | Edit interests, privacy, prefs |
| `mobile/lib/portals/attendee/screens/attendee_profile_card_sheet.dart` | Self/peer card sheet |
| `mobile/lib/portals/attendee/models/attendee_profile.dart` | Workspace profile + privacy |
| `mobile/lib/portals/attendee/models/attendee_profile_card.dart` | Privacy-filtered card DTO |
| `mobile/lib/features/home/widgets/home_messages_tab.dart` | Hub message previews (non-DM) |
| `mobile/lib/portals/customer/screens/customer_event_wall_screen.dart` | Celebration wall (organizer) |
| `mobile/lib/portals/customer/screens/customer_event_guests_screen.dart` | Organizer guest list |

### Nest / DB

| Path | Role |
|------|------|
| `services/api/src/modules/users/public-profile.controller.ts` | Peer/self profile card |
| `services/api/src/modules/users/users.service.ts` | `getPublicAttendeeProfile` visibility |
| `services/api/src/modules/identity/attendee-profile.service.ts` | Attendee workspace profile CRUD |
| `infra/db/050_attendee_workspace_profile.sql` | Privacy columns |
| `infra/db/owanbe_core.sql` | `chat_*`, `notifications` |
| `infra/db/029_celebration_wall.sql` | Wall posts/reactions |
| `infra/db/038_event_guests_invitations.sql` | Organizer guests |

### API endpoints (relevant)

| Method | Path | Notes |
|--------|------|-------|
| `GET/PUT/PATCH` | `me/attendee-profile` | Self workspace profile |
| `GET` | `me/attendee-profile-card` | Self card |
| `GET` | `users/:userId/attendee-profile-card` | Peer card (privacy-filtered) |
| `GET/POST` | `events/:eventId/wall…` | Celebration wall (not networking graph) |
| — | No connection / meeting / attendee-directory endpoints | |

---

## Overall determination

**Phase 8 is partially implemented** — specifically profile + privacy foundations and a peer profile-card API — and **not implemented** as an attendee Networking & Social Experience.

It is **not** “already built but hidden,” **not** a complete networking backend, and **not** frontend-only.

---

## Prioritized roadmap — single Phase 8 completion sprint

Compose on existing **profile card + privacy + ticket entitlements / check-ins**. Defer full DM/meetings if capacity is tight.

### P0 — Event People Directory (must ship)

1. **Event-scoped directory** of attendees who opted in (`privacy_show_to_attendees`) and hold entitlement / checked-in for `eventId`  
   - Browse + search + open peer profile card  
   - **Effort: Large** (new list API + Flutter screen under Live Hub or Event)
2. **Wire peer profile** from directory → existing `users/:id/attendee-profile-card` + sheet  
   - **Effort: Small**

### P1 — Business card + connect MVP

3. **Digital business card** from existing card fields + share text / QR payload (contact, not ticket)  
   - **Effort: Medium**
4. **Connection requests** (request / accept / list) — minimal schema  
   - **Effort: Large** (smallest viable social graph)

### P2 — One messaging vertical OR wall community

5. Prefer **attendee-visible celebration wall** (compose existing wall APIs) as “Event Community” **or** thin DM on top of connections  
   - Wall reuse: **Medium**; true DM: **Large**

### P3 — Explicitly defer (Phase 8B)

6. Meeting requests + calendar  
7. Mutual connections / recommendations engine  
8. Mentions / follow graph / rich media chat  
9. Full push social notification center  

### Suggested sprint outcome (COMPLETE definition)

Phase 8 **COMPLETE** when an attendee at a live/ticketed event can:

1. Open **People** for that event and browse opted-in attendees  
2. **Search** and open a **privacy-respecting profile card**  
3. **Share** their digital business card  
4. Send/accept at least one **connection request** **or** participate in **event community** (wall)  

Messaging, meetings, and advanced discovery may remain **PARTIAL / deferred** if called out in the completion report.

---

## Final determination

| Verdict | **Partially implemented** |
|---------|---------------------------|
| Attendee Networking & Social product | **Mostly not implemented** |
| Live QA explanation | Correct — no dedicated networking UI |
| Strongest reuse | Profile card API + privacy flags + interests + wall reactions |
| Next step | Implementation sprint per roadmap above |

**STOP — audit only. No implementation performed.**
