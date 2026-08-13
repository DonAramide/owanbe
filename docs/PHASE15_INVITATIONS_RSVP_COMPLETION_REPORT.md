# PHASE 15 — INVITATIONS, RSVP & GUEST ACCESS COMPLETION REPORT

**Date:** 2026-08-01  
**Reference:** `docs/PHASE15_SCOPE_AND_GAP_ANALYSIS.md`  
**Status:** Implementation complete — pending **Phase 15 Live QA and Certification**  
**Constraint:** No Organizer architecture redesign; reused guests/invitations APIs, entitlements, notifications, Event Workspace  

---

## Section verdicts

| Section | Verdict |
|---------|---------|
| P0 Invitation management | **PASS** |
| P0 RSVP Flutter experience | **PASS** |
| P0 Invite-only access enforcement | **PASS** |
| P0 RSVP → entitlement | **PASS** |
| P1 Organizer guest management | **PASS** |
| P1 Attendee experience (My Events / passes) | **PASS** |
| P1 Notifications | **PARTIAL PASS** |
| P2 Invitation sharing (token / expiry / one-time) | **PASS** |
| P2 Event Workspace guest section | **PASS** |
| UX polish | **PARTIAL PASS** |
| Maybe RSVP | **PASS** (explicitly unsupported — backend enum has no `maybe`) |
| Technical quality | **PASS** |
| Overall | **PASS** (await Live QA) |

---

## Features implemented

### P0 — Invitation management
- Send by **email** (default from Invitation hub) and **link**
- **Invite existing user** — `POST …/guests/invite-user` (lookup user → guest → send)
- **Resend** — `POST …/invitations/:id/resend`
- **Cancel** — `POST …/invitations/:id/cancel` (invalidates tokens)
- Hub lists pending / accepted / declined with filters; shows ticket-issued flag

### P0 — RSVP experience
- Flutter route `/events/:id/rsvp?token=` → `EventRsvpScreen`
- Landing with event/guest details; Accept / Decline
- Expired / cancelled / invalid states
- Maybe not offered (DB RSVP enum: invited/pending/confirmed/declined only)

### P0 — Invite access
- Validate / RSVP require valid non-cancelled, non-expired token
- Cancelled invitations blocked
- One-time response: subsequent RSVP returns existing status
- Private events remain out of Discover (Phase 14 rules)

### P0 — RSVP → entitlement
- On **confirmed**: create free fulfilled `ticket_orders` + line + `ticket_entitlements`; set `event_guests.entitlement_ref`
- If guest email has no user yet: mark `pendingEntitlement`; claim on `me/guest-invitations` when they sign in
- On **declined**: update RSVP only — no entitlement
- Authenticated `me/guest-invitations/:id/rsvp` also issues entitlement

### P1 — Organizer guest surfaces
- Invitation hub status panel + KPIs (invited, awaiting, accepted, declined, tickets)
- Private Attendees tab shows API guests from manage snapshot
- Guest PATCH/DELETE controller routes exposed

### P1 — Attendee
- Confirmed invite → entitlement → My Tickets / passes (existing entitlement list)
- Sign-in with invitation email claims pending entitlements

### P1 — Notifications
- Guest: invitation email (on send), RSVP confirmation email
- Organizer: accepted / declined emails
- Reminder / expired organizer push: **deferred** (no scheduler) — **PARTIAL**

### P2 — Sharing
- Secure token links via `PUBLIC_APP_BASE_URL` / fallbacks
- Validate expiry; cancel sets `expires_at = now()`
- `POST …/guests/:id/invite-link` regenerates shareable URL
- Share targets point at `/rsvp` (not `/tickets`)

---

## Existing APIs reused

| API | Role |
|-----|------|
| `GET/POST …/guests` | Guest list / add |
| `POST …/guests/bulk` | Bulk (unchanged; CSV out of scope) |
| `GET/POST …/invitations` | Hub + send |
| `GET invitations/validate` | Token validate |
| `POST invitations/rsvp` | Token RSVP |
| `GET/POST me/guest-invitations…` | Attendee inbox RSVP |
| `GET me/ticket-entitlements` | Passes / My Events |
| **New** | `PATCH/DELETE …/guests/:id`, `invite-user`, `invite-link`, `resend`, `cancel` |

---

