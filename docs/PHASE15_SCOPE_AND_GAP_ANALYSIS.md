# PHASE 15 — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–14 + live code / schema audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no code changes  
**Prerequisite:** Phase 14 Live QA / Certification (or explicit waiver)

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Public ticketed loop closed: create → tickets → publish → discover → purchase → orders/buyers (11–14) |
| **Remaining dual-mode hole** | `PRIVATE_INVITATION` events still cannot complete invite → RSVP deep-link → door-eligible pass |
| **Proposed domain** | Guest Management, Invitations & RSVP — **correct direction**, wrong if framed as greenfield CRM |
| **Natural Phase 15** | Close the **private invitation loop** on existing `038` guests/invites substrate |
| **Not Phase 15** | Full VIP/tags/plus-ones CRM, SMS marketing, Live Ops rebuild, Finance, Vendor CRM |
| **Overall** | **✅ Phase 15 Scope Defined** |

---

## 2. Business flow review — next missing capability

```
Create (12) → Configure (12) → Tickets (13) → Publish (12/14)
    → Discover (14) → Purchase (13/14) → Sales visibility (14)
```

| Access mode | Status after Phase 14 |
|-------------|------------------------|
| **PUBLIC_TICKETED** | Operating loop complete enough to sell and see buyers |
| **PRIVATE_INVITATION** | Guests/invites APIs exist; **guest cannot complete token RSVP in app**; RSVP does **not** create `ticket_entitlements`; Live Ops admits entitlements only |

**Next missing business capability:** make private celebrations operable end-to-end — invite guest → open link → RSVP → appear on organizer list with attendance state → (minimum) be eligible for later check-in via a real pass reference.

This matches Phase 14 roadmap §11 (“Private invitation closure”) and Phase 14 deferred invite→entitlement / RSVP deep-link.

### Alternative progression check

| Candidate | Why not Phase 15 (unless strategy flips) |
|-----------|------------------------------------------|
| **Door / Live Ops** | Strong for *public sold tickets*; entitlements already issued. Better as **Phase 16** after private guests also hold passes |
| **Finance / refunds** | Admin refund queue exists; does not unblock private mode |
| **Vendor CRM** | Parallel marketplace track; unrelated to invite loop |
| **Full Guest CRM** (VIP, tags, approvals, SMS) | Substrate incomplete; expands surface without closing the loop |

**Justification:** Owambe’s core product rule is dual access (`PRIVATE_INVITATION` vs `PUBLIC_TICKETED`). After closing the public sell loop, architecture demands closing the private invite loop before deepening Live Ops or Finance.

---

## 3. Phase 15 definition

### Official Phase Name

**Private Invitation Closure — Guests, RSVP & Invite Access**

*(Working short name: Private Invitation Closure)*

### Business goal

Organizers running **private / invitation** events can invite guests, collect RSVPs via shareable links, see invitation and attendance status, and produce a door-eligible access record — without relying on public Discover ticket sales.

### Technical goal

Wire and complete the existing guests/invitations stack (`038_event_guests_invitations.sql` + services) with:

1. Flutter **RSVP deep-link** (`/events/:id/rsvp?token=`)
2. Correct **invitation link** share URLs (token, not fake `/tickets`)
3. **Invite access model**: confirmed RSVP (or explicit invite pass) writes `ticket_entitlements` and/or `event_guests.entitlement_ref`
4. Organizer guest list + invitation hub **wired to APIs** (not heuristic empty Attendees for private mode)
5. Optional P1: guest PATCH/DELETE routes, bulk import → `POST …/guests/bulk`, email channel from hub

### Primary user journeys

| # | Journey |
|---|---------|
| J1 | Organizer adds guests → sends invitations → copies real RSVP link |
| J2 | Guest opens token link → validates → confirms/declines RSVP (unauthenticated or light auth as API allows) |
| J3 | Organizer sees invitation status + RSVP status update on guest list / invitations hub |
| J4 | Confirmed guest receives / is linked to an entitlement (pass) usable later by Live Ops |
| J5 | Signed-in attendee continues to manage invites via existing `me/guest-invitations` inbox |

