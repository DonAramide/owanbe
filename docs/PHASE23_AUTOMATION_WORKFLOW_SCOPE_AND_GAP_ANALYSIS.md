# PHASE 23 — AUTOMATION & WORKFLOW ENGINE — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–22 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **14–22** architecture-frozen pending integrated Live QA — consume only  
**Business Operations Layer:** Phases **19–25** form one integrated layer; **one integrated Live QA after Phase 25**  
**Automation rule:** Automation is an **orchestration layer**. It must **not** own business data, replace Finance / Ops / CRM / Reporting rules, or invent metrics. It **triggers** existing workflows and **reuses** existing services.

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Organizer can create → operate → settle → measure → hire → report → delegate via Organization & Team |
| **Proposed domain** | Automation & Workflow Engine — **correct next Organizer capability** |
| **Prior roadmap** | Organization (22) → **Automation (23)** → Integrations (24) → Hardening (25) |
| **Natural Phase 23** | Reduce manual ops by reacting to business events and schedules — without a second source of truth |
| **IA** | Primary = Organizer **Automations** hub (rules catalog + history); secondary = deep-link Ops / Finance / CRM / Reports; do **not** promote Super-admin Workflow Studio stub as organizer truth |
| **Trigger model** | **Both** event-driven **and** schedule-driven (see §16) |
| **Overall** | **✅ Phase 23 Scope Defined** |

Nothing else should precede Automation in the Business Ops layer. Integrations (24) need stable hooks; Hardening (25) needs measurable automation readiness. Marketing (20) remains planned — marketing automations stay Unavailable until Marketing exists.

**Soft sequencing note:** Activate / wire existing `workflow_*` tables (`040_enterprise_workflows.sql`) as the persistence substrate where possible; do not invent a parallel workflow warehouse. Flutter `WorkflowEngine` / Workflow Studio are **stubs** — Nest must become the source of truth.

---

## 2. Business flow review — where automation adds value

```
Create → Publish → Sell → Invite → Operate → Finance → Analytics
  → Vendor CRM → Marketing → Reporting → Organization
  → ??? Remove repetitive human glue between systems
```

| After Phase 22 | Organizer can… | Still missing |
|----------------|----------------|---------------|
| Run full business loop | Do each step manually | Auto-react when tickets sell, RSVPs change, refunds escalate, vendors accept |
| Notify guests / buyers | Hardcoded call sites | Configurable **rules** (when X → notify Y / remind Z) |
| Program reminders | Lazy on-read program offsets | Reliable **scheduled** reminder delivery |
| Reporting | On-demand Export Center | Optional scheduled export packs (consume Phase 21) |
| Team | Delegate work | Auto-assign / notify staff on capability events |

**Highest-value automation zones (Phase 23 focus):**

1. **Transactional reminders** — invitation RSVP nudge, door day-of, program offsets → `NotificationService`  
2. **Commerce / finance signals** — ticket issued, refund status, payout/escrow alerts → notify organizer / team  
3. **Vendor CRM signals** — stage accepted / declined → notify organizer  
4. **Reporting packs** — schedule Export Center packs (read-only consume)  
5. **Approval routing overlays** — observe refund/vendor transitions; do **not** replace domain state machines  

**Next missing capability:** Organizer-facing **Automation & Workflow Engine** — answer “when this happens (or at this time), run these actions on existing systems.”

---

## 3. Phase definition

### Official Phase Name

**Phase 23 — Automation & Workflow Engine**

### Business Goal

Let organizers define and monitor **automation rules** that orchestrate existing platform capabilities (notify, remind, export, escalate awareness) so Business Operations run with less manual glue — without changing canonical domain logic.

### Technical Goal

Introduce a thin Nest **Workflow / Automation orchestrator** that:

1. **Listens** to business events (emit from existing services) and **runs** schedule ticks.  
2. **Evaluates** conditions against rule definitions (reuse / activate `workflow_definitions` where fit).  
3. **Dispatches actions** only via existing services (`NotificationService`, Reporting export APIs, AuditLog, in-app notifications).  
4. **Persists** instance/history (reuse `workflow_instances` / `workflow_history` or approved thin extension).  
5. **Surfaces** Organizer Automations UI (catalog, enable/disable, history) — not a second CRM/Finance.

### Primary User Journeys

| ID | Journey |
|----|---------|
| J1 | Organizer enables “RSVP reminder 48h before event” → schedule tick → `NotificationService` |
| J2 | Ticket purchase completes → business event → rule → confirmation already exists; optional organizer digests |
| J3 | Vendor accepts CRM request → event → notify organizer team members with `team.manage` / ops capability |
| J4 | Refund moves to under_review → event → notify finance-capable org members (observe refund SM; do not rewrite it) |
| J5 | Organizer schedules weekly portfolio report pack → schedule → Reporting export → download/email Unavailable if email attachment not ready |
| J6 | Organizer views **execution history** (success / skip / fail) and retries failed notification actions only |
| J7 | Organizer disables a rule; no further runs |

