# PHASE 17 — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–16 + live code / schema audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no code changes beyond this document  
**Prerequisite:** Phase 16 Live QA / Certification (or explicit waiver)

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Sell → invite → door loop closed (11–16). Money was earned and admitted; organizer cannot yet **own** post-event financial operations |
| **Critical-path hole** | Finance substrate is strong (ledger, summary, payouts, refunds, admin export) but organizer UX is stubbed/hidden; sales GET routes missing from HTTP surface; refunds admin-only |
| **Proposed domain** | Organizer Finance & Event Financial Operations — **correct next phase** |
| **Natural Phase 17** | Productize per-event + thin org finance: gross/net/fees, escrow/payout, refunds, reconciliation against orders — **not** a bank/OMS |
| **Not Phase 17** | Vendor CRM, Marketing, Analytics depth, tax engine, multi-currency banking, QFE rebuild |
| **Overall** | **✅ Phase 17 Scope Defined** |

---

## 2. Business flow review — next missing capability

```
Create (12) → Publish (14) → Sell (13–14) → Invite (15)
    → Check-in / Operate (16)
    → ??? Money: settle, refund, payout, reconcile
```

| After Phase 16 | Money state | Organizer can… |
|----------------|-------------|----------------|
| Paid / free orders | Captured / fulfilled; fees on ledger | See revenue chips; **not** a finance OS |
| Escrow | Held until release window | Summary fields exist; UX stub |
| Refunds | Buyer request + admin queue | See counts; **cannot** operate refunds |
| Payouts | API + ledger | Button only inside **hidden** `FinanceTabV3` |

**Next missing business capability:** Organizer-facing **event financial operations** — understand gross/net/fees, manage refunds, see settlement/payout readiness, reconcile orders to money, export evidence.

### Alternative progression check

| Candidate | Why not Phase 17 |
|-----------|------------------|
| **Vendor CRM** | Marketplace track; roadmap Phase **18**; does not close ticket money loop |
| **Marketing** | Campaigns; roadmap Phase **19**; no settlement dependency |
| **Analytics depth** | Charts/reporting; roadmap Phase **20**; soft dependency on finance truth |
| **Ops CRM** (walk-in/gates/staff) | Explicit Phase 16 deferral; not post-door money |

**Justification:** Phases 13–16 created and admitted paid value. Architecture roadmaps (14–16) already name Phase 17 as **Organizer finance & refunds productization**. Vendor/Marketing/Analytics do not unblock escrow, refunds, or payouts.

---

## 3. Phase 17 definition

### Official Phase Name

**Organizer Finance & Event Financial Operations**

*(Working short name: Organizer Finance Productization)*

### Business goal

After (or during) an event, organizers can **see and act on event money**: gross sales, platform fees, net earnings, escrow/payout eligibility, refund cases, and order-level reconciliation — with a thin org-wide finance hub for portfolio attention.

### Technical goal

Productize existing finance substrate without inventing parallel ledgers:

1. Mount real finance UI (`FinanceTabV3` or equivalent) on Event Workspace Finance tab  
2. Expose missing organizer sales HTTP routes (`OrganizerTicketSalesService`) for order reconciliation  
3. Organizer refund queue (read + appropriate actions) on top of `ticket_refund_cases`  
4. Surface gross / net / fees / escrow / payout KPIs from `OrganizerFinanceService`  
5. Thin org-wide finance hub + organizer-scoped export  
6. Complimentary / free-order visibility for accounting honesty  

### Primary user journeys

| # | Journey |
|---|---------|
| J1 | Organizer opens Event → Finance → sees gross, fees, net, escrow, open refunds |
| J2 | Organizer inspects orders / payments / refund status (reconcile) |
| J3 | Organizer reviews refund requests and takes allowed action (or clear handoff to policy) |
| J4 | Organizer requests payout when eligible; sees payout history / pending |
| J5 | Organizer exports event financial CSV for records |
| J6 | Organizer opens org Finance hub → portfolio revenue, payout-eligible, open refunds |

### Success criteria

- Event Finance tab is live (not escrow stub / not Budget-only misroute)  
- Gross, platform fees, net, escrow, payout eligibility match backend summary  
- Organizer can list event orders and open order detail (sales HTTP wired)  
- Refund cases visible to organizer; action path defined and working  
- Complimentary/free fulfilled orders countable  
- Export works for event-scoped transactions/orders/refunds  
- No new ledger schema; admin platform finance remains source of truth for platform ops  
- Phase 13–16 regressions: purchase, invite entitlement, door check-in still work  