### Success criteria

- Token RSVP works end-to-end in Flutter (no 404 route)
- Share/copy URLs include invitation token and land on RSVP UI
- Organizer private Attendees / Guests surfaces show API guests (not only ticket buyers)
- Confirmed invite path sets `entitlement_ref` and/or issues `ticket_entitlements`
- No Marketing / Vendor / Finance / Live Ops rebuild in this phase
- Phase 14 public ticketed regressions pass (Discover, purchase, orders)

### Why this follows Phase 14

Phase 14 explicitly deferred private RSVP UI and invite→entitlement. Public sales visibility is done; private mode is the other half of the product dual-mode architecture. Live Ops (Phase 16) is more valuable when **both** paid buyers and invited guests hold entitlements.

---

## 4. Classification legend

| Label | Meaning |
|-------|---------|
| **Fully Implemented** | End-to-end usable on live path |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 15 completeness |
| **Implemented but Hidden** | Built; not on primary organizer route |
| **Backend Only** | API/DB ready; insufficient UX |
| **Frontend Only** | UI present; API stubbed/absent/unenforced |
| **Not Implemented** | No meaningful product implementation |

---

## 5. Feature breakdown & codebase audit

| Feature | Classification | Evidence |
|---------|----------------|----------|
| **Guest Lists** | **Partially Implemented** | Schema `event_guests` (`038_…sql`); `EventGuestsService` list/create/bulk/patch/remove; controller exposes GET/POST + bulk only — **no PATCH/DELETE routes**; Flutter `CustomerEventGuestsScreen` + `event_guests_api.dart` list/add |
| **RSVP Management** | **Partially Implemented** | `GET invitations/validate`, `POST invitations/rsvp`; attendee `me/guest-invitations`; **no Flutter `/rsvp` route** under `mobile/lib/router/` |
| **Invitations** | **Partially Implemented** | `EventInvitationsService` send + hub; `/events/:id/invitations` UI; FE often sends `channel: 'link'` |
| **Invitation Links** | **Partially Implemented** | Backend builds `/events/:id/rsvp?token=…`; FE share models may point at `/tickets` without token |
| **Invite by Email** | **Partially Implemented** | Backend email when `channel === 'email'` via `NotificationService`; hub UI not consistently selecting email |
| **Invite by Phone** | **Not Implemented** | `phone_e164` stored; `sms`/`whatsapp` enum unused in send path |
| **Guest Import (CSV)** | **Frontend Only** | Attendees CSV button stubs snackbar; `POST …/guests/bulk` unused by CSV |
| **VIP Guests** | **Frontend Only** | Tier-name / filter heuristics; no VIP column on `event_guests` |
| **Plus Ones** | **Not Implemented** | Settings copy / name heuristics only; no plus-one model |
| **Guest Tags** | **Not Implemented** | No tags; `metadata` notes only |
| **Guest Groups** | **Partially Implemented** | DB `group_label`; CC V3 `GuestGroup` often synthetic/heuristic |
| **Manual Registration** | **Not Implemented** | `registrationEnabled` metadata flag only |
| **Approval Workflow** | **Not Implemented** | No guest approval state machine |
| **Check-in Eligibility** | **Partially Implemented** | Live Ops check-in uses `ticket_entitlements`; guests’ `entitlement_ref` never written; private Attendees check-in is local state |
| **Invitation Status** | **Partially Implemented** | `event_invitations` statuses + hub deliveries; open via validate |
| **Attendance Status** | **Partially Implemented** | `rsvp_status` + entitlement `checked_in`; dual models not unified |
| **Reminder Messages** | **Frontend Only** | Planning / workspace reminders — not invitation follow-up sends |
| **Invitation Analytics** | **Partially Implemented** | Backend funnel stats (`getStats`); FE mix of hub API + synthesized guest heuristics |

---

## 6. Existing vs missing implementation

### Existing (reuse — do not rebuild)