### Success Criteria

- [ ] Automation never writes parallel ticket/finance/RSVP/vendor truth  
- [ ] Actions call existing services only  
- [ ] Event-driven **and** schedule-driven paths both exist  
- [ ] Execution history persisted and visible to organizer  
- [ ] Super-admin Workflow Studio not required for organizer product  
- [ ] Frozen domains untouched except approved emit hooks (thin, additive)  
- [ ] Marketing automations Unavailable until Phase 20  
- [ ] No Bull/Redis requirement unless separately approved — prefer Nest schedule + DB job rows for MVP  

### Why this naturally follows Phase 22

Organization & Team creates **who** may act. Automation creates **when** the platform acts on their behalf. Staff need notifications and reminders routed correctly after membership exists. Integrations (24) then expose the same orchestrator outward.

---

## 4. Feature breakdown (audit)

| Capability | Classification | Evidence | Phase 23 stance |
|------------|----------------|----------|-----------------|
| **Workflow Builder** | **Frontend Only** (stub) | `workflow_studio_screen.dart` + in-memory `workflow_engine.dart` | P2 thin rule editor; do not ship studio as truth |
| **Automation Rules** | **Frontend Only** | Hardcoded `RuleEngine` guards in Flutter | **P0** Nest rule registry |
| **Event Triggers** | **Partially / Hidden** | Flutter `PlatformEventBus` unused; Nest `realtime-broadcast` = SSE only; no EventEmitter2 | **P0** Nest domain emit + subscribers |
| **Conditions** | **Frontend Only** | Simulated guards | **P0** simple condition DSL (field/op/value) |
| **Actions** | **Frontend Only** | `AutomationEngine` logs only | **P0** real adapters → Notification / Report / Audit |
| **Notifications** | **Partially Implemented** | Nest `NotificationService` immediate email/sms/push(log) | **Consume**; add delayed send via schedule jobs |
| **Scheduled Jobs** | **Not Implemented** | No `@nestjs/schedule` / Bull; `setInterval` finance timeout; program reminders lazy on GET | **P0** Nest ScheduleModule **or** DB due-jobs sweeper |
| **Approval Workflows** | **Partially Implemented** | Refund SM + vendor CRM stages; SQL seeds unused | **Observe** domain SMs; do not replace |
| **Reminder Workflows** | **Partially Implemented** | `event_program_reminders` + lazy `processDueReminders` | **P0** schedule-backed delivery via NotificationService |
| **Ticket Workflows** | **Partially Implemented** | Hardcoded confirmation on capture | Optional rules; keep capture path canonical |
| **Invitation Workflows** | **Partially Implemented** | Send on invite; no nudge engine | **P1** RSVP reminder rules |
| **Vendor Workflows** | **Partially Implemented** | CRM notify on stage | **P1** rule templates on CRM events |
| **Finance Notifications** | **Partially Implemented** | Alerts service + timeout sweeps | **P1** rule-ize alerts; keep ledger rules frozen |
| **Reporting Automation** | **Not Implemented** | Phase 21 deferred schedules | **P1** schedule Export Center packs |
| **Audit Automation** | **Backend Only** | `AuditLogService` on mutations | **Consume** for execution + team events |
| **Retry Policies** | **Partially Implemented** | Email provider retries; payout manual retry | **P1** action-level retry for notification failures |
| **Workflow History** | **Hidden** (SQL unused) + Flutter in-memory | `workflow_history` table; no Nest usage | **P0** persist + organizer UI |
| **Execution Logs** | **Frontend Only** | Session logs in Flutter engine | **P0** Nest history |

---

## 5. Existing implementation (keep / consume)

| Asset | Role |
|-------|------|
| `NotificationService` + `notification_deliveries` | Canonical outbound notify |
| `EmailService` / SMS providers | Channel dispatch |
| Ticket capture / entitlements notifications | Imperative hooks to preserve |
| `EventInvitationsService` sends | Canonical invite send |
| `VendorCrmService` stage notifications | Canonical CRM notify |
| Finance alerts / `FinanceTimeoutService` | Keep sweeps; emit events for rules |
| `event_program_reminders` + program service | Reminder data model |
| `AuditLogService` | Execution / mutation audit |
| `040_enterprise_workflows.sql` tables + seeds | Persistence substrate candidate |
| Phase 21 Reporting export APIs | Scheduled pack actions |
| Phase 22 team / capabilities | Route notifications to capable members |
| Flutter Workflow Studio | Reference UX only — not product truth |

---

## 6. Missing implementation