### Why this follows Phase 16

Door ops completes attendance of issued entitlements. The business question after “people got in” is **“what did we earn, what is held, what was refunded, what can we payout?”** Finance was explicitly deferred through Phases 11–16.

---

## 4. Classification legend

| Label | Meaning |
|-------|---------|
| **Fully Implemented** | End-to-end usable on live organizer path |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 17 completeness |
| **Implemented but Hidden** | Built; not on primary organizer Finance route |
| **Backend Only** | API/DB ready; insufficient organizer UX |
| **Frontend Only** | UI present; API stubbed/absent/unenforced |
| **Not Implemented** | No meaningful product implementation |

---

## 5. Feature breakdown & codebase audit

| Feature | Classification | Evidence |
|---------|----------------|----------|
| **Revenue Dashboard (per-event)** | **Implemented but Hidden** | Rich `FinanceTabV3` + `organizerEventFinanceSummaryProvider`; Event Workspace uses stub `_FinanceTabBridge` (single escrow ListTile). Module “Finance” often opens **Budget**. |
| **Gross Sales** | **Backend Only** / **Partial FE** | `OrganizerEventFinanceSummary.grossCollectedMinor` / `ticketRevenueMinor` in `organizer-finance.service.ts`; shown inside hidden tab / KPI chips elsewhere |
| **Net Revenue** | **Backend Only** / **Partial FE** | `netEarningsMinor` on summary API; not primary live Finance surface |
| **Platform Fees** | **Backend Only** / **Partial FE** | `platformFeeMinor`; fee policy `tenant_finance_settings.ticket_platform_fee_bps` — no organizer fee config UI |
| **Refunds** | **Partially Implemented** | Buyer create + admin queue/actions (`ticket-refund.*`, `admin_ticket_refunds_panel.dart`). Organizer sees `openRefundRequests` count — **no organizer refund OS** |
| **Complimentary Ticket Accounting** | **Partially Implemented** | Free fulfill path in orders/payments; no dedicated complimentary KPI/line on finance summary |
| **Order Reconciliation** | **Partially Implemented** | `OrganizerTicketSalesService` (listOrders, getOrder, buyers, salesSummary) registered in module — **no Nest `@Get` routes** wiring it; Flutter already calls `events/:id/ticket-orders` etc. |
| **Settlement Status** | **Partially Implemented** | Escrow fields (`heldInEscrowMinor`, `payoutEligible`, `escrow_release_not_before` on orders); no organizer settlement timeline UX |
| **Payment Timeline** | **Implemented but Hidden** | `GET events/:id/finance/transactions` + list in `FinanceTabV3` |
| **Payout History** | **Partially Implemented** | `POST organizers/:id/payouts`; ledger `organizer_payable`; payout button in hidden tab; admin payout screens complete |
| **Financial Activity Feed** | **Implemented but Hidden** | Same transactions list; not on stub Finance tab |
| **Financial Summary** | **Partially Implemented** | API complete; UI mounting incomplete |
| **Event Profit Snapshot** | **Partially Implemented** | Closing center P/L mixes budget/vendor heuristics (`event_closing_*`) — adjacent, not ticket finance OS |
| **Transaction Search** | **Backend Only** (admin) | Admin finance transactions with filters; organizer list is limit-only |
| **Export Financial Data** | **Backend Only** (admin) | `finance-export.controller.ts` (transactions, payouts, refunds, settlements, organizer-payouts); **no organizer-scoped export** |

**Adjacent (do not redefine Phase 17):**

| Area | Notes |
|------|-------|
| Admin / Super-admin Finance | **Fully Implemented** for platform roles |
| Vendor Finance / Wallet | Parallel track — Phase 18 adjacency |
| Budget module | Celebration spend — keep separate from ticket finance |
| Live Ops revenue KPIs | Hard-zeroed in door summary mapping — hide or wire later; not P0 finance OS |

---

## 6. Existing vs missing implementation

### Existing (reuse — do not rebuild)