| Asset | Path |
|-------|------|
| Schema | `infra/db/038_event_guests_invitations.sql` |
| Guests service | `services/api/src/modules/events/event-guests.service.ts` |
| Invitations service | `services/api/src/modules/events/event-invitations.service.ts` |
| Controller routes | `events.controller.ts` — guests, invitations send/hub, validate, rsvp, `me/guest-invitations` |
| Flutter guests | `customer_event_guests_screen.dart`, `event_guests_api.dart` |
| Flutter invitations hub | `customer_event_invitations_screen.dart` |
| Attendee inbox | `guest_invitations_api.dart`, registrations / tickets tabs |
| Contacts sheet (stubbed prod) | `import_contacts_sheet.dart` |
| Notifications | `NotificationService` (email channel) |
| Entitlements / check-in APIs | `ticket_entitlements`, `event-operations.service.ts` |
| Phase 14 invite-only purchase gate | guest email match on order create |
| Private vs ticketed Attendees split | `attendees_tab_v3.dart` |

### Missing (Phase 15 targets)

| Gap | Priority |
|-----|----------|
| Flutter RSVP deep-link route + UI | **P0** |
| Share/copy uses real token RSVP URL | **P0** |
| Invite → entitlement / `entitlement_ref` on confirm | **P0** |
| Private organizer guest list wired to `GET …/guests` (not heuristics alone) | **P0–P1** |
| Guest PATCH/DELETE HTTP + FE | **P1** |
| CSV / contacts → `guests/bulk` | **P1** |
| Email channel selectable in hub | **P1** |
| SMS / WhatsApp invite | **Out** (later) |
| VIP / tags / plus ones / approval CRM | **Out** |
| Invitation reminder campaigns | **Out** (Marketing-adjacent) |
| Live Ops rebuild | **Out** (Phase 16) |

---

## 7. Reuse analysis

| Layer | Reuse |
|-------|-------|
| **Routes** | Extend `app_router` / portal routes with `/events/:id/rsvp`; keep `/guests`, `/invitations` |
| **Screens** | Invitations hub, guests screen, attendee invite inbox — extend, don’t replace |
| **Widgets** | Import contacts sheet, EOS cards, CC Attendees private branch |
| **Providers** | Guest / invitation APIs; organizer event providers |
| **Controllers** | `EventsController` — add PATCH/DELETE guests if needed; no new commerce OS |
| **Services** | `EventGuestsService`, `EventInvitationsService`; issue entitlements via capture/orders patterns or thin invite-fulfill helper |
| **DTOs** | Existing invitation/guest body shapes |
| **Tables** | `event_guests`, `event_invitations`, `event_invitation_tokens`, `ticket_entitlements` |
| **Business rules** | RSVP enum; invitation status funnel; Phase 14 visibility (private not in Discover) |

**Avoid:** second guest CRM, parallel check-in tables, marketing campaign builder.

---

## 8. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Ticketing / Orders** | Soft — invite pass may mint complimentary entitlement without paid order; invite-only purchase already uses guest email |
| **Attendees (Phase 14)** | Ticketed buyers stay on entitlements; private mode must prefer `event_guests` + issued passes |
| **Notifications** | Email invite delivery reuse |
| **Profiles / users** | Optional link when guest email matches signed-in user (`me/guest-invitations`) |
| **Check-in / Live Ops** | **Downstream consumer** of entitlements — Phase 15 produces eligibility; Phase 16 deepens door UX |
| **Phase 14 certification** | Gate before build |

---

## 9. Risks

| Risk | Mitigation |
|------|------------|
| Scope creeps into full Guest CRM | Hard out-list VIP/tags/SMS/approvals |
| Invite entitlement model ambiguous (comp tier vs invite-only pass) | Decide in sprint kickoff: **recommended default** — on RSVP `confirmed`, issue entitlement with metadata `{ source: 'invitation', guestId }` and set `entitlement_ref`; no paid order required |
| Private Attendees UI vs `/guests` dual surfaces | Prefer wiring existing screens; one source of truth = `event_guests` API |
| Breaking public ticketed Attendees | Keep `isPublicTicketed` branch from Phase 14 |
| Deep-link auth friction | Match backend: token RSVP may be public; don’t force full signup if API allows |

