# PHASE 21 — REPORTING & EXPORTS — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–20 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **14–18** architecture-frozen pending integrated Live QA — consume only  
**Business Operations Layer:** Phases **19–25** form one integrated layer; do not redesign completed earlier work; **one integrated Live QA after Phase 25**  
**Reporting rule:** Reporting is a **READ-ONLY consumer**. It aggregates existing systems. It does **not** become another source of truth. It must **not** invent metrics when canonical operational data is absent (show **Unavailable**).

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Organizer can create, publish, sell, invite, operate door, settle finance, measure performance, hire vendors, and (Phase 20 scope) grow audiences |
| **Proposed domain** | Reporting & Exports — **correct next Organizer capability** |
| **Prior roadmap** | Analytics (18) → Vendor CRM (19) → Marketing (20) → **Reporting (21)** |
| **Natural Phase 21** | Unified, read-only packaging of already-canonical business data into stakeholder-ready reports and file exports |
| **IA** | Primary = Organizer **Export Center / Reports** surface (Event Workspace + portfolio); secondary = deep-links into Finance / Analytics / Ops / CRM / Marketing tabs (do not replace them) |
| **Overall** | **✅ Phase 21 Scope Defined** |

Nothing else should precede Reporting in the Organizer business lifecycle. Compliance/audit needs are **exports of existing truth**, not a separate domain before this phase. Team collaboration, settings, and AI assistants are not the next closed-loop business capability.

**Soft sequencing note:** Phase 20 Marketing is **scoped but not yet implemented**. Marketing *reports* in Phase 21 must consume Marketing when it exists; until then, Marketing report kinds are **Unavailable** or deferred — never invented. This does **not** block defining Phase 21 scope.

---

## 2. Business flow review — next missing capability

```
Create (12)
  → Tickets / Sell (13–14)
  → Invite (15)
  → Operate (16)
  → Finance (17)
  → Analytics (18)
  → Vendor CRM (19)
  → Marketing (20)
  → ??? Package evidence for stakeholders
```

| After Phase 20 (scoped) | Organizer can… | Still missing |
|-------------------------|----------------|---------------|
| Operate & settle | Run door, money, vendors | Take **portable evidence** off-platform (accountant, sponsor, board) |
| Analytics | See intelligence in-app | Bundle multi-domain snapshots into **named report packs** |
| Finance / Analytics exports | Point exports per tab (CSV clipboard) | **One Export Center**, consistent formats, portfolio packs, attendance/guest/vendor packs |
| Marketing (when built) | Run growth actions | Attribute and export campaign outcomes **without a second warehouse** |

**Next missing business capability:** Organizer-facing **Reporting & Exports** — answer “how do I package and leave with trustworthy evidence of what happened?” by composing Operations, Finance, Analytics, Marketing, and Vendor CRM — without inventing a second metrics store.

---

## 3. Phase definition

### Official Phase Name

**Phase 21 — Reporting & Exports**

### Business Goal

Give organizers a single, trustworthy way to **generate, filter, and download** business evidence (event, attendance, financial, marketing, vendor, portfolio) for stakeholders, using only canonical data already produced by Phases 13–20.

### Technical Goal

Introduce a thin **Reporting Engine** (read-only) that:

1. **Composes** existing Nest services / GETs (Finance, Analytics, Ops, Invitations, Orders, Vendor CRM, Marketing when present).  
2. **Reuses** existing CSV/XLS packers (`FinanceExportService` pattern) and Flutter `ExportHelper`.  
3. **Surfaces** an Organizer Export Center + event report packs.  
4. **Never** duplicates Analytics KPIs, Finance ledgers, or Ops check-in rules.

### Primary User Journeys

| ID | Journey |
|----|---------|
| J1 | Organizer opens **Reports / Export Center** for an event and downloads a finance pack (orders / transactions / refunds / summary) |
| J2 | Organizer downloads an **event performance** pack (sales + attendance + RSVP summary) from Analytics-backed data |
| J3 | Organizer exports **attendance / door** detail (checked-in, no-shows) from Ops entitlements + check-ins |
| J4 | Organizer exports **guest / invitation** list with RSVP status |
| J5 | Organizer exports **vendor CRM** pipeline snapshot for an event |
| J6 | Organizer runs a **portfolio / multi-event** summary export (reuse portfolio analytics) |
| J7 | Organizer chooses format (CSV primary; XLS where packers exist; PDF/print as P2 where justified) |
| J8 | Organizer deep-links from a report card into Finance / Analytics / Ops / Vendors / Marketing (consume UI, do not fork) |

### Success Criteria

