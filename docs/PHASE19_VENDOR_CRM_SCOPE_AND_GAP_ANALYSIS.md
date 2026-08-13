# PHASE 19 — VENDOR CRM & VENDOR OPERATIONS — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–18 + live code audit + Vendor OS / Identity reports) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Architecture freeze:** Phases 14–18 are frozen pending Live QA — Phase 19 may **consume** them only; it must not redesign Publishing, Sales, Invitations, Door Ops, Finance, or Analytics  
**Prerequisite:** Phase 18 Live QA / Certification (or explicit waiver) **and** Vendor Identity Resolution complete (assumed before CRM productization)

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Ticket lifecycle complete: Create → Sell → Invite → Door → Finance → Analytics |
| **Proposed domain** | Vendor CRM & Vendor Operations — **correct next Organizer capability** |
| **Prior roadmap** | Phase 18 scope already renumbered Vendor CRM → **19**, Marketing → **20** |
| **Identity** | Vendor Identity Resolution is a **separate** sprint; Phase 19 **consumes** canonical `vendors.id` only — does not redesign identity |
| **Natural Phase 19** | Productize the existing hire → inbox → negotiate → assign → execute → complete loop — not a greenfield CRM platform |
| **IA** | Primary = Event Vendor Pipeline + Event Workspace Vendors; secondary = Vendor Inbox / Dashboard (Vendor OS) |
| **Overall** | **✅ Phase 19 Scope Defined** |

---

## 2. Business flow review — next missing capability

```
Create (12) → Tickets (13) → Publish/Sell (14) → Invite (15)
    → Door (16) → Finance (17) → Analytics (18)
    → ??? Hire & operate vendors
```

| After Phase 18 | Organizer can… | Still missing |
|----------------|----------------|---------------|
| Run ticketed events end-to-end | Sell, invite, check in, settle, measure | **Trusted vendor hire lifecycle** as a first-class Event OS module |
| Marketplace discovery | Find vendors and create CRM requests | Coherent pipeline UX on Workspace (not stub counts) |
| Vendor OS inbox (partial) | Accept / decline / counter on live CRM rows | Honest contracts, deliverables, notes, history, performance |
| Analytics | Ticket/RSVP/door/finance intelligence | Vendor spend & completion intelligence (later; consume CRM stages first) |

**Next missing operational capability:** Organizer-facing **Vendor CRM & Operations** — answer “who did we hire, where are they in the pipeline, what was agreed, and did they complete?” using the existing `vendor_event_requests` spine — not mock leads or parallel negotiation engines.

### Alternative progression check

| Candidate | Why not Phase 19 (now) |
|-----------|-------------------------|
| **Marketing** | Needs audience + performance signals; ticket analytics just landed; campaigns do not close the hire loop |
| **Attendee CRM depth** | Guests/RSVP already shipped in Phase 15; further CRM is refinement, not the next Organizer gap |
| **Vendor payouts / vendor finance depth** | Parallel Vendor OS money track; depends on accepted contracts/completion; follows CRM truth |
| **Deeper BI / ML** | Explicitly deferred; Analytics freeze says read-only, no warehouse |
| **Keep CRM later** | Hire loop is the largest unfinished Organizer operational track after tickets |

**Justification:** Phases 11–18 closed the **attendee commerce** loop. The Organizer’s remaining day-to-day operational loop is **marketplace hire → negotiate → assign → execute → complete**. Identity resolution unblocks trustworthy IDs; Phase 19 productizes the CRM that already partially exists.

---

## 3. Phase 19 definition

### Official Phase Name

**Organizer Vendor CRM & Vendor Operations**

*(Working short name: Vendor CRM)*

### Business goal

Give organizers a trustworthy **vendor hire pipeline** for each event — request, negotiate, accept, schedule, arrive, complete — shared with Vendor OS inbox, without inventing a second CRM or redesigning Marketplace / Identity / Finance / Analytics.

### Technical goal

Productize existing Vendor CRM rails without greenfield duplication:

1. Treat `vendor_event_requests` (+ stage history, `vendor_negotiations` / offers) as the **canonical hire record**  
2. Mount / deepen Event Workspace Vendors (replace stub `_VendorsTabBridge`) — prefer reuse of `VendorsTabV3` + pipeline screen patterns (like Finance/Analytics mounts)  
3. Keep Marketplace as **discovery-only**; create requests with canonical `vendors.id`  
4. Prefer live CRM on Vendor Dashboard / Inbox; stop masking empty state with demo intelligence where live data exists  
5. Decide honesty for **Contracts** (UI mock today) — either wire to CRM negotiation amounts or mark Unavailable / defer legal signing  
6. Do **not** redesign Vendor Identity; do **not** merge AI `negotiation_sessions` into CRM without an explicit architecture decision  
7. Do **not** modify frozen Phase 14–18 business rules  