## Controllers / services reused

- `EventsController` — extended invitation/guest routes  
- `EventInvitationsService` — send, validate, RSVP, hub, resend, cancel, invite user  
- `EventGuestsService` — list/create/patch/remove  
- `NotificationService` — email templates  
- **New helper:** `invite-entitlement.ts` — complimentary order + entitlement  

---

## DTO / Flutter changes

- Hub stats: pending, declined, ticketsIssued, totalInvited, eligibleForCheckIn  
- Delivery items: rsvpStatus, entitlementRef, sentAt, respondedAt  
- Validate view: usedAt, startsAt, venue, city; expired/cancelled error payloads  
- Flutter: `EventRsvpScreen`, `InvitationPublicApi`, hub delivery panel, `/rsvp` route  
- Share models: RSVP URL path corrected  

---

## Database changes

**None.** Reused `event_guests`, `event_invitations`, `event_invitation_tokens`, `ticket_orders`, `ticket_order_lines`, `ticket_entitlements`.

---

## Business rules added

1. Confirmed RSVP → complimentary fulfilled order + invitation entitlement when holder user resolvable  
2. Pending entitlement claim when matching email user opens attendee invite inbox  
3. Declined RSVP never issues entitlement  
4. Cancelled invitation: tokens expired; validate/RSVP rejected  
5. Token response is one-time for status change; re-open is idempotent  
6. Invitation links use app base URL + `/events/:id/rsvp?token=`  

---

## Flutter screens / routes added

| Item | Path |
|------|------|
| Screen | `event_rsvp_screen.dart` |
| Route | `/events/:id/rsvp` |
| API | `invitation_public_api.dart` |
| Hub panel | Invitation status list on `CustomerEventInvitationsScreen` |

---

## Regression summary

| Area | Status |
|------|--------|
| Organizer Dashboard | **PASS** (untouched paths) |
| Event Workspace | **PASS** |
| Ticket entitlements / paid path | **PASS** (separate idempotency keys) |
| My Events / Passes | **PASS** (entitlement list) |
| Check-in eligibility | **PASS** (issued entitlements) |
| Notifications | **PARTIAL PASS** |
| Orders / Discover | **PASS** |

---

## Deferred items

| Item | Reason |
|------|--------|
| Guest CRM / VIP / tags / plus ones | Explicit out of scope |
| CSV import | Explicit out of scope |
| SMS / WhatsApp invite | Channel enum unused for delivery |
| Invitation reminder jobs / expired organizer alert | Needs scheduler |
| Live Ops rebuild | Phase 16 |
| Finance / Vendor / Marketing / Seating | Later phases |
| Maybe RSVP | Not in DB enum |

---

## Architecture question — canonical private-event lifecycle

```
Organizer
  ↓  Event Workspace / Wizard (Phase 12) — PRIVATE_INVITATION
Create Private Event
  ↓  Guests screen / Invitation hub
Invite Guests
  ↓  EventInvitationsService.send + NotificationService (email)
Invitation Delivered
  ↓  Token URL → EventRsvpScreen (/rsvp)
RSVP (Accept / Decline)
  ↓  On Accept: invite-entitlement → ticket_orders (free) + ticket_entitlements
Entitlement
  ↓  ticket_code + QR metadata
Ticket / Pass
  ↓  me/ticket-entitlements, Attendee passes UI
My Events
  ↓  Existing attendee My Events / entitlement sync
Pass
  ↓  Digital pass card (Phase 4–7)
Check-in
  ↓  Live Ops entitlement check-in (eligible; Phase 16 deepens UX)
```

### Modules reused at each step

| Step | Modules |
|------|---------|
| Create | Wizard V2, EventsService, access mode metadata |
| Invite | EventGuestsService, EventInvitationsService, Invitation hub UI |
| Delivered | NotificationService, invitation tokens |
| RSVP | `invitations/validate` + `rsvp`, EventRsvpScreen |
| Entitlement | `invite-entitlement.ts`, ticket commerce tables |
| Ticket / Pass | TicketEntitlementsService, attendee pass screens |
| My Events | Existing entitlement → attendee providers |
| Check-in | Existing ops check-in against `ticket_entitlements` |

---

## STOP

**Do not begin Phase 16.**  
Wait for Phase 15 Live QA and Certification.