| Asset | Path |
|-------|------|
| Event finance summary / txs | `organizer-finance.controller.ts`, `organizer-finance.service.ts` |
| Payouts | `organizer-payout.service.ts`, `POST organizers/:id/payouts` |
| Sales service (needs HTTP) | `organizer-ticket-sales.service.ts` |
| Orders / payments / capture | `ticket-orders.service.ts`, `ticket-payments.service.ts`, `ticket-capture.service.ts` |
| Refunds | `ticket-refund.controller.ts`, `ticket-refund.service.ts`, `ticket_refund_cases` |
| Fee policy | `tenant-finance-policy.service.ts`, `tenant_finance_settings` |
| Ledger | `ledger.service.ts`, `ledger_*` tables |
| Export (admin) | `finance-export.service.ts` / `.controller.ts` |
| Flutter finance clients | `organizer_finance_api.dart`, `organizer_finance_providers.dart`, customer twin APIs |
| Rich FE | `finance_tab_v3.dart`, `cc_v3_finance_charts.dart` |
| Tickets / orders UI | `TicketsTabV3`, `ticket_commerce_api.dart` |
| Portal revenue KPI | `organizer-portal.service.ts` dashboard |
| Schema | `016_phase5_ticket_commerce_foundation.sql`, `006_fintech_escrow_controls.sql`, ledger in `owanbe_core.sql` |

### Missing (Phase 17 targets)

| Gap | Priority |
|-----|----------|
| Replace `_FinanceTabBridge` with live finance UI | **P0** |
| Wire `OrganizerTicketSalesService` to HTTP GET routes | **P0** |
| Organizer refund queue + allowed actions | **P0** |
| Gross / net / fees / escrow / payout KPIs on live surface | **P0** |
| Settlement / eligibility copy (escrow countdown honesty) | **P1** |
| Complimentary / free-order accounting slice | **P1** |
| Thin org-wide Finance hub + EOS nav | **P1** |
| Organizer-scoped CSV export | **P1** |
| Transaction search (organizer filters) | **P2** |
| Ops dashboard revenue zeros | **P2** (hide or soft-wire) |
| Tax / banking / QFE / Vendor CRM / Marketing | **Out** |

---

## 7. Reuse analysis

| Layer | Reuse |
|-------|-------|
| **Routes** | Event Workspace `Finance` tab slot; `/events/:id/budget` stays budget; add org Finance destination |
| **Screens / widgets** | Mount `FinanceTabV3`; charts; admin refund panel as UX pattern; vendor earnings as parallel reference only |
| **Providers / APIs** | `organizer_finance_*`, `ticket_commerce_api` sales methods, refund buyer APIs |
| **Controllers / services** | Organizer finance, payout, ticket sales (wire), refund (extend authZ), finance export (scope) |
| **Tables** | `ticket_orders`, `ticket_payments`, `ticket_refund_cases`, `organizer_payouts`, `ledger_*`, `tenant_finance_settings` |
| **Business rules** | Fee bps, escrow hold, payout eligibility, refund case state machine, free-order zero fee |

**Avoid:** Second ledger, parallel “wallet” schema, rebuilding admin finance for organizers, conflating Budget module with ticket finance.

---

## 8. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Ticket Commerce (13)** | **Hard** — orders, fees, capture, entitlements |
| **Orders / Payments** | **Hard** — reconciliation source of truth |
| **Refunds** | **Hard** — cases + ledger reverse |
| **Settlements / escrow** | **Hard** — payout eligibility |
| **Organizer Dashboard** | Soft — portfolio entry + revenue KPI consistency |
| **Analytics / Reports** | Soft — export may feed later analytics |
| **Phase 16 Door Ops** | Soft — no finance dependency; **cert gate** before starting 17 |
| **Vendor Operations** | Out of scope (Phase 18) |

```
ticket_orders → ticket_payments → capture → ledger
             → free fulfill (fee 0)
             → ticket_refund_cases → refund ledger
             → escrow window → organizer_payouts → ledger
```

---

## 9. Risks

| Risk | Mitigation |
|------|------------|
| Scope creeps into banking / tax / QFE | Hard out-list; productize existing rails only |
| Organizer refund authZ unclear (approve vs request-only) | Decide in sprint: organizer approve within policy **or** organizer request + admin finalize — document in completion report |
| Sales HTTP gap breaks Tickets/Finance reconcile | P0 wire `OrganizerTicketSalesService` routes |
| Finance tab conflated with Budget | Keep Budget route; Finance = ticket money |
| Payout against Quaser stub vs prod | Document environment policy; reuse existing payout service |
| Starting before Phase 16 cert | STOP until Live QA / waiver |