### Primary user journeys

| # | Journey |
|---|---------|
| J1 | Organizer browses Marketplace → requests vendor for event → row appears in Vendor Pipeline |
| J2 | Vendor sees request in Inbox → accepts / declines / counters → Organizer pipeline updates |
| J3 | Organizer advances stages (accepted → scheduled → arrived → completed) |
| J4 | Either party messages on the request; both see notifications / feed activity |
| J5 | Accepted vendor appears in Vendor Events (participation) |
| J6 | Organizer opens Event Workspace Vendors and sees the same CRM truth (not stub counts) |

### Success criteria

- Event Workspace Vendors is live CRM (not thin “Requested / Accepted” stub only)  
- Pipeline and Vendor Inbox share the same `vendor_event_requests` rows  
- All requests use canonical `vendors.id` (Identity Resolution outcome)  
- Stage transitions, counter, messages work end-to-end with notifications  
- Contracts / ratings / deliverables either **real** or **honestly unavailable** — no fake signed agreements presented as truth  
- No parallel second CRM table or second hire workflow  
- Phases 14–18 untouched except deep-links / reads  
- No Marketing / ML / ticket-commerce redesign  

### Why this follows Phase 18

Analytics closed “understand ticket performance.” The next Organizer question for celebration production is **vendor fulfillment**: who is hired and whether they deliver. Identity Resolution makes Marketplace → CRM → Inbox safe. CRM productization is the natural Phase 19 before Marketing (20) or deeper vendor finance.

---

## 4. Classification legend

| Label | Meaning |
|-------|---------|
| **Fully Implemented** | End-to-end usable with real data on live path |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 19 completeness |
| **Implemented but Hidden** | Built; not on primary Event Workspace / Organizer path |
| **Backend Only** | API/DB ready; insufficient organizer/vendor UX |
| **Frontend Only** | UI present; API stubbed/mocked/synthesized |
| **Not Implemented** | No meaningful product implementation |

---

## 5. Feature breakdown & codebase audit

