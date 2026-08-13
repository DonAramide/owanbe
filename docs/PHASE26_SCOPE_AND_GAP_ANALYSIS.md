# PHASE 26 — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-02  
**Method:** Architecture-derived (Phases 1–25 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **1–25** architecture-complete — Phase 26 may **consume** only; must not redesign frozen domains  
**Evolution layer:** Phases **26–30** are the next platform evolution — each must have a clear platform-level objective  
**Prerequisite gate:** Phase 25 Completion Review **and** Integrated Live QA Planning / certification progress (Business Ops 19–25) before implementation starts

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Core platform + Business Operations + Hardening complete; Marketing product never shipped |
| **Proposed domain** | Organizer Marketing & Growth — **correct next evolution capability** |
| **Why not AI / Dev portal / queues first** | Evidence shows grow-loop gap is larger and has richer substrate; AI/SDK/Bull deferred by prior scopes |
| **Natural Phase 26** | Ship the **deferred Phase 20** product as Phase 26 — catch up the missing **grow** loop after **operate + harden** |
| **IA** | Organizer Marketing surface (shell tab and/or Event Workspace module) consuming guests, buyers, NotificationService, Analytics, Discover, ticket apply path |
| **Overall** | **✅ Phase 26 Scope Defined** |

Phase 20 was scoped then skipped while Phases 21–25 built Reporting → Org → Automation → Integrations → Hardening. Reports and Automation still treat Marketing as **Unavailable**. After hardening, the highest-value evolution step is to **close the grow loop** without inventing parallel CRM/analytics.

---

## 2. Platform state — what naturally follows

```
Attendee Platform
        ↓
Organizer Platform (create → sell → invite → door → finance → analytics → CRM)
        ↓
Business Operations (reports → org → automation → integrations)
        ↓
Production Hardening (Phase 25)
        ↓
??? Grow demand using audiences already owned
```

| Layer | Status after Phase 25 |
|-------|----------------------|
| Attendee / Organizer core | Architecture-complete — consume |
| Vendor CRM | Implemented — consume |
| Marketing & Growth | **Scope-only (Phase 20) — Not Implemented** |
| Reporting / Org / Automation / Integrations | Implemented — consume |
| Hardening | Implemented — consume; Live QA pending |

**Next missing platform capability:** Organizer-facing **Marketing & Growth** — reach past guests/buyers, run campaigns via existing notification rails, offer promotions on the existing ticket path, and read conversion from Analytics/Orders.

---

## 3. Why Phase 26 follows Phase 25

1. **Operate → Harden → Grow** is the coherent sequence. Hardening made notification delivery, org capabilities, and observability trustworthy enough to send campaigns without silent failures.  
2. **Deferred debt is explicit:** Phase 20 never productized; Phases 21–25 marked Marketing Unavailable rather than inventing packs/actions.  
3. **Substrate is ready:** guests, buyers, `NotificationService` (queued/retry/DLQ), Email infrastructure, Analytics monetary truth, Discover listing, Automation hooks that can later trigger marketing actions.  
4. **Does not redesign 1–25:** additive campaigns/audiences/promos consuming canonical data owners.  
5. **Evolution, not accumulation:** one platform objective — **demand growth** — not a grab-bag of enterprise/AI features.

### Prerequisite (not Phase 26 work)

Integrated Live QA for Phases 19–25 should proceed under **Live QA Planning** (checklist + script already prepared). Phase 26 **implementation** should not start until that gate is acknowledged. This document defines scope only.

---

## 4. Phase definition

### Official Phase Name

**Phase 26 — Organizer Marketing & Growth**

*(Continues / supersedes the unimplemented Phase 20 product scope under the 26–30 evolution numbering.)*

### Business Goal

Give organizers a trustworthy way to **reach audiences**, **run campaigns**, **offer promotions**, and **see conversion into tickets/RSVPs** — using existing guests, buyers, notifications, Discover, Finance, and Analytics — without inventing parallel audience or conversion systems.

### Technical Goal

Productize growth as a **consumer layer**:

1. **Audience** read models over guests + ticket buyers (optional Discover followers if present) — no second CRM of truth  
2. **Campaign** records that dispatch via existing `NotificationService` / email infrastructure  
3. **Promo codes / referral links** on the Ticket Commerce apply path without redesigning order lifecycle  
4. Delivery honesty from `notification_deliveries`; conversion attribution via Analytics/Orders **read-only**  
5. Thin Organizer Marketing IA + deep-links into Analytics, Discover, Invitations  
6. Unlock Marketing report packs and Automation marketing actions that were blocked as Unavailable  

### Primary Users

| User | Need |
|------|------|
| Organizer Owner / Admin / Manager | Grow ticket sales and RSVPs |
| Staff | Typically no campaign send (capability gate — extend org matrix carefully) |
| Attendee / Guest / Buyer | Receive campaigns; redeem promos — no new identity system |
| Super-admin | Platform email readiness only — not organizer campaign UI |

### Primary Journeys

| ID | Journey |
|----|---------|
| J1 | Build audience from guests + buyers → send email campaign → see delivery status |
| J2 | Create promo code → apply at checkout → order reflects discount → Analytics/Finance still truthful |
| J3 | View campaign → conversion panel (tickets sold / RSVPs attributed read-only) |
| J4 | Deep-link Marketing → Analytics / Invitations / Discover |
| J5 | Report pack “Marketing” becomes Available (or remains Unavailable with honest reason until P0 ships) |
| J6 | Capability deny for roles without marketing permission |

### Success Criteria

- [ ] No parallel guest/buyer/CRM store  
- [ ] Campaigns send only through `NotificationService` / EmailService  
- [ ] Promo apply does not invent ledger/finance rules — commerce + Finance remain owners  
- [ ] Conversion metrics read Analytics/Orders — no synthetic vanity metrics  
- [ ] Super-admin Communication Center mocks are **not** promoted as organizer Marketing truth  
- [ ] Frozen domains consume-only  
- [ ] Org capability overlay extended (e.g. `marketing.manage`) — no RBAC redesign  
- [ ] Phase 20 Unavailable markers removed only where product exists  

---

## 5. Strategic audit (Step 1) — missing capabilities map

| Area | Gap vs Phase 26? | Verdict |
|------|------------------|---------|
| User experience (organizer grow) | No Marketing surface | **In Phase 26** |
| Enterprise readiness | Org/capabilities/hardening done; enterprise MDM/governance still mock | Later (27+) |
| Scalability | In-process jobs; Bull deferred | Only if Live QA fails — not Phase 26 objective |
| Intelligence / AI | Mock copilots; no LLM | Deferred — needs campaign substrate first |
| Marketplace growth | Ratings/featured weak; hire loop closed | Runner-up later |
| Platform ecosystem / developer APIs | `platform_api_keys` unused; no SDK | Later |
| Administration | Launch Ops real; MDM/governance mock | Later |
| Security / compliance depth | Phase 8 baseline exists | Later polish |
| Automation expansion | Marketing actions blocked | Unblocked **by** Phase 26, not replaced by it |

---

## 6. Codebase audit (Step 3)

| Capability | Classification | Evidence |
|------------|----------------|----------|
| Organizer Marketing product | **Not Implemented** | No Marketing module/nav; Phase 20 scope only |
| Reports Marketing packs | **Backend Only / Unavailable** | `organizer-reports.service.ts` Unavailable reason |
| Automation marketing suite | **Not Implemented** (deferred) | Phase 23 deferred list |
| Notification / email send | **Fully Implemented** | `NotificationService`, Enterprise Email |
| Guests / buyers audiences | **Fully Implemented** (data) | Invitations, ticket orders/entitlements |
| Analytics conversion reads | **Fully Implemented** | Organizer Analytics (Finance-aligned money) |
| Discover listing | **Fully Implemented** (organic) | Attendee Discover — consume for promo/visibility |
| Promo codes in commerce | **Not Implemented** (schema absent per Phase 20) | Ticket apply path exists — extend carefully |
| Super-admin Communication Center | **Frontend Only / mock** | Must not become organizer truth |
| Platform Copilot / MDM / Governance | **Mock** | Not Phase 26 |
| Outbound webhooks / integrations | **Fully Implemented** | Optional campaign webhooks later — consume |
| Developer API keys / SDK | **Not Implemented** | Schema stub `043` unused |
| Compliance export/retention | **Partially Implemented** | Phase 8 admin — not Marketing |
| Job queues (Bull/Redis) | **Not Implemented** (deferred) | In-process sweepers |

### Reusable systems (must consume)

- `NotificationService` + notification delivery lifecycle (Phase 25)  
- `EmailService` / Enterprise Email  
- Guests, invitations, ticket buyers/orders  
- `OrganizerAnalyticsService` / Finance monetary truth  
- `EventsAccessService` + org capabilities  
- Discover / public event surfaces  
- Reporting catalog (flip Marketing packs from Unavailable when ready)  

---

## 7. Feature discovery (Step 4) — what belongs in Phase 26

### In Phase 26 (P0–P1)

| Item | Priority |
|------|----------|
| Marketing IA (organizer) | P0 |
| Audience over guests + buyers | P0 |
| Email campaigns via NotificationService | P0 |
| Delivery status honesty | P0 |
| Promo codes on ticket apply (or explicit Unavailable until ready) | P0 |
| Conversion panel (read-only Analytics/Orders) | P1 |
| Deep-links to Analytics / Invitations / Discover | P1 |
| `marketing.manage` org capability | P0 |
| Enable Marketing report packs when data exists | P1 |

### Explicitly NOT Phase 26

| Item | Why |
|------|-----|
| LLM / Platform Copilot productization | Deferred; substrate first |
| Developer portal / public SDK | No consumer path; schema-only |
| Bull/Redis introduction | Infra gate, not grow objective |
| Salesforce / external ad networks | Integrations evolution later |
| Marketplace ratings/featured overhaul | Separate growth vector after demand tools |
| Super-admin Communication Center as organizer CRM | Mock — forbidden |
| Redesign Invitations / Ticketing / Analytics | Frozen |
| Parallel audience warehouse | Invents business data |

---

## 8. Architecture impact (Step 5)

```
Core Business Systems  ← audiences & orders remain truth; promos touch ticket apply only
        ↓
Automation Layer      ← can later emit/consume marketing actions (after campaigns exist)
        ↓
Integration Layer      ← email delivery already; optional webhooks unchanged
        ↓
Reporting Layer        ← Marketing packs become Available when product exists
        ↓
Organization Layer     ← new capability overlay (marketing.manage)
        ↓
Organizer Workspace    ← Marketing tab / Event Workspace module + deep-links
        ↓
Users                  ← organizers send; attendees receive via existing channels
```

| Layer | Impact |
|-------|--------|
| Core business | Additive campaign/promo tables; commerce apply path extension only |
| Automation | Unblock deferred marketing workflows — do not rebuild engine |
| Integrations | Consume email/SMS; no new provider system |
| Reporting | Replace Unavailable with real packs reading campaign + orders |
| Organization | Capability gate — no RBAC redesign |
| Workspace | Thin Marketing surface — extend Event Workspace / shell |
| Users | No new identity model |

---

## 9. Effort estimation (Step 6)

| Dimension | Estimate |
|-----------|----------|
| Overall Phase 26 | **Large** |
| P0 (IA + audience + email campaign + delivery + capability) | **Medium** |
| P0+ promo codes on commerce | **Medium** (touches commerce carefully) |
| P1 conversion + report packs + deep-links | **Medium** |
| Full enterprise ad/network growth | **Enterprise** — out of scope |

Comparable to a full Business Ops product phase (e.g. CRM / Reporting), not a hardening sprint.

---

## 10. Risks

| Risk | Mitigation |
|------|------------|
| Treating Communication Center mocks as production | Forbidden; Nest-backed organizer APIs only |
| Inventing second guest/buyer store | Audience = read model only |
| Promo codes corrupting Finance/Analytics | Finance remains money owner; promo is order-line/commerce concern |
| Starting before Live QA | Prerequisite gate in this document |
| Scope creep into AI/SDK/marketplace | Explicit out-of-scope list |
| Spam / consent | Prefer existing prefs (`allow_marketing` / ECP) where present; honest Unavailable if consent missing |
| Staff over-permission | Capability matrix; staff default deny send |

---

## 11. Implementation roadmap (definition only — do not implement yet)

### Wave 0 — Gate

1. Phase 25 Completion Review  
2. Integrated Live QA Planning progress acknowledged  

### Wave A — P0 Marketing foundation

3. Migration: campaigns, audience snapshots (non-authoritative), optional promo tables  
4. Nest Marketing module consuming guests/buyers + NotificationService  
5. Org capability `marketing.manage`  
6. Flutter Marketing surface  

### Wave B — Promo + conversion

7. Promo apply on ticket commerce  
8. Conversion read panel + report packs Available  
9. Deep-links  

### Wave C — Automation unlock

10. Thin automation actions for campaign triggers (consume engine)  
11. Regression across ticketing, finance, analytics, invitations  

---

## 12. Runner-up alternatives (why not Phase 26)

| Alternative | Why not now |
|-------------|-------------|
| Multi-instance job infrastructure (Bull/Redis) | Reliability infra; only if Live QA proves need |
| Developer portal / API keys / SDK | Schema stub; no organizer value unlock |
| Super-admin Copilot / MDM / Governance | Mock polish; not post-ops business gap |
| Marketplace ratings / featured | Valid later; hire loop already closed |
| LLM AI assistants | Explicitly deferred until campaign + analytics substrate |

---

## 13. Relationship to Phase 20

Phase 20 **Organizer Marketing & Growth** was correctly scoped then **not implemented** while 21–25 prioritized Business Operations.  

**Phase 26 is the evolution-layer delivery of that same platform objective**, updated for:

- Hardened NotificationService lifecycle  
- Org capability enforcement pattern  
- Finance-owned monetary truth for any revenue-adjacent KPIs  
- Frozen architecture rules for Phases 1–25  

Prior Phase 20 scope document remains a reference; Phase 26 is the authoritative next-phase definition under the 26–30 roadmap.

---

## 14. Final result

✅ Phase 26 Scope Defined

**STOP.** Do not begin Phase 26 implementation until Phase 25 Completion Review and Integrated Live QA Planning gates are cleared.