| Gap | Priority | Notes |
|-----|----------|-------|
| Nest Workflow / Automation module | **P0** | Definitions, instances, runs |
| Domain event emit from key services | **P0** | Additive hooks only |
| Schedule runner (cron or due-jobs) | **P0** | |
| Action adapters (notify, audit, report export) | **P0** | |
| Organizer Automations UI + history | **P0–P1** | |
| Delayed / scheduled notification jobs | **P0** | |
| RSVP / door / CRM rule templates | **P1** | |
| Reporting schedule packs | **P1** | |
| Action retry + dead-letter view | **P1** | |
| Visual workflow builder | **P2 / defer** | Fixed templates first |
| Marketing campaign automations | **Defer** | Needs Phase 20 |
| Bull/Redis workers | **Defer** unless scale requires | |

---

## 7. Hidden / mock / backend-only

| Item | Classification | Evidence |
|------|----------------|----------|
| `workflow_definitions` / `instances` / `history` | **Hidden** (schema unused by Nest) | `040_enterprise_workflows.sql` |
| Super-admin Workflow Studio | **Frontend Only** stub | `workflow_studio_screen.dart` |
| Flutter `WorkflowEngine` / `AutomationEngine` | **Frontend Only** simulated | `workflow_engine.dart` |
| Flutter `PlatformEventBus` | **Hidden** (no Workflow subscribers) | `platform_event_bus.dart` |
| Copilot “Decision trigger sent to Workflow Engine” | **Frontend Only** mock | `copilot_workspace_screen.dart` |
| Escrow `triggered_by = 'cron'` | **Backend schema label** | No Nest cron |
| AI negotiation tables (`044`) | **Separate stack** — not Phase 23 engine | Do not merge |

---

## 8. Reuse analysis (do not duplicate)

| Domain | Reuse | Do not |
|--------|-------|--------|
| **Notifications** | `NotificationService.send` | Parallel mailer inside workflow |
| **Invitations** | Invitation services + guest status | Second RSVP store |
| **Finance** | Observe refund/payout events; alerts | Rewrite refund SM / ledger |
| **Analytics** | Read snapshots only if needed | Invent KPIs |
| **Vendor CRM** | Stage events from CRM service | Parallel vendor pipeline |
| **Reporting** | Export Center pack APIs | Second report engine |
| **Organization** | Capability-based recipients | Bypass membership |
| **Background jobs** | Pattern from finance timeout + program reminders | Ad-hoc intervals per feature forever |
| **Workflow schema** | Prefer `040` tables | Second `automations2` warehouse |
| **Audit** | `AuditLogService` | Separate opaque log only |

**Orchestration invariant:** Domain services remain authoritative. Automation **calls** them; it does not **become** them.

---

## 9. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Notifications** | **Hard** — primary action channel |
| **Finance** | Soft–Hard for finance alerts; freeze ledger rules |
| **Analytics** | Soft — rarely needed for conditions |
| **Vendor CRM** | Soft–Hard for CRM event templates |
| **Reporting** | Soft for scheduled packs |
| **Organization / Team** | Soft–Hard for recipient routing |
| **Workspace / Event** | Soft — event-scoped rules |
| **Invitations / Ops** | Hard for reminder templates |
| **Schedule infrastructure** | **Hard** — greenfield Nest schedule or DB sweeper (approved addition, not redesign of frozen domains) |
| **Emit hooks in frozen services** | **Gate** — additive event emit only; STOP if business rules must change |

### Dependency requiring approval before code

| Change | Why |
|--------|-----|
| Additive `emit('ticket.issued', …)` style hooks inside frozen commerce/invite/CRM/finance services | Engine cannot react without signals; must not alter business outcomes |
| Introduce `@nestjs/schedule` (or equivalent due-job table + sweeper) | No production scheduler exists today |

---

## 10. Risks

| Risk | Mitigation |
|------|------------|
| Workflow engine becomes second CRM/Finance | Actions = adapters only; no domain writes except via existing services |
| Promoting Flutter studio as production | Nest API is source of truth; studio optional later |
| Duplicate orchestration with hardcoded notifies | Keep existing notifies; rules add-on / gradually template |
| Unbounded visual builder scope | Ship **fixed templates** + enable/disable first |
| Cron without idempotency | Run keys + `workflow_history`; skip if already succeeded |
| Marketing automations invented | Unavailable until Phase 20 |
| Bull/Redis prematurely | Prefer ScheduleModule + DB jobs for MVP |
| Touching frozen refund SM | Observe transitions; do not replace |

---

## 11. Implementation effort