| Feature | Classification | Evidence |
|---------|----------------|----------|
| **Vendor Pipeline** | **Partially Implemented** | Live: `CustomerEventVendorPipelineScreen` + `eventVendorCrmProvider` → `GET /events/:id/vendor-requests`. Workspace Vendors tab is stub `_VendorsTabBridge` (counts only). `VendorsTabV3` richer but **not mounted** on primary workspace |
| **Vendor CRM (core request spine)** | **Partially Implemented** | DB `vendor_event_requests`, stage history (`036_vendor_crm.sql`); `VendorCrmService` + `VendorOperationsController` |
| **Vendor Inbox** | **Partially Implemented** | `GET /vendors/:id/requests`; `vendorInboxSnapshotProvider`; dashboard prefers live inbox when loaded; still falls back to `VendorIntelligenceEngine` demos |
| **Vendor Requests** | **Fully Implemented** (API + Marketplace create) | `POST /events/:id/vendor-requests`; `inviteVendorToEvent` / `inviteVendor` resolve canonical ID |
| **Negotiations** | **Partially Implemented** | CRM path: `vendor_negotiations` + `vendor_negotiation_offers` on create-with-amount / counter. **Parallel stack:** `negotiation_sessions` (`vendor-negotiations.service.ts`, AI engine) — Class C / out of CRM spine |
| **Counter Offers** | **Fully Implemented** (API) / **Partial** UX | `POST /vendor-requests/:id/counter`; vendor dashboard sheets; organizer pipeline stage chips thinner on counter display |
| **Contracts** | **Frontend Only** | `ContractProposal` + `ContractGenerator` in-memory dialogs on pipeline & vendor dashboard — hardcoded amounts; **not** persisted CRM contracts. Separate `negotiation_contracts` in AI migration — not organizer hire contracts |
| **Vendor Timeline** | **Partially Implemented** | History rows written to `vendor_request_stage_history`; **no GET history endpoint**. FE timeline UX incomplete / mock on Event 360 |
| **Vendor Activity Feed** | **Partially Implemented** | Backend writes `event_feed_items` (`feed_type = vendor_crm`) + in-app notifications; readable via event feed; organizer hub alerts via `organizerVendorCrmAlertsProvider`; no dedicated CRM activity UI |
| **Vendor Status (stages)** | **Fully Implemented** (backend rules) | Stages: `new → negotiating → accepted → scheduled → arrived → completed` (+ declined/cancelled); `STAGE_TRANSITIONS` enforced |
| **Vendor Performance** | **Not Implemented** | No organizer performance rollups from completed requests; analytics Phase 18 did not include vendor KPIs |
| **Vendor Notes** | **Frontend Only** | Mock notes on `VendorCrmScreen` (“Organizer CRM Workspace”); stage `note` field exists on transition API but not productized as CRM notes |
| **Vendor Attachments** | **Not Implemented** | No attachment tables/APIs for CRM requests |
| **Vendor Categories** | **Partially Implemented** | Catalog / tenant categories exist for marketplace discovery; not a CRM assignment taxonomy product |
| **Vendor Event Assignments** | **Partially Implemented** | Accept → `vendor_event_participations` upsert; Vendor Events tab; organizer assignment UX thin |
| **Vendor Availability** | **Partially Implemented** | Calendar APIs + BE conflict check on `scheduled`; Flutter `vendorCalendarProvider` / fetch helpers largely **unused** — `/vendor/calendar` UI still local mock |
| **Vendor Contacts** | **Partially Implemented** | Vendor profile / workspace profile; not request-scoped contact CRM |
| **Vendor Ratings (Organizer only)** | **Frontend Only** / display null | UI shows `ratingAverage`; `VendorsService` returns `ratingAverage: null`; marketplace may synthesize display ratings |
| **Vendor Deliverables** | **Frontend Only** | Mock progress on OMS (`orders_bookings_screen`) and Event 360 local timeline |
| **Vendor Completion** | **Partially Implemented** | Stage `completed` + `completedAt` on CRM; weak deliverable checklist / sign-off |
| **Vendor History** | **Backend Only** | Stage history + offers written; **no list/history API** and no organizer history browser |
| **CRM vs organizer vendor slots** | **Dual-path risk** | Pipeline/marketplace write `vendor_event_requests`; EOS `VendorManagementScreen` / CC V3 often synthesize from `event.vendors` slots with fake negotiation timelines — Phase 19 must unify or deprecate slot pipeline UX |
| **Offer ledger (list/accept)** | **Backend Only** (writes) | Counters create `vendor_negotiation_offers`; missing organizer list/accept offer endpoints and UI |

### Related surfaces (context, not Phase 19 greenfield)

| Surface | Classification | Notes |
|---------|----------------|-------|
| Marketplace | Discovery + request create | Must stay discovery-only for CRM |
| Vendor Dashboard | Partial live + demos | Prefer CRM inbox |
| Vendor OMS / Orders | Frontend Only mocks | `_mockOmsOrders` — do not treat as CRM truth |
| Vendor Identity | Separate sprint (complete for path) | Consume only |
| `VendorCrmScreen` mock leads | Frontend Only | Misleading “Organizer CRM”; not the event pipeline |

---

## 6. Existing implementation (keep / reuse)

| Layer | Assets |
|-------|--------|
| **DB** | `vendors`, `vendor_profiles`, `vendor_event_requests`, `vendor_request_stage_history`, `vendor_negotiations`, `vendor_negotiation_offers`, `vendor_event_participations`, `vendor_availability_settings`, `vendor_calendar_blocks`, `notifications`, `event_feed_items` |
| **Services** | `VendorCrmService`, `VendorCalendarService`, `VendorParticipationService`, `VendorsService` (catalog), `NotificationService`, Identity / `EventsAccessService` / `VendorAccessService` resolve chains |
| **Controllers** | `VendorOperationsController` — list/create/patch/stage/counter/messages; vendor calendar routes |
| **Flutter API/providers** | `VendorCrmApi`, `eventVendorCrmProvider`, `vendorInboxProvider`, `vendorInboxSnapshotProvider`, marketplace invite helpers |
| **Flutter UI** | Pipeline screen, marketplace request sheet, vendor stage badge, vendor dashboard inbox branch, `VendorsTabV3` (orphan), invite vendor sheet |
| **Docs** | `VENDOR_IDENTITY_RESOLUTION_REPORT.md`, `VENDOR_OS_INTEGRATION_REPORT.md` |