**Architectural decision resolved for naming:** Phase 17 = **organizer finance productization on existing commerce/ledger**, not a new financial core.  
One product policy to confirm during implementation (not blocking scope): **organizer refund authority** (approve vs escalate). Default recommendation: organizer can **view + approve/reject within tenant policy** mirroring admin actions with organizer ownership checks; if policy forbids, ship read-only queue + “escalate to admin” — still in scope as thin slice.

No further phase-level decisions block **scope definition**.

---

## 10. Implementation effort

| Module | Effort | Notes |
|--------|--------|-------|
| Mount FinanceTabV3 / replace stub | **Small** | FE exists |
| Wire organizer sales GET routes | **Small** | Service complete |
| Gross/net/fee/escrow KPI polish + settlement copy | **Small** | Summary API ready |
| Organizer refund queue + actions | **Medium** | AuthZ + FE; reuse cases |
| Complimentary accounting slice | **Small** | SQL + KPI |
| Org-wide Finance hub (read-only) | **Medium** | Aggregate API + nav + screen |
| Organizer CSV export | **Small–Medium** | Clone admin export + ownership filter |
| Transaction search (organizer) | **Medium** | Optional P2 |
| Tax / QFE / banking rebuild | **Large** | **Defer** |
| **Sprint total (scoped)** | **Medium** | ~1 focused sprint |

---

## 11. Completion sprint roadmap

### Single sprint goal

**Organizers can operate event money — see gross/net/fees/escrow, reconcile orders, handle refunds, request payouts, and export — on existing ledger/commerce rails.**

### P0 (must ship)

1. Replace Event Workspace `_FinanceTabBridge` with live finance UI (`FinanceTabV3` or equivalent wired providers).  
2. Expose HTTP for `OrganizerTicketSalesService`: event orders, order detail, buyers, sales summary.  
3. Surface gross, platform fees, net, escrow held, available/pending payout, open refunds, payout eligibility.  
4. Organizer refund queue for the event (list + detail); implement allowed actions with ownership checks.  
5. Payout request path reachable from live Finance UI (reuse existing POST).  
6. Regression smoke: purchase → finance summary update; refund does not break door entitlement rules unexpectedly.

### P1 (should ship)

7. Settlement / escrow eligibility copy (why payout blocked / when release).  
8. Complimentary / free fulfilled order count (and zero-revenue clarity).  
9. Thin org-wide Finance hub (portfolio revenue, payout-eligible, open refunds) + EOS organizer Finance entry.  
10. Organizer-scoped CSV export (transactions / orders / refunds).  
11. Empty / loading / error polish on Finance surfaces.

### P2 (defer if timeboxed)

12. Organizer transaction search/filters.  
13. Live Ops revenue zeros — hide vendor/orders/revenue cards or soft-wire from finance.  
14. Deeper profit snapshot aligning closing P/L with ticket finance only.

### Explicitly out of sprint

- Walk-in sales, staff/gates (Ops CRM)  
- Vendor marketplace CRM (Phase 18)  
- Marketing campaigns (Phase 19)  
- Analytics time-series rebuild (Phase 20)  
- Tax engine, multi-currency banking, QFE redesign  
- Platform admin finance rewrite  

---

## 12. Roadmap hint (non-binding)

| Phase | Theme |
|-------|--------|
| **16** | Door / Live Event Operations (implemented; Live QA pending) |
| **17** | Organizer Finance & Event Financial Operations (**this doc**) |
| **18** | Vendor marketplace CRM |
| **19** | Marketing / communications campaigns |
| **20** | Analytics depth |

---

## 13. Dependencies & stop conditions

| Gate | Status |
|------|--------|
| Phase 16 implementation | Complete (completion report) |
| Phase 16 Live QA / Certification | **Pending** — do not start Phase 17 build until certified (or waived) |
| Phase 17 scope doc | **This document** |
| Phase 17 implementation | **Not started** |

**STOP:** Do not begin Phase 17 coding, Phase 18, or Marketing/Analytics delivery from this doc alone.

---

## 14. Final classification

### ✅ Phase 17 Scope Defined

**Phase 17 = Organizer Finance & Event Financial Operations**

Validates the proposed finance domain as the correct **next Organizer capability**: productize existing commerce, ledger, payout, and refund rails into a live Event Finance surface (plus thin org hub/export) — not a greenfield bank or OMS. Natural successor to Phases 13–14 money creation and Phase 16 door completion.
