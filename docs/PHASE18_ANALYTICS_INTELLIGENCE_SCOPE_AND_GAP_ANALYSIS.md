# PHASE 18 — ANALYTICS & EVENT INTELLIGENCE — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–17 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no code changes beyond this document  
**Prerequisite:** Phase 17 Live QA / Certification (or explicit waiver)

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Create → sell → invite → door → finance loop is complete; organizers lack **honest event intelligence** over that data |
| **Proposed domain** | Analytics & Event Intelligence — **correct next Organizer phase** |
| **Prior roadmap conflict** | Phases 14–17 numbered Vendor CRM as 18 and Analytics as 20 |
| **Resolution** | **Promote Analytics to Phase 18**; renumber Vendor CRM → **19**, Marketing → **20**, deeper BI → later |
| **Natural Phase 18** | Productize existing charts/tabs with **real time-series** from commerce, invitations, check-ins, finance — not a new BI platform |
| **IA** | Primary = **Event Workspace Analytics tab**; secondary = EOS Organizer Analytics shell |
| **Overall** | **✅ Phase 18 Scope Defined** |

---

## 2. Business flow review — next missing capability

```
Create (12) → Configure (12) → Tickets (13) → Publish (14)
    → Sell (14) → Invite (15) → Operate (16) → Finance (17)
    → ??? Understand performance
```

| After Phase 17 | Organizer can… | Still missing |
|----------------|----------------|---------------|
| Sell / invite / check-in / refund | Operate and settle money | **Trends, funnels, conversion honesty** |
| Finance workspace | See gross/net/fees point-in-time | Sales velocity, refund/attendance curves |
| EOS Analytics tab | Open charts | Values largely **synthesized** |
| Workspace Analytics tab | Exists | Stub “Traffic & Channel Conversion” |

**Next missing business capability:** Organizer-facing **Event Intelligence** — answer “are we selling, converting RSVPs, filling the room, and refunding?” with data from phases 13–17, not mock sparklines.

### Alternative progression check

| Candidate | Prior slot | Why not Phase 18 (now) |
|-----------|------------|-------------------------|
| **Vendor CRM** | Was “18” | Parallel marketplace track; does not consume finance/door/invite truth; weak sequel to Phase 17 |
| **Marketing** | Was “19” | Campaigns need audience/performance signals — analytics first is healthier |
| **Keep Analytics as 20** | Old roadmap | Soft dependency was **finance truth** — Phase 17 closed that gate |

**Justification:** Analytics was deferred until money and ops data existed. That prerequisite is met. Vendor CRM remains important but is a different loop (hire → deliver → vendor pay). After Finance, the organizer’s natural question is performance intelligence.

---

## 3. Phase 18 definition

### Official Phase Name

**Organizer Analytics & Event Intelligence**

*(Working short name: Event Intelligence)*

### Business objective

Give organizers a trustworthy view of **how an event is performing** — ticket sales trends, invitation/RSVP conversion, attendance/check-in, revenue and refund rates — composed from existing commerce, invite, ops, and finance data.

### Technical objective

Productize existing analytics UI without inventing a second analytics engine:

1. Add organizer **time-series / snapshot APIs** over existing tables  
2. Replace synthesis in `organizerAnalyticsProvider` with real series  
3. Mount `AnalyticsTabV3` on Event Workspace (replace stub bridge)  
4. Unify invitation, check-in, sales, and finance KPIs into one event intelligence surface  
5. Upgrade portfolio comparison honesty; optional analytics CSV export  
6. Do **not** greenfield traffic/UTM, demographics, or ML forecasts in this phase  

### Primary user journeys

| # | Journey |
|---|---------|
| J1 | Organizer opens Event → Analytics → sees sales, attendance, RSVP/purchase conversion, refund rate |
| J2 | Organizer switches period (7d / 30d / all) and sees real trend charts |
| J3 | Organizer opens EOS Analytics, picks event, same snapshot as workspace |
| J4 | Organizer compares events on portfolio (honest rollups / sparklines) |
| J5 | Organizer exports sales/attendance/RSVP summary CSV |

### Success criteria

- Workspace Analytics tab is live (`AnalyticsTabV3`), not fake traffic series  
- Sales / revenue / check-in / refund trends come from backend buckets (or clearly labeled estimates only where unavoidable)  
- Invitation funnel and ticket sell-through use real stats APIs  
- No duplicate BI schema; compose commerce + invites + ops + finance  
- Traffic sources / demographics remain out unless already supported (they are not)  
- Phase 13–17 regressions: purchase, RSVP, door, finance still work  