---

## 7. Missing implementation

| Gap | Priority for Phase 19 |
|-----|------------------------|
| Mount real Vendors CRM on Event Workspace (replace stub bridge) | **P0** |
| Unify organizer UX: pipeline stages + counters + messages visible | **P0** |
| Stop presenting mock contracts as signed truth | **P0** |
| Prefer live inbox; reduce demo intelligence masking | **P0** |
| Honest ratings (Unavailable until rating store exists) | **P1** |
| Request-scoped notes / activity timeline UI | **P1** |
| Completion / deliverables checklist tied to CRM request | **P1** |
| Attachments | **P2** / defer |
| Organizer-only ratings write path | **P2** |
| Vendor performance rollups into Analytics (read-only consume) | **P2** / later |
| Legal e-sign contracts | **Defer** (or separate decision) |
| Merge/kill AI `negotiation_sessions` stack | **Architecture decision** — do not silently merge |

---

## 8. Hidden implementation

| Asset | Status |
|-------|--------|
| `VendorsTabV3` | Implemented but Hidden (not mounted on Event Workspace) |
| Stage history + feed writes | Backend present; thin organizer UI |
| Calendar CRM schedule blocks | Backend + vendor calendar; organizer scheduling UX partial |
| Participation on accept | Backend wired; organizer “assignment” UX partial |

---

## 9. Reuse opportunities (do not duplicate)

| Capability | Reuse |
|------------|-------|
| Hire record | `vendor_event_requests` only |
| Negotiation money offers | `vendor_negotiations` / `vendor_negotiation_offers` (CRM path) |
| Inbox | Same list-for-vendor API |
| Marketplace | Catalog + request create only |
| Notifications | Existing in-app + `NotificationService` kinds |
| Event activity | `event_feed_items` vendor_crm |
| Calendar | `VendorCalendarService` on schedule |
| Identity | `GET /me/vendor-id` + COALESCE resolve — no new ID scheme |
| Workspace mount pattern | Same as FinanceTabV3 / AnalyticsTabV3 |
| OMS / AI negotiation / mock ContractProposal | Do **not** promote to source of truth without decision |

---

## 10. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Vendor Identity** | **Hard prerequisite** — Marketplace → CRM → Inbox → Notifications must share `vendors.id` |
| **Marketplace** | Discovery entry; create request |
| **Notifications** | Stage/counter/message alerts |
| **Finance (Phase 17)** | Consume later for vendor payouts; **do not** change ticket finance rules in Phase 19 |
| **Analytics (Phase 18)** | Optional later read of CRM stages; **do not** invent vendor metrics |
| **Orders (tickets)** | Out of scope — vendor hire ≠ ticket orders |
| **Contracts** | Depends on negotiation honesty decision |
| **Negotiations** | Prefer CRM `vendor_negotiations`; isolate AI `negotiation_sessions` |

---

## 11. Risks

| Risk | Mitigation |
|------|------------|
| Dual negotiation engines confuse product | Document CRM spine vs AI stack; freeze AI path as Class C for Phase 19 |
| Mock contracts erode trust | Remove or label Unavailable; never show fake signatures as real |
| Demo intelligence masks empty inbox | Prefer live snapshot; empty = empty |
| Touching frozen phases | Architecture freeze — consume only; stop for approval if 14–18 changes needed |
| Scope explosion into OMS / rentals / attire | Keep Phase 19 on CRM request lifecycle |
| Identity regressions | Regression tests on canonical UUID create → inbox |
| Workspace Vendors mount without CRM provider | Mirror Finance/Analytics pattern; wire `eventVendorCrmProvider` |
| Dual negotiation engines (CRM vs AI `negotiation_sessions`) | Prefer CRM-linked `vendor_negotiations`; freeze AI stack as Class C unless approved |
| CRM accept → finance | Accept does **not** post ledger/escrow; hardcoded participation payout fields — bridge later without inventing a second money path |
| Dual organizer truth (slots vs CRM requests) | Single organizer vendor surface must read CRM; retire or map slots |

---

## 12. Implementation effort

| Workstream | Size |
|------------|------|
| Workspace Vendors mount + pipeline parity | **Medium** |
| Inbox honesty / demos cleanup | **Small–Medium** |
| Counter/message UX parity on organizer | **Medium** |
| Contracts honesty (wire or Unavailable) | **Medium** (full e-sign = **Large**, defer) |
| Notes / activity timeline | **Medium** |
| Deliverables / completion checklist | **Medium** |
| Ratings store + organizer write | **Large** (defer to P2) |
| Attachments | **Medium–Large** (defer) |
| **Overall Phase 19 completion sprint** | **Large** |

