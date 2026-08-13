# PHASE 16 — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–15 + live code / schema audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no code changes  
**Prerequisite:** Phase 15 Live QA / Certification (or explicit waiver)

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Public sell loop (11–14) + private invite → entitlement (15) both produce `ticket_entitlements` with `status=issued` |
| **Critical-path hole** | Door admission is incomplete: QR is stubby, counters partial, local Attendees check-in bypasses API, SSE unused |
| **Proposed domain** | Live Event Operations — **correct next phase** |
| **Natural Phase 16** | Close the **door loop**: admit issued entitlements (paid + invitation) via trustworthy Live Ops UX |
| **Not Phase 16** | Walk-in CRM, multi-gate product, staff rostering, emergency broadcast suite, Finance, Vendor CRM |
| **Overall** | **✅ Phase 16 Scope Defined** |

---

## 2. Business flow review — next missing capability

```
Create (12) → Configure (12) → Tickets (13) → Publish (14)
    → Sales (14) → Guests / RSVP (15) → Entitlement issued
    → ??? Door / check-in
```

| Access mode | Pass source after Phase 15 | Door ready? |
|-------------|----------------------------|-------------|
| **PUBLIC_TICKETED** | Paid / free ticket entitlements | API exists; UX incomplete |
| **PRIVATE_INVITATION** | Invite-sourced entitlements (`invite-entitlement.ts`) | Same entitlement path; not certified at door |

**Next missing operational capability:** admit holders of issued entitlements at the event — real check-in, live attendance counters, activity feed freshness — without inventing a parallel guest/door CRM.

### Alternative progression check

| Candidate | Why not Phase 16 (unless strategy flips) |
|-----------|------------------------------------------|
| **Finance / refunds** | Does not consume new invite entitlements; roadmap Phase **17** |
| **Vendor CRM** | Marketplace track; not day-of admission; roadmap Phase **18** |
| **Marketing / broadcasts suite** | Announcement substrate is thin; not the dual-mode door loop |
| **Full ops CRM** (gates, staff, walk-ins, agenda) | Expands surface without closing entitlement → check-in |

**Justification:** Phases 13–15 issued the passes. Architecture and Phase 14/15 roadmaps already name Phase 16 as **Door / Live Ops**. Finance and Vendor do not unblock door day.

---

## 3. Phase 16 definition

### Official Phase Name

**Door / Live Event Operations**

*(Working short name: Live Door Ops)*

### Business goal

On event day, organizers and door staff can **reliably check in** guests and ticket holders (public paid and private invitation), see **live attendance**, and monitor a **live activity feed** — using one entitlement-based path.

### Technical goal

Harden existing Live Ops substrate (`OperationsShell`, Event Day routes, `event-operations.service`, `event_check_ins`, feed/incidents) so that:

1. Check-in **always** goes through `ticket_entitlements` API (paid + invitation)
2. QR / code entry resolves real ticket codes / QR payloads
3. Live counters reflect issued vs checked-in (and capacity honesty where data exists)
4. Feed is fresh (SSE consumer or short polling); incident status updates work end-to-end
5. Local-only Attendees check-in bypass is removed or redirected to API

### Primary user journeys

| # | Journey |
|---|---------|
| J1 | Organizer opens Live Ops / Event Day → Check-in center → admits issued entitlement |
| J2 | Door staff scans QR (or enters ticket code) → success / already checked-in / invalid |
| J3 | Dashboard shows checked-in count, remaining, rate, health |
| J4 | Feed shows check-in activity (and incidents) in near-real-time |
| J5 | Invitation pass (`INV-…` / invite entitlement) and paid pass use the **same** door path |

### Success criteria

- Paid and invitation entitlements check in via API and appear in `event_check_ins`
- Duplicate check-in and invalid code states are clear
- Live Ops KPIs match entitlement truth (not mock-only)
- No walk-in sales / staff CRM / multi-gate product in this phase
- Phase 14–15 regressions: Discover, purchase, RSVP → entitlement still work

### Why this follows Phase 15

Phase 15 made private guests **check-in eligible** via entitlements. Public buyers already held entitlements. The product loop after “pass issued” is **admit at the door**. Live Ops rebuild was explicitly deferred through Phases 11–15.

---

## 4. Classification legend

| Label | Meaning |
|-------|---------|
| **Fully Implemented** | End-to-end usable on live path |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 16 completeness |
| **Implemented but Hidden** | Built; not on primary Live Ops route |
| **Backend Only** | API/DB ready; insufficient UX |
| **Frontend Only** | UI present; API stubbed/absent/unenforced |
| **Not Implemented** | No meaningful product implementation |

---

## 5. Feature breakdown & codebase audit