### Why this follows Phase 17

Finance made money truthful. Intelligence needs truthful money **plus** sales, invites, and check-ins already shipped in 13–16. Charts and tabs already exist but lie or hide. Phase 18 closes the “understand the event” gap before branching into Vendor CRM or Marketing.

---

## 4. Classification legend

| Label | Meaning |
|-------|---------|
| **Fully Implemented** | End-to-end usable with real data on live path |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 18 completeness |
| **Implemented but Hidden** | Built; not on primary Analytics route |
| **Backend Only** | API/DB ready; insufficient organizer UX |
| **Frontend Only** | UI present; API stubbed/synthesized |
| **Not Implemented** | No meaningful product implementation |

---

## 5. Feature breakdown & codebase audit

| Feature | Classification | Evidence |
|---------|----------------|----------|
| **Event Performance Dashboard** | **Partially Implemented** | `EventAnalyticsScreen` on EOS tab 5; Workspace Analytics stub; `AnalyticsTabV3` orphaned |
| **Attendance Analytics** | **Partially Implemented** | Check-in rates in ops health / door summary; analytics snap has checkIns/noShows — **no hourly/day series API** |
| **Revenue Analytics** | **Partially Implemented** | Finance summary + tickets KPIs point-in-time; trend charts synthesized |
| **Ticket Sales Trends** | **Frontend Only** / **Partial** | `organizerAnalyticsProvider` synthesizes (`sold/7` style); `GET tiers/sales` is point-in-time |
| **Sales Funnel** | **Partially Implemented** | Sell-through / capacity metrics; not visit→cart→purchase |
| **Conversion Funnel** | **Partially Implemented** | `conversionPercent` from capacity heuristics; private RSVP funnel charts exist |
| **Traffic Sources** | **Not Implemented** | Workspace “Traffic & Channel Conversion” uses hardcoded series; no UTM/referrer storage |
| **Invitation Analytics** | **Partially Implemented** | Backend `getStats` / hub; `InvitationStatsRow`; not unified into Analytics tab |
| **RSVP Conversion** | **Partially Implemented** | Funnel charts in `cc_v3_analytics_charts.dart` for private events |
| **Purchase Conversion** | **Partially Implemented** | Sell-through labeled as conversion; pageViews heuristic (`sold * 3`) |
| **Refund Analytics** | **Partially Implemented** | Finance `refundRatePct` / totals — not analytics trend product |
| **Check-in Analytics** | **Partially Implemented** | Door throughput 15m/60m; not analytics time-series |
| **No-show Analytics** | **Partially Implemented** | Derived remaining/issued in door/finance-adjacent models |
| **Timeline Analytics** | **Frontend Only** | Period chips exist; series not real |
| **Hourly Attendance** | **Not Implemented** | No hourly bucket API |
| **Audience Demographics** | **Not Implemented** | No organizer demographic model |
| **Repeat Attendee Insights** | **Not Implemented** | No cross-event attendee identity analytics |
| **Popular Ticket Tier** | **Partially Implemented** | Tier sales / donut charts from sold counts |
| **Revenue Breakdown** | **Partially Implemented** | Finance gross/net/fees; not analytics-composed chart pack |
| **Export Analytics** | **Not Implemented** (finance export adjacent) | Finance CSV only; no analytics export kind |
| **Event Comparison** | **Partially Implemented** | Portfolio `buildPortfolioAnalytics` client-side |
| **Historical Trends** | **Partially Implemented** | Portfolio / closing heuristics; weak visualization |

---

## 6. Existing vs missing vs hidden

### Existing (reuse — do not rebuild)

| Asset | Path |
|-------|------|
| EOS Analytics screen | `event_analytics_screen.dart` |
| Rich analytics tab | `analytics_tab_v3.dart` (**orphan**) |
| Charts | `cc_v3_analytics_charts.dart`, `EosSparkline`, `EosTimeSeriesChart` |
| Snapshot model / provider | `EventAnalyticsSnapshot`, `organizerAnalyticsProvider` |
| Portfolio analytics | `organizer_portfolio_models.dart`, portfolio workspace panel |
| Tier sales API | `GET events/:id/tiers/sales` |
| Finance summary / refund rate | `organizer-finance.service.ts` |
| Invitation funnel | `event-invitations.service.ts` `getStats` |
| Door counters / throughput | `event-operations.service.ts` door-summary |
| Workspace Analytics tab slot | `event_workspace.dart` |
| EOS rail Analytics destination | `EosRoleDestinations.organizer` |