---

## 13. Completion Sprint roadmap (definition only — do not implement yet)

### P0 — Canonical hire loop on Organizer surfaces
- Mount CRM Vendors on Event Workspace (reuse `VendorsTabV3` and/or deepen pipeline embed)
- Ensure Marketplace → request → Pipeline → Inbox → stage/counter/message path is the only hire path
- Remove or quarantine mock contract “signed” UX
- Prefer live inbox over `VendorIntelligenceEngine` when CRM loads

### P1 — Operations honesty
- Activity / stage history UI for a request
- Scheduling UX tied to calendar blocks
- Completion marking with clear status (deliverables light)
- Ratings display = Unavailable until backend exists (no synthetic stars)

### P2 — CRM depth (optional in sprint if time)
- Organizer notes on request
- Attachments
- Organizer ratings write
- Portfolio vendor history
- Read-only vendor stage rollups into Analytics (consume only)

### Explicitly out of Phase 19
- Marketing campaigns  
- Ticket commerce / door / finance / analytics redesign  
- Vendor Identity redesign  
- AI negotiation engine productization  
- Full legal e-sign / escrow vendor payouts (unless already present and only linked)  
- OMS mock → real OMS identity sprint  

---

## 14. Architecture question — canonical Vendor CRM lifecycle

**After Vendor Identity Resolution is complete, what is the canonical Vendor CRM lifecycle?**

```
Marketplace                    (VendorsService catalog — discovery only)
        │
        ▼
Organizer Request              (POST /events/:eventId/vendor-requests
                                vendorId = canonical vendors.id)
        │
        ▼
Vendor Inbox                   (GET /vendors/:vendorId/requests
                                Vendor Dashboard live inbox branch)
        │
        ▼
Negotiation                    (vendor_negotiations + vendor_negotiation_offers
                                counter / optional create-with-amount
                                messages via stage history + feed)
        │
        ▼
Contract                       (*Phase 19 decision*: bind to CRM negotiation
                                amounts OR show Unavailable —
                                NOT ContractProposal mock as truth)
        │
        ▼
Assignment                     (stage accepted → vendor_event_participations
                                Vendor Events / event assignment)
        │
        ▼
Execution                      (scheduled → arrived; calendar crm_scheduled
                                blocks; day-of ops stay Phase 16 door — separate)
        │
        ▼
Completion                     (stage completed + completedAt;
                                optional deliverables checklist in P1)
```

### Modules reused at each step

| Step | Reuse |
|------|-------|
| Marketplace | `VendorsService` / Flutter marketplace + request sheet |
| Organizer Request | `VendorCrmService.createRequest`, Identity resolve |
| Vendor Inbox | `listForVendor`, `vendorInboxSnapshotProvider` |
| Negotiation | CRM negotiations/offers + counter/messages endpoints |
| Contract | TBD honesty layer over CRM negotiation — not AI `negotiation_contracts` by default |
| Assignment | `ensureParticipationOnAccept` / `VendorParticipationService` |
| Execution | Stage machine + `VendorCalendarService` |
| Completion | Stage `completed` + history/feed |

**Organizer OS, Vendor OS, and Attendee OS remain separate worlds** — integration is through **business records** (`vendor_event_requests`), not shared UI shells.

---

## 15. Deliverables checklist (this document)

| # | Section | Status |
|---|---------|--------|
| 1 | Recommended Phase title | **Organizer Vendor CRM & Vendor Operations** |
| 2 | Business objective | Hire lifecycle trust for organizers |
| 3 | Technical objective | Productize CRM spine; mount Workspace Vendors |
| 4 | Feature breakdown | §5 |
| 5 | Existing implementation | §6 |
| 6 | Missing implementation | §7 |
| 7 | Hidden implementation | §8 |
| 8 | Reuse opportunities | §9 |
| 9 | Dependencies | §10 |
| 10 | Risks | §11 |
| 11 | Completion Sprint roadmap | §13 |

---

## 16. Final result

**✅ Phase 19 Scope Defined**

**STOP.** Do not implement Phase 19. Do not modify application code from this document. Await Phase 18 Live QA / Certification (or waiver) and confirm Vendor Identity Resolution remains the consumed identity path before any Completion Sprint.