| Module | Effort | Notes |
|--------|--------|-------|
| Nest automation module + wire `040` tables | **Medium** | |
| Domain event emit hooks | **Medium** | Many call sites, thin changes |
| Schedule runner + delayed notify | **Medium** | |
| Action adapters | **Small–Medium** | |
| Organizer Automations UI + history | **Medium** | |
| Template pack (RSVP, door, CRM, finance alert, report) | **Medium** | |
| Visual builder | **Large** | Defer |
| Full queue platform (Bull) | **Large** | Defer |

**Overall Phase 23 (P0–P1):** **Medium–Large**  
**With visual builder + Redis workers:** **Large** — do not default into scope  

---

## 12. Completion Sprint roadmap (proposed)

### Sprint A — Engine foundation (P0)

1. Approve emit-hook + scheduler approach.  
2. Nest Automation module over `workflow_*` (or approved extension).  
3. Schedule runner (Nest Schedule **or** due-jobs sweeper).  
4. Action: `NotificationService` + `AuditLogService`.  
5. Persist execution history.

### Sprint B — Event-driven templates (P0–P1)

6. Emit: ticket issued, invite RSVP changed, vendor stage changed, refund status changed.  
7. Organizer rule catalog (enable template rules).  
8. Recipient resolution via Phase 22 capabilities where relevant.

### Sprint C — Schedule + reporting (P1)

9. Program / RSVP / door reminder schedules → NotificationService.  
10. Scheduled Reporting packs (consume Phase 21).  
11. Retry failed notification actions; history UI.  
12. Explicit Unavailable: Marketing, visual builder, Bull.

---

## 13. Architecture question — canonical Automation lifecycle

```
Business Event (or Schedule Tick)
        ↓
Workflow Engine (definitions / instances — orchestration only)
        ↓
Conditions (rule guards — no invented business truth)
        ↓
Actions (adapters)
        ↓
Notifications (and/or Reporting export / in-app notify)
        ↓
Business Systems (Tickets, Invitations, Ops, Finance, CRM, Reports, Team)
        ↓
Audit Log (AuditLogService + workflow_history)
```

### Modules reused at each step

| Step | Reused modules |
|------|----------------|
| **Business Event** | Additive emits from Ticket Commerce, Invitations, Ops, Finance alerts, Vendor CRM; schedule ticks from Nest Schedule / due-jobs |
| **Workflow Engine** | Nest Automation module; prefer `workflow_definitions` / `workflow_instances` |
| **Conditions** | Thin condition evaluator; optional read of canonical status fields |
| **Actions** | Adapters only |
| **Notifications** | `NotificationService`, email/SMS infra, in-app `notifications` |
| **Business Systems** | Existing Phase 13–22 services — never duplicated |
| **Audit Log** | `AuditLogService` + `workflow_history` |

**Invariant:** If an action would require new business data, show **Unavailable** or STOP for approval — do not invent it.

---

## 14. Event-driven vs schedule-driven (explicit answer)

**Phase 23 must support both.**

| Mode | When | Infrastructure to use / introduce |
|------|------|-----------------------------------|
| **Event-driven** | React to ticket purchases, RSVP changes, vendor stage changes, refund transitions, check-ins | **Introduce** a thin Nest domain-event bus (or `@nestjs/event-emitter`) + **additive emit hooks** in existing services. Do **not** use Flutter `PlatformEventBus` as server truth. SSE `realtime-broadcast` stays for live feed only. |
| **Schedule-driven** | Reminders before event, digest emails, scheduled report packs, delayed notify | **Introduce** `@nestjs/schedule` **or** a `automation_jobs` / due-row sweeper (pattern already hinted by finance `setInterval` and program `processDueReminders`). Prefer durable DB due-jobs over process-local `setInterval` for production. Extend `NotificationService` with **job-scheduled** send (not inline delay in HTTP). |

| Do not | Why |
|--------|-----|
| Event-only | Misses reminders / report schedules — core organizer value |
| Schedule-only | Misses real-time CRM/commerce reactions |
| Bull/Redis as default MVP | Large ops jump; approve later if volume demands |
| Replacing domain state machines with the engine | Violates freeze / orchestration rule |

**Recommended MVP split:**  
- **P0 event-driven:** ticket / invite / CRM / refund signals → notify  
- **P0 schedule-driven:** reminder due-jobs → `NotificationService`  
- **P1 schedule-driven:** Reporting packs  

---

## 15. Out of scope (explicit)

- Redesigning Publishing, Invitations, Live Ops, Finance, Analytics, Vendor CRM, Reporting, Organization  
- Replacing refund or CRM state machines  
- Visual BPMN builder as P0  
- Marketing automation (needs Phase 20)  
- AI negotiation engine (`044`) as workflow truth  
- Inventing engagement / conversion metrics  
- Promoting Super-admin Workflow Studio mocks as organizer product  

---

## 16. Final result

**✅ Phase 23 Scope Defined**