**Architectural decision resolved for naming:** Phase 15 = private invitation **closure**, not CRM expansion.  
**In-sprint product default for access model:** invitation-sourced entitlement (above) — does not require further phase-level redesign.

---

## 10. Implementation effort

| Module | Effort | Notes |
|--------|--------|-------|
| RSVP deep-link route + UI | **Medium** | Validate + RSVP APIs exist |
| Fix invitation share URLs | **Small** | Backend already builds correct pattern |
| Invite → entitlement on confirm | **Medium** | Reuse entitlement insert patterns; set `entitlement_ref` |
| Wire private guest list to API | **Medium** | Guests screen exists; Attendees private branch |
| Guest PATCH/DELETE API + FE | **Small–Medium** | Service methods exist |
| Bulk CSV → `guests/bulk` | **Medium** | Bulk API exists; CSV UI stub |
| Email channel in hub | **Small** | Backend path exists |
| SMS / VIP / tags / plus ones / reminders / approvals | **Large** if forced | **Defer** |
| **Sprint total (scoped)** | **Medium** (~1 week focused) | P0 + selective P1 |

**S** = days · **M** ≈ 1 week · **L** = multi-week

---

## 11. Completion sprint roadmap

### Single sprint goal

**Private invitation events: invite → token RSVP → status visible to organizer → door-eligible entitlement — without building Guest CRM or Live Ops.**

### P0 (must ship)

1. Flutter route `/events/:id/rsvp` reading `token` query → validate → confirm/decline.  
2. Invitation hub share/copy uses backend token RSVP URL.  
3. On RSVP `confirmed`, issue invite-sourced `ticket_entitlement` + set `event_guests.entitlement_ref`.  
4. Organizer can see updated RSVP / invitation status (hub and/or guests list from API).  
5. Regression: Phase 14 public Discover/purchase/orders; private events stay out of Discover.

### P1 (should ship)

6. Expose guest PATCH/DELETE on controller + FE edit/remove.  
7. CSV (and/or enabled contacts) → `POST …/guests/bulk`.  
8. Hub channel control: `link` vs `email`.  
9. Private Attendees tab loads `GET …/guests` instead of empty/heuristic-only list.  
10. Empty / loading / error polish on RSVP + guests.

### P2 (defer if timeboxed)

11. Wire `group_label` editing in UI (not synthetic groups).  
12. Basic invitation funnel display from hub `getStats` only (no campaign analytics).  
13. Decline path messaging / re-invite.

### Explicitly out of sprint

- VIP, tags, plus ones, approval workflows  
- Invite by SMS / WhatsApp  
- Reminder message campaigns  
- Live Ops / check-in center rebuild  
- Marketing, Finance settlement, Vendor CRM  
- Manual public registration product

---

## 12. Roadmap hint (non-binding)

| Phase | Theme |
|-------|--------|
| **15** | Private Invitation Closure (this doc) |
| **16** | Door / Live Ops (check-in against entitlements — paid + invite) |
| **17** | Organizer finance & refunds productization |
| **18** | Vendor marketplace CRM |
| **19** | Marketing / communications campaigns |
| **20** | Analytics depth |

Guest CRM extras (VIP, plus ones, SMS) can attach to 15 P2, 19, or a later “Guest CRM” slice — not redefine 15.

---

## 13. Dependencies & stop conditions

| Gate | Status |
|------|--------|
| Phase 14 implementation | Complete (completion report) |
| Phase 14 Live QA / Certification | **Pending** — do not start Phase 15 build until certified (or waived) |
| Phase 15 scope doc | **This document** |
| Phase 15 implementation | **Not started** |

**STOP:** Do not begin Phase 15 coding, Phase 16, or Marketing/Finance/Vendor delivery from this doc alone.

---

## 14. Final classification

### ✅ Phase 15 Scope Defined

**Phase 15 = Private Invitation Closure — Guests, RSVP & Invite Access**

Validates the proposed “Guest Management, Invitations & RSVP” domain as the correct **next Organizer capability**, scoped as **loop closure on existing substrate** — not a greenfield guest CRM. Natural successor to Phase 14’s public ticketed loop; prepares entitlements for Phase 16 Live Ops.