- [ ] One Organizer **Export Center** (or equivalent Reports hub) discoverable from Event Workspace / Organizer home  
- [ ] All export kinds resolve to **canonical** services — no parallel metric SQL that contradicts Analytics/Finance  
- [ ] Finance + Analytics existing exports remain the source for those domains (wrapped, not rewritten)  
- [ ] Attendance, invitation, and vendor packs available or explicitly **Unavailable** with dependency cited  
- [ ] Marketing packs only when Phase 20 data exists; otherwise Unavailable  
- [ ] CSV downloads work via real file download (not clipboard-only) using `ExportHelper` where applicable  
- [ ] No invented page-views, engagement rates, or estimated revenue  
- [ ] Frozen phases 14–18 untouched except read/consume  

### Why this naturally follows Phase 20

Marketing closes the **growth** loop (fill the room). Reporting closes the **accountability** loop (prove what happened to people outside the app). Stakeholders need packages after the business has been run, measured, hired, and promoted — not before.

---

## 4. Feature breakdown (audit)

| Capability | Classification | Evidence | Phase 21 stance |
|------------|----------------|----------|-----------------|
| **Executive Reports** | **Not Implemented** (organizer) | Super-admin `analytics_360` “Executive Reporting Center” + Export PDF is UI/mock, not organizer truth | P2 portfolio executive pack over portfolio analytics — **read-only** |
| **Event Reports** | **Partially Implemented** | Analytics snapshot + CSV summary (`OrganizerAnalyticsService.exportEventCsv`); Finance summary export | Unify into **event report pack**; do not rebuild Analytics |
| **Attendance Reports** | **Backend/UI data only** | Analytics attendance KPIs; Ops check-ins; **no dedicated attendance export** | P0/P1 export kind over check-ins + entitlements |
| **Financial Reports** | **Fully Implemented** (event-scoped) | `GET events/:id/finance/export/:kind` + `FinanceTabV3` | **Consume / wrap** in Export Center |
| **Marketing Reports** | **Not Implemented** | Phase 20 scope only; no campaign tables in Nest for organizer | Defer kinds until Marketing lands; Unavailable otherwise |
| **Vendor Reports** | **Partially Implemented** (insights in CRM UI) | Vendor CRM pipeline stats / timeline APIs; **no CSV export** | P1 CRM snapshot export |
| **Export Center** | **Not Implemented** | Exports buried in Finance + Analytics tabs only | **P0** hub |
| **Scheduled Reports** | **Not Implemented** | No cron/email report jobs for organizers | **Out of scope / P3** unless approved |
| **Saved Reports** | **Not Implemented** | No saved filter presets store | **P2** optional |
| **CSV Export** | **Partially Implemented** | Finance + Analytics CSV; often clipboard on mobile | Standardize file download via `ExportHelper` |
| **Excel Export** | **Partially Implemented** (backend) | `FinanceExportService` xlsx/SpreadsheetML; admin + organizer format query | Surface in Export Center for finance kinds |
| **PDF Export** | **Not Implemented** (organizer) | Vendor/super-admin snackbars / buttons are mocks | **P2** print-friendly HTML/PDF only if needed; do not block CSV |
| **Print Views** | **Not Implemented** | No dedicated print CSS/report view | **P2** |
| **Report Templates** | **Not Implemented** | No template registry | Ship **fixed packs** (finance, performance, attendance, guests, vendors, portfolio); custom templates later |
| **Custom Report Filters** | **Partially Implemented** | Analytics period params; finance kinds | Reuse domain filters; no free-form query builder in Phase 21 |
| **Multi-event Reports** | **Partially Implemented** | `GET organizers/me/analytics/portfolio` | Add portfolio CSV pack |
| **Portfolio Reports** | **Partially Implemented** | Portfolio analytics JSON | Export + executive summary card |
| **Operational Reports** | **Not Implemented** (export) | Ops feed / door summary in UI; seating `GET seating/export` exists | Attendance + optional ops incident list; seating already backend |
| **Audit Reports** | **Backend Only** (admin/compliance adjacent) | Admin finance exports; Phase 8 compliance notes | Organizer audit = export of orders/refunds/check-ins already canonical; no new audit ledger |

---

## 5. Existing implementation (keep / consume)

### NestJS

| Asset | Role |
|-------|------|
| `FinanceExportService` | CSV + SpreadsheetML packers; `exportForOrganizerEvent` |
| `OrganizerFinanceController` `GET events/:id/finance/export/:kind` | Organizer finance exports |
| `FinanceExportController` `GET admin/finance/exports/:kind` | Admin — do not promote as organizer UI |
| `OrganizerAnalyticsService.exportEventCsv` | Event intelligence CSV |
| `EventsController` `GET events/:id/analytics/export` | Analytics export route |
| `GET organizers/me/analytics/portfolio` | Multi-event rollup |
| `OrganizerFinanceService` / summary + txs | Money truth |
| `EventOperationsService` / check-ins | Attendance truth |
| Invitations APIs | Guest / RSVP truth |
| `VendorCrmService` / pipeline + timeline | Vendor truth |
| `GET events/:id/seating/export` | Seating layout export (adjacent) |