| Feature | Classification | Evidence |
|---------|----------------|----------|
| **Live Operations Dashboard** | **Partially Implemented** | `OperationsDashboardScreen` + `OperationsShell`; some KPIs zeroed on API-only path (`operations_providers.dart`) |
| **Real-time Check-ins** | **Partially Implemented** | `EventOperationsService.checkIn` → entitlement `checked_in` + `event_check_ins`; Flutter polls; QR UI is text/demo stub; Attendees local `_checkIn` bypasses API |
| **Gate Monitoring** | **Not Implemented** | Mock incident copy only (`operations_store.dart`) |
| **Attendance Counters** | **Partially Implemented** | Derived from check-in list KPIs; not always entitlement-complete |
| **Capacity Monitoring** | **Frontend Only** (adjacent) | Tier capacity on Tickets; Live Ops health does not track venue/tier fill vs capacity |
| **Walk-in Registration** | **Not Implemented** | Models hardcode `walkIns: 0`; no register API |
| **Walk-in Ticket Sales** | **Not Implemented** | No walk-in commerce path in ops |
| **Session Monitoring** | **Implemented but Hidden** | Program/day widgets exist; not in OperationsShell modules |
| **Agenda Progress** | **Implemented but Hidden** | Program / attendee live hub; not organizer Live Ops panel |
| **Announcements** | **Backend Only** | Attendee `live-updates` filters announcements; organizer “Broadcast” opens Wall, not ops feed insert |
| **Emergency Broadcasts** | **Backend Only** | Feed types include `emergency`/`alert`; no organizer compose API in ops |
| **Live Notifications** | **Partially Implemented** | SSE `GET …/feed/stream` publishes on check-in; Flutter does not subscribe |
| **Staff Operations** | **Not Implemented** | Stub navigation / hardcoded contacts; no staff roster APIs |
| **Door Management** | **Not Implemented** | No gates/doors entities; free-text `source` only |
| **Operational Timeline** | **Partially Implemented** | `event_feed_items` + `LiveEventFeedScreen` (HTTP poll) |
| **Live Activity Feed** | **Partially Implemented** | Same feed; SSE backend-only |
| **Event Health Indicators** | **Partially Implemented** | Client-computed from check-in rate + incidents |

---

## 6. Existing vs missing implementation

### Existing (reuse — do not rebuild)

| Asset | Path |
|-------|------|
| Schema | `infra/db/022_phase54_persistence.sql` — `event_check_ins`, `event_incidents`, `event_feed_items` |
| Ops service | `services/api/src/modules/events/event-operations.service.ts` |
| Check-in HTTP | `GET/POST events/:eventId/check-ins` |
| Feed / incidents | Feed list + incident APIs; SSE stream |
| Flutter ops API | `mobile/lib/core/api/operations_api.dart` |
| OperationsShell | Dashboard, Check-In, Scan, Feed, Vendors, Incidents, Command, Health |
| Event Day routes | `/events/:id/day`, `…/check-in`, `…/scan`, `…/feed`, `…/incidents` |
| CC Operations tab | `operations_tab_v3.dart` → jump to Live Ops |
| Entitlements | Paid capture + Phase 15 invite entitlements (same `issued` status) |
| Organizer rail | Live Ops tab → `OperationsShell` |

### Missing (Phase 16 targets)

| Gap | Priority |
|-----|----------|
| Real QR / reliable code → `ticket_code` or QR payload | **P0** |
| Remove / redirect Attendees local check-in to API | **P0** |
| Honest live counters (issued / checked-in / remaining) | **P0** |
| Feed SSE consumer or short poll | **P0–P1** |
| Incident status PATCH end-to-end (if FE already calls it) | **P1** |
| Capacity vs issued (optional honesty) | **P1** |
| Smoke paid + invite entitlements at door | **P0** |
| Walk-in sales/registration | **Out** |
| Multi-gate / staff roster / emergency composer | **Out** |
| Vendor floor monitor productization | **Out** |

---

## 7. Reuse analysis

| Layer | Reuse |
|-------|-------|
| **Routes** | `/organizer` Live Ops tab; `/events/:id/day/*` — extend, don’t fork |
| **Screens** | `CheckInCenterScreen`, `QrScanScreen`, `LiveEventFeedScreen`, `IncidentCenterScreen`, `OperationsDashboardScreen`, `EventHealthScreen` |
| **Widgets / providers** | `operations_providers.dart`, ops models, CC Operations tab |
| **Controllers** | `EventsController` ops endpoints |
| **Services** | `EventOperationsService`, entitlement rows from commerce / Phase 15 |
| **Tables** | `ticket_entitlements`, `event_check_ins`, `event_feed_items`, `event_incidents` |
| **Business rules** | Only `issued` → `checked_in`; unique check-in per ticket code; feed append on check-in |

**Avoid:** second check-in table, guest-only door path, walk-in OS, staff CRM, broadcast marketing tool.

---