### Hidden / orphaned

| Asset | Status |
|-------|--------|
| `AnalyticsTabV3` | Built; **never mounted** on Event Workspace |
| `EventModuleId.analytics` | `visible: false`; empty / no-op open |
| Workspace `_AnalyticsTabBridge` | Live stub with fake traffic series |
| Overview/Attendees/Vendors V3 tabs | Still largely orphaned (pattern note; not Phase 18 scope to remount all) |
| Super-admin `AnalyticsEngine` forecasts | Hardcoded demo — not organizer Phase 18 |

### Missing (Phase 18 targets)

| Gap | Priority |
|-----|----------|
| Organizer time-series / snapshot API (sales, revenue, check-ins, refunds) | **P0** |
| Replace synthesis in `organizerAnalyticsProvider` | **P0** |
| Mount `AnalyticsTabV3`; remove fake traffic bridge | **P0** |
| Wire invitation + check-in + finance KPIs into one view | **P0** |
| Honest conversion labeling (sell-through vs funnel) | **P0–P1** |
| Portfolio sparklines / API-backed rollups | **P1** |
| Analytics CSV export | **P1** |
| Unhide Event module Analytics deep-link | **P1** |
| Traffic sources / page views | **Out** (Large) |
| Demographics / repeat attendees / ML | **Out** |

---

## 7. Reuse analysis

| Layer | Reuse |
|-------|-------|
| **Routes** | Event Workspace Analytics tab; `/organizer` Analytics shell; portfolio workspace |
| **Screens / widgets** | Mount `AnalyticsTabV3`; keep `EventAnalyticsScreen` as shell picker |
| **Charts** | CC V3 analytics charts + EOS time-series/sparklines |
| **Providers** | Extend `organizerAnalyticsProvider` — do not fork |
| **Services** | Compose tiers/sales, finance summary, invitation stats, door summary; add thin analytics aggregation service |
| **Tables** | `ticket_orders`, `ticket_entitlements`, `event_check_ins`, `ticket_refund_cases`, `event_guests` / invitations |
| **Business rules** | Sell-through = sold/capacity; RSVP funnel from invite statuses; refund rate from finance |

**Avoid:** Second warehouse, parallel “insights” schema, Marketing attribution suite, Vendor BI reuse as organizer analytics.

---

## 8. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Ticket Commerce / Orders** | **Hard** — sales/revenue series |
| **Finance (17)** | **Hard** for refund/revenue honesty; soft gate = Phase 17 cert |
| **Check-ins / Operations (16)** | **Hard** for attendance series |
| **Invitations (15)** | **Hard** for RSVP funnel |
| **Organizer Dashboard / Workspace** | Soft — host surfaces already exist |
| **Reports / Export** | Soft — clone finance export pattern |
| **Vendor CRM** | Independent — do not block |
| **Page-view instrumentation** | Absent — out of Phase 18 |

---

## 9. Risks

| Risk | Mitigation |
|------|------------|
| Scope creeps into traffic/UTM/demographics | Hard out-list; rename fake traffic UI |
| Continues shipping synthesized sparklines | P0 API + provider replace; ban silent synthesis |
| Confuses sell-through with conversion | Explicit labels; optional true funnel later |
| Duplicates Finance tab | Analytics = trends/funnels; Finance = money ops |
| Starts before Phase 17 cert | STOP until Live QA / waiver |
| Vendor CRM stakeholders expect “Phase 18” | Document renumber: CRM → 19 |

**Architectural decision resolved:** Phase 18 = **Event Intelligence productization** on existing data + UI substrate.  
**IA decision resolved:** Workspace tab primary; EOS shell secondary (mirror Finance).

No further phase-level decisions block scope definition.

---

## 10. Implementation effort