### Flutter

| Asset | Role |
|-------|------|
| `FinanceTabV3` `_ExportRow` | Finance export UX |
| `AnalyticsTabV3` Export CSV | Analytics export UX |
| `organizer_finance_api.dart` / `organizer_analytics_api.dart` | HTTP clients |
| `ExportHelper` (+ web/io) | Real file download utility |
| `eos_data_table.dart` Excel/PDF menu | Partial table export pattern (CSV via helper) |
| Event Workspace tabs | Deep-link targets (Finance, Analytics, Ops, Vendors) |

---

## 6. Missing implementation

| Gap | Priority | Notes |
|-----|----------|-------|
| Organizer **Export Center / Reports hub** | **P0** | Single IA entry; cards deep-link + download |
| Unified **report pack** API or facade | **P0** | Thin composer over existing services — not a warehouse |
| Attendance / door detail CSV | **P0–P1** | From entitlements + `event_check_ins` |
| Guest / invitation list CSV | **P1** | From invitations module |
| Vendor CRM pipeline CSV | **P1** | From `VendorCrmService` |
| Portfolio / multi-event CSV | **P1** | From portfolio analytics |
| Replace clipboard-only with `ExportHelper` downloads | **P1** | Finance + Analytics tabs + new hub |
| Surface XLS for finance kinds in UI | **P1** | Backend already supports `format=xlsx` |
| Marketing report kinds | **P2** | After Phase 20 implementation |
| PDF / print views | **P2** | Optional; CSV remains primary |
| Saved report presets | **P2** | Optional |
| Scheduled / emailed reports | **P3 / out** | Needs ops + privacy design — STOP if required |

---

## 7. Hidden / mock / backend-only

| Item | Classification | Evidence |
|------|----------------|----------|
| Admin finance exports | **Backend Only** (admin) | `FinanceExportController` |
| Finance XLS format | **Implemented but Hidden** (organizer) | Query `format=xlsx` exists; UI uses CSV clipboard |
| Seating layout export | **Partially wired** | Nest + customer seating screen; not Organizer Export Center |
| Super-admin Executive Reporting PDF | **Frontend Only / mock** | `analytics_360_workspace_screen.dart` |
| Vendor “download PDF” | **Frontend Only / mock** | Snackbar / DAM Framework copy |
| EOS table “Export as PDF” | **Partially Implemented** | Menu item; CSV path via `ExportHelper` — PDF not real report engine |
| Analytics chart → PDF | **Not Implemented** | Explicitly deferred in Phase 18 completion |

---

## 8. Reuse analysis (do not duplicate)

| Domain | Reuse | Do not |
|--------|-------|--------|
| **Analytics** | Snapshot + portfolio + existing CSV | Second intelligence SQL / charts warehouse |
| **Finance** | `FinanceExportService` + organizer export routes | New ledger or refund math |
| **Operations** | Check-in + entitlement queries / door summaries | Parallel check-in store |
| **Orders / Commerce** | Order/line tables via finance/analytics services | Invent sales-by-tier outside existing analytics tiers |
| **Vendors** | `VendorCrmService` views | New CRM stage machine |
| **Invitations** | Invitation list/status APIs | New guest database |
| **Marketing** | Phase 20 campaign APIs when present | Fake open/click rates |
| **Export infra** | `FinanceExportService.pack`, `ExportHelper` | Per-tab one-off string builders forever |
| **Controllers / routes** | Wrap or add thin `organizer-reports` facade | Parallel `/analytics2` |
| **Providers / DTOs** | Existing finance/analytics/CRM providers | Duplicate models with different numbers |
| **Business rules** | Consume frozen 14–18 rules | Replace settlement, RSVP, or door rules |

---

## 9. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Finance (17)** | **Hard** — financial report packs |
| **Analytics (18)** | **Hard** — performance packs / portfolio |
| **Operations (16)** | **Hard** — attendance packs |
| **Orders / Ticketing (13–14)** | **Hard** — sales rows via finance/analytics |
| **Invitations (15)** | **Hard** — guest/RSVP packs |
| **Vendor CRM (19)** | **Soft–Hard** for vendor packs; hub can ship without them first |
| **Marketing (20)** | **Soft** — marketing packs only when implemented |
| **Architecture freeze 14–18** | **Hard** — consume only |
| **Email/scheduler platform** | Soft — only if scheduled reports approved |

**If a frozen phase must change to enable Reporting:** STOP. Document the dependency. Wait for approval. Prefer Unavailable over schema invention.