## 8. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Ticket Entitlements** | **Hard** — door admits `issued` entitlements only |
| **RSVP / Guest Management (15)** | Supplies invitation entitlements; same door path |
| **Notifications** | Soft — optional check-in confirm / staff alerts later |
| **Organizer Dashboard** | Soft — Live Ops entry + health jump |
| **Vendor Operations** | Parallel; Live Ops vendor panel is mock — do not productize in 16 |
| **Attendee Check-in** | Must converge on organizer ops API |
| **Live Hub (attendee)** | Consumes feed/announcements; organizer compose deferred |
| **Analytics** | Soft — reuse check-in counts; no time-series rebuild |

---

## 9. Risks

| Risk | Mitigation |
|------|------------|
| Scope creeps into gates/staff/walk-in CRM | Hard out-list in sprint plan |
| Dual check-in paths (local vs API) confuse QA | Single API path; remove local bypass |
| QR camera / platform friction | Ship reliable code entry + best-effort camera; document platform limits |
| SSE only in-process (multi-instance) | Prefer short poll if multi-node; document SSE limitation |
| Capacity definition ambiguous (venue vs tier sum) | P1: use issued entitlements vs checked-in; optional tier remaining |

**Architectural decision resolved for naming:** Phase 16 = **door-loop closure on entitlements**, not full Live Ops CRM.  
No further phase-level decisions block scope.

---

## 10. Implementation effort

| Module | Effort | Notes |
|--------|--------|-------|
| Unify check-in on entitlements API | **Small–Medium** | Service exists |
| QR / code entry hardening | **Medium** | Replace demo stub |
| Live counters + health honesty | **Small–Medium** | Providers + dashboard |
| Feed freshness (SSE or poll) | **Medium** | Backend stream exists |
| Incident status PATCH closure | **Small** | If controller gap confirmed |
| Capacity vs issued (optional) | **Small** | |
| Walk-in / gates / staff / broadcasts | **Large** if forced | **Defer** |
| **Sprint total (scoped)** | **Medium** (~1 week focused) | P0 + selective P1 |

**S** = days · **M** ≈ 1 week · **L** = multi-week

---

## 11. Completion sprint roadmap

### Single sprint goal

**Issued entitlements (paid + invitation) can be checked in at the door with trustworthy Live Ops counters and feed — without building ops CRM.**

### P0 (must ship)

1. Single check-in path via `POST …/check-ins` against `ticket_entitlements` (ticket code / entitlement id / QR payload).  
2. Replace Attendees local-only check-in with API (or remove action).  
3. Harden Check-In + Scan UX: success, already checked-in, invalid, not issued.  
4. Live counters: issued / checked-in / remaining (or rate) from real data.  
5. Regression smoke: paid entitlement + invitation entitlement both admit.  
6. Feed updates after check-in visible in Live Ops (poll or SSE).

### P1 (should ship)

7. Consume `feed/stream` SSE **or** documented short poll interval.  
8. Incident status update end-to-end if FE already expects PATCH.  
9. Capacity honesty: checked-in vs issued (optional vs tier remaining).  
10. Empty / loading / error polish on Check-In, Scan, Dashboard, Feed.

### P2 (defer if timeboxed)

11. Source tagging on check-in (`source`: door / scan / manual) for feed clarity.  
12. Command Center Operations deep-link polish to Event Day check-in.  
13. Health screen copy aligned to entitlement truth.

### Explicitly out of sprint

- Walk-in registration / walk-in ticket sales  
- Multi-gate door management / gate monitoring product  
- Staff rostering / door staff roles  
- Emergency broadcast / announcement composer  
- Session / agenda progress inside Live Ops  
- Vendor floor monitor productization  
- Finance settlement, Marketing, Vendor CRM  

---

## 12. Roadmap hint (non-binding)

| Phase | Theme |
|-------|--------|
| **15** | Private Invitation Closure (done / pending cert) |
| **16** | Door / Live Event Operations (this doc) |
| **17** | Organizer finance & refunds productization |
| **18** | Vendor marketplace CRM |
| **19** | Marketing / communications campaigns |
| **20** | Analytics depth |

Walk-in / multi-gate / staff can attach to a later “Ops CRM” slice — not redefine 16.

---

## 13. Dependencies & stop conditions

| Gate | Status |
|------|--------|
| Phase 15 implementation | Complete (completion report) |
| Phase 15 Live QA / Certification | **Pending** — do not start Phase 16 build until certified (or waived) |
| Phase 16 scope doc | **This document** |
| Phase 16 implementation | **Not started** |

**STOP:** Do not begin Phase 16 coding, Phase 17, or Marketing/Finance/Vendor delivery from this doc alone.

---

## 14. Final classification

### ✅ Phase 16 Scope Defined

**Phase 16 = Door / Live Event Operations**

Validates the proposed Live Event Operations domain as the correct **next Organizer capability**, scoped as **entitlement door-loop closure** on existing Live Ops substrate — not a greenfield gates/staff/walk-in CRM. Natural successor to Phase 15’s invite entitlements and Phases 13–14 paid passes.