| Module | Effort | Notes |
|--------|--------|-------|
| Nest organizer analytics snapshot + time-series | **Medium** | SQL over existing tables |
| Replace FE synthesis | **Small–Medium** | Provider + models |
| Mount AnalyticsTabV3 + unhide module | **Small** | Same as Finance mount |
| Unify invite / check-in / finance KPIs | **Medium** | Composition |
| Real sales/revenue/attendance charts | **Medium** | Reuse EosTimeSeriesChart |
| Portfolio comparison upgrade | **Medium** | Models exist |
| Analytics CSV export | **Small** | Clone finance export |
| Traffic / demographics / ML | **Large** | **Defer** |
| Vendor CRM productization | **Large** | **Phase 19** |
| **Sprint total (scoped)** | **Medium** | ~1 focused sprint |

---

## 11. Completion sprint roadmap

### Single sprint goal

**Organizers see real event performance — sales, RSVP, attendance, revenue/refund signals — on Event Workspace Analytics, backed by APIs over existing tables.**

### P0 (must ship)

1. Nest organizer analytics endpoints: event snapshot + daily (or weekly) series for sales qty, revenue, check-ins, refunds.  
2. Replace `organizerAnalyticsProvider` synthesis with API data.  
3. Mount `AnalyticsTabV3` on Event Workspace; delete/replace `_AnalyticsTabBridge` fake traffic chart.  
4. Compose invitation funnel stats + door attendance KPIs + finance refund/revenue into the tab.  
5. Honest labels: sell-through vs conversion; remove or hide “Traffic sources” until instrumented.  
6. Regression smoke: finance/tickets/invites/door unchanged.

### P1 (should ship)

7. Period controls wired to real series windows.  
8. Unhide Event module Analytics → open workspace Analytics.  
9. Portfolio comparison sparklines / clearer honesty.  
10. Analytics CSV export (sales / attendance / RSVP summary).  
11. Loading / empty / error polish on Analytics surfaces.

### P2 (defer if timeboxed)

12. Hourly check-in curve (if door timestamps support cheap aggregation).  
13. Popular tier ranking polish.  
14. Cross-link Finance tab ↔ Analytics for refund deep-dives.

### Explicitly out of sprint

- Traffic sources / UTM / page-view platform  
- Demographics / repeat attendee identity graph  
- ML forecasts / predictive “insights”  
- Vendor CRM productization (Phase **19**)  
- Marketing campaigns (Phase **20**)  
- Super-admin analytics rewrite  

---

## 12. Architecture question — Workspace tab vs standalone dashboard?

### Recommendation

**Primary: Event Workspace Analytics tab**  
**Secondary: EOS Organizer Analytics (`EventAnalyticsScreen`)**  
**Tertiary: Portfolio workspace for multi-event comparison**

| Surface | Role |
|---------|------|
| **Event Workspace → Analytics** | Canonical **per-event** intelligence (mount `AnalyticsTabV3`) — matches how Finance was productized in Phase 17 |
| **EOS `/organizer` → Analytics** | Event picker + same snapshot for organizers living in the shell |
| **Portfolio** | Cross-event comparison / historical rollups |

**Do not** make Analytics *only* a standalone dashboard feature: organizers already work inside Event Workspace for Tickets and Finance.  
**Do not** invent a third Reports app until time-series APIs exist.

This best fits the platform: tab slot already exists; rich `AnalyticsTabV3` already built; EOS rail already has Analytics; Finance set the mount pattern.

---

## 13. Roadmap hint (revised, non-binding)

| Phase | Theme |
|-------|--------|
| **17** | Organizer Finance & Event Financial Operations |
| **18** | Organizer Analytics & Event Intelligence (**this doc**) |
| **19** | Vendor marketplace CRM *(was 18)* |
| **20** | Marketing / communications *(was 19)* |
| **21+** | Deeper BI / traffic instrumentation / demographics |

---

## 14. Dependencies & stop conditions

| Gate | Status |
|------|--------|
| Phase 17 implementation | Complete (completion report) |
| Phase 17 Live QA / Certification | **Pending** — do not start Phase 18 build until certified (or waived) |
| Phase 18 scope doc | **This document** |
| Phase 18 implementation | **Not started** |

**STOP:** Do not begin Phase 18 coding, Phase 19 Vendor CRM, or Marketing delivery from this doc alone.

---

## 15. Final classification

### ✅ Phase 18 Scope Defined

**Phase 18 = Organizer Analytics & Event Intelligence**

Validates the proposed Analytics domain as the correct **next Organizer capability** after Finance: productize existing analytics UI with real series from commerce, invitations, check-ins, and finance — with **Event Workspace Analytics as the primary surface**. Vendor CRM is deferred to Phase 19 as a parallel marketplace track.