---

## 10. Risks

| Risk | Mitigation |
|------|------------|
| Reporting becomes a second Analytics | Hub = packs + downloads; charts stay in AnalyticsTabV3 |
| Invented metrics for “complete” PDFs | Unavailable rule; ban estimates |
| Duplicating Finance export SQL | Always call `FinanceExportService` |
| Scope creep into scheduled email + custom BI | Fixed packs first; schedule out of default scope |
| Clipboard-only “exports” fail stakeholder needs | Mandate `ExportHelper` file download |
| Marketing reports before Marketing exists | Soft dependency; mark Unavailable |
| PDF engine project | Keep CSV/XLS primary; PDF P2 |
| Touching frozen publish/invite/ops/finance/analytics workflows | Read-only composer only |

---

## 11. Implementation effort

| Module | Effort | Notes |
|--------|--------|-------|
| Export Center IA + deep-links | **Small–Medium** | Workspace / home entry |
| Thin Nest reports facade (compose existing) | **Medium** | No new truth tables |
| Attendance + guests + vendor CSV kinds | **Medium** | New packers, same patterns |
| Wire `ExportHelper` + XLS in UI | **Small** | Existing backend |
| Portfolio pack | **Small–Medium** | Portfolio analytics → CSV |
| Marketing packs | **Small** after Phase 20 | Else skip |
| PDF / print / scheduled | **Large** | Defer |

**Overall Phase 21 (P0–P1):** **Medium**  
**With PDF + schedules + custom builder:** **Large** — do not default into scope

---

## 12. Completion Sprint roadmap (proposed)

### Sprint A — Hub + honesty (P0)

1. Organizer Export Center / Reports entry (Event Workspace + portfolio).  
2. Cards wrapping **existing** Finance + Analytics exports (no new math).  
3. File download via `ExportHelper`; keep tab exports working.  
4. Explicit Unavailable for missing packs (marketing, etc.).

### Sprint B — Operational & CRM packs (P0–P1)

5. Attendance / door detail CSV (check-ins + entitlements).  
6. Guest / invitation RSVP CSV.  
7. Vendor CRM pipeline CSV.  
8. Surface finance `format=xlsx` in hub.

### Sprint C — Portfolio & polish (P1–P2)

9. Portfolio / multi-event CSV from analytics portfolio.  
10. Optional print-friendly event summary view.  
11. Marketing packs only if Phase 20 data exists.  
12. Saved presets optional; **no** scheduled email without approval.

---

## 13. Architecture question — canonical Reporting lifecycle

```
Operations (16)
    ↓  entitlements, event_check_ins, door feed, incidents
Finance (17)
    ↓  orders, payments, refunds, settlements, payouts
Analytics (18)
    ↓  read-only composition → snapshots, series, portfolio
Marketing (20)
    ↓  campaigns / audiences / promo outcomes (when present)
Vendor CRM (19)
    ↓  requests, stages, contracts, timeline
        ↓
Reporting Engine (Phase 21 — READ ONLY)
    ↓  composes packs; never writes business truth
Exports (CSV / XLS / optional PDF)
    ↓
Organizer (Export Center + stakeholder files)
```

### Modules reused at each step

| Step | Reused modules |
|------|----------------|
| **Operations** | `EventOperationsService`, check-in tables, door summary UIs (read) |
| **Finance** | `OrganizerFinanceService`, `FinanceExportService`, finance routes / `FinanceTabV3` |
| **Analytics** | `OrganizerAnalyticsService`, analytics export route, `AnalyticsTabV3`, portfolio GET |
| **Marketing** | Phase 20 APIs / providers when built; else Unavailable |
| **Vendor CRM** | `VendorCrmService`, vendor-operations controller, `VendorsTabV3` providers |
| **Reporting Engine** | New thin composer + Export Center only — **no** parallel warehouse |
| **Exports** | `FinanceExportService.pack` / CSV helpers, `ExportHelper`, existing attachment headers |
| **Organizer** | Event Workspace deep-links; Organizer home; clipboard→file download upgrade |

**Invariant:** Numbers in a report must match Finance/Analytics/Ops screens for the same filters. Divergence = defect, not a new metric definition.

---

## 14. Out of scope (explicit)

- Redesigning Publishing, Invitations, Live Ops, Finance, or Analytics  
- Duplicating Analytics charts or Finance settlement workflows  
- Inventing engagement / traffic / demographic metrics  
- Full BI / custom SQL report builder  
- Scheduled email reports (unless separately approved)  
- Promoting Super-admin mock “Executive Reporting” as organizer truth  
- Vendor / DAM fake PDF downloads as completion criteria  

---

## 15. Final result

**✅ Phase 21 Scope Defined**
