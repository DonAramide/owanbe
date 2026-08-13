# PHASE 25 — PLATFORM HARDENING & BUSINESS OPERATIONS READINESS — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–24 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **14–24** architecture-frozen pending integrated Live QA — consume only  
**Business Operations Layer:** Phases **19–25** form one integrated layer; **one integrated Live QA after Phase 25**  
**Hardening rule:** Phase 25 **stabilizes** existing capabilities. It must **not** redesign frozen domains, invent business data, or introduce parallel workflows.

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Business Ops loop is complete through Integrations (24) |
| **Proposed domain** | Platform Hardening & Business Operations Readiness — **correct final phase** |
| **Prior roadmap** | Integrations (24) → **Hardening (25)** → integrated Live QA / certification |
| **Natural Phase 25** | Stability, security consistency, performance, observability, UX readiness, certification prep |
| **IA** | No new primary IA — harden existing Organizer Workspace + Super-admin Hub surfaces |
| **Overall** | **✅ Phase 25 Scope Defined** |

Phase 25 is **not** a feature phase. Nothing new should precede integrated certification. Remaining work is readiness gaps inside the frozen architecture.

---

## 2. Platform readiness objective

### Official Phase Name

**Phase 25 — Platform Hardening & Business Operations Readiness**

### Business Goal

Make the Business Operations Layer **production-certifiable**: organizers and operators can run tickets, finance, CRM, reporting, team, automation, and integrations with predictable security, failure behavior, and auditability — without changing what the business means.

### Technical Goal

1. Close **security enforcement gaps** (org capabilities, secrets at rest, production webhook config).  
2. Close **reliability gaps** (notification failure honesty/retry policy, job observability).  
3. Reconcile **cross-module semantic drift** (finance ↔ analytics ↔ reports) without redesigning modules.  
4. Improve **performance** of known heavy dashboard/export paths.  
5. Extend **observability** for automation, webhooks, and integrations.  
6. Normalize **UX readiness** (loading / empty / error / permissions).  
7. Deliver **integrated Live QA + certification pack** for Phases 19–25.

### What Phase 25 is NOT

| Not this | Why |
|----------|-----|
| New feature phase | Business Ops capabilities already shipped (19–24) |
| Redesign phase | Architecture frozen 14–24 |
| New architecture phase | Layers already exist; harden interactions |
| Migration phase | No schema rewrite; only additive hardening if approved |
| Marketing rebuild | Phase 20 remains scope-only / Unavailable until separately approved |

---

## 3. Current architecture state

### Completed Business Operations (consume-only)

| Phase | Domain | Implementation status | Live QA |
|-------|--------|----------------------|---------|
| 19 | Vendor CRM | Implemented | Pending (integrated) |
| 20 | Marketing & Growth | **Scope-only** (not productized) | N/A / Unavailable |
| 21 | Reporting & Exports | Implemented | Pending (integrated) |
| 22 | Organization & Team | Implemented | Pending (integrated) |
| 23 | Automation & Workflow | Implemented | Pending (integrated) |
| 24 | Integrations & External Services | Implemented | Pending (integrated) |
| 25 | Hardening & Readiness | **This scope** | Defines certification gate |

### What remains before integrated certification

1. **Enforcement consistency** — org capability matrix applied beyond team management.  
2. **Semantic consistency** — money/settlement labels agree across Finance / Analytics / Reports.  
3. **Failure honesty** — notifications and log-only SMS paths must not silently “succeed.”  
4. **Secrets / production config** — outbound webhook secrets encryption; Quaser secret presence in production.  
5. **Observability depth** — health + metrics for automation backlog, webhook DLQ, integration health.  
6. **Performance passes** on large-event dashboards and export packs.  
7. **UX state normalization** on Automations, Team, Hub, Command Center.  
8. **Integrated Live QA script + certification report** (none exist for 19–25 today).

### Migrations present (must be applied in cert environments)

- `infra/db/055_organizer_members.sql`  
- `infra/db/056_automation_engine.sql`  
- `infra/db/057_integrations_layer.sql`  

---

## 4. Final Business Operations architecture (after Phase 25)

Phase 25 does **not** invent a new stack. It certifies this layered system:

```
Core Business Systems
        ↓
Automation Layer
        ↓
Integration Layer
        ↓
Reporting Layer
        ↓
Organization Layer
        ↓
Organizer Workspace
        ↓
Users
```

### How the layers interact

#### Core Business Systems

Canonical system of record for:

- Events, publishing, invitations, live operations  
- Tickets / orders / payments (Quaser)  
- Finance ledger & settlements  
- Analytics aggregates  
- Vendor CRM pipeline stages  

**Rule:** Only these modules invent or mutate business entities. Hardening may add constraints, indexes, validation, and capability checks — not parallel stores.

#### Automation Layer (Phase 23)

- Consumes `DomainEventsService` (`ticket.issued`, `rsvp.changed`, `vendor.stage_changed`, `refund.completed`, `report.generated`, `schedule.tick`)  
- Decides **when/if** to act via workflow definitions and due jobs  
- Calls **NotificationService** and **OrganizerReportsService** — never forks email/SMS or invents CRM data  

#### Integration Layer (Phase 24)

- Decides **where/how** external systems receive actions  
- Registry, messaging credentials, signed outbound webhooks, delivery retry/DLQ  
- Email remains `NotificationService` → `EmailService`  
- Quaser inbound remains the payment ingress  

#### Reporting Layer (Phase 21)

- **Read-only composition** over Finance / Analytics / Ops / CRM  
- Export packs must reuse canonical services; Marketing stays Unavailable  
- Hardening must align pack semantics with Finance/Analytics — not invent numbers  

#### Organization Layer (Phase 22)

- Owner-first + `organizer_members` access  
- Capability matrix (`finance.read`, `events.write`, `team.manage`, …) overlays platform RBAC  
- Hardening must **enforce** capabilities on organizer APIs that currently check membership only  

#### Organizer Workspace

- Flutter shell + Event Workspace deep-links into frozen modules  
- Super-admin Integrations Hub for platform providers  
- Hardening normalizes loading/error/permission UX — no IA redesign unless cert blockers require deep-link polish only  

#### Users

- Organizers, staff members, attendees, vendors, super-admins  
- Experience portal switching and JWT/tenant guards already exist; hardening clarifies deny messaging for org roles  

### End-to-end interaction (certified path)

```
User action in Organizer Workspace
        ↓
Core Business System mutates canonical state + emits Domain Event
        ↓
Automation Layer evaluates workflows (optional notify / schedule / report)
        ↓
Integration Layer delivers email/SMS/webhook (retry / audit)
        ↓
Reporting Layer reads canonical state for export packs
        ↓
Organization Layer gates who may see/act
        ↓
Audit + metrics + health prove the path for certification
```

---

## 5. Step 1 — System hardening gaps

| Area | Status | Gap / hardening target |
|------|--------|------------------------|
| API reliability | Partial | Global exception filter + request IDs exist; ensure consistent error envelopes on new hub/automation routes |
| Error handling | Strong | Keep `OwanbeExceptionFilter`; eliminate silent success paths (log-only SMS as `ok: true`) |
| Validation | Partial | Global `ValidationPipe` exists; many organizer bodies still ad-hoc — add DTOs where mutations are hardening-critical (webhooks, messaging, team role) |
| DB constraints | Strong-ish | 055–057 present; verify applied in all envs; add indexes only if query audit proves need |
| Migration safety | Gap (ops) | Document ordered apply of 055→057; cert env checklist |
| Logging | Partial | Request log middleware exists; standardize warn fields for automation/webhook failures |
| Audit trails | Partial | `audit_log` used unevenly; webhook CRUD / exports / messaging should be auditable (reuse or consolidate with `messaging_provider_audit`) |
| Background jobs | Partial | In-process `setInterval` for automation (60s) and webhooks (30s); multi-instance race risk — document single-writer assumption or add SKIP LOCKED-safe idempotency (already partial) |
| Retries | Partial | Webhooks: retry + DLQ ✅; Automation: retry then failed; Notifications: **no retry** |
| Failure recovery | Partial | Webhook dead-letter queryable; need operator runbooks + Hub visibility for DLQ depth |

### P0 hardening items

1. Honest notification failure statuses (no false-success log SMS when production expects delivery).  
2. Migration apply verification for 055–057.  
3. Idempotent / safe background sweeps under multi-instance (document or harden).  

### P1

4. Notification retry policy (bounded) or explicit “no-retry + alert” product rule.  
5. DTO validation on integration mutation endpoints.  
6. Audit coverage for integration config changes and sensitive exports.

---

## 6. Step 2 — Security gaps

| Area | Status | Gap / hardening target |
|------|--------|------------------------|
| Authentication | Fully Implemented | JWT + commerce guards — consume |
| Authorization / platform RBAC | Fully Implemented | Roles/Permissions guards — consume |
| Tenant isolation | Fully Implemented | `TenantHeaderGuard` + query scoping — consume |
| Organization membership | Fully Implemented | Owner-or-member access — consume |
| Org capability enforcement | **Gap** | Matrix defined; `assertOrgCapability` barely applied outside team.manage — **staff may reach finance/ops/analytics/reports contrary to matrix** |
| API permissions | Partial | Align organizer controllers with capability checks |
| Secrets handling | Partial | Email/messaging encrypted ✅; **outbound webhook `secret_key` plaintext** ❌ |
| Webhook security | Strong inbound / Strong outbound HMAC | Harden empty `QUASER_WEBHOOK_SECRET` in production mode |
| Integration credentials | Strong (messaging) | Extend crypto pattern to webhook secrets |
| Audit logging | Partial | Security-relevant mutations must leave trails |

### P0 security items

1. Enforce `assertOrgCapability` (or equivalent) on finance, analytics, reports, ops, automations mutations/reads per Phase 22 matrix.  
2. Encrypt outbound webhook secrets at rest (reuse `EmailSecretsCrypto`).  
3. Fail closed when `INTEGRATIONS_MODE=production` and Quaser webhook secret missing/empty.

### P1

4. Expand audit_log (or equivalent) for webhook/messaging admin actions.  
5. Permission-denied messaging contract for Flutter (stable error codes).

---

## 7. Step 3 — Cross-module consistency gaps

| Pair | Risk | Hardening target |
|------|------|------------------|
| Finance ↔ Analytics | **High** | Same labels (`grossCollectedMinor`, `netEarningsMinor`, `settlementStatus`) with different formulas / escrow / `partial` handling |
| Finance ↔ Reports | Medium | Reports reuse `FinanceExportService` — verify pack numbers match Finance tab |
| Analytics ↔ Reports | Medium | CSV / intelligence packs must not redefine net |
| Tickets / Orders ↔ Finance | Low–Med | Ensure status vocabulary documented; no parallel ledgers |
| Vendor CRM ↔ Automation | Low | Stage events already wired — verify run history |
| Automation ↔ Integrations | Low | Dual consumers of domain bus — ensure no double-notify product bugs |
| Organization ↔ all | **High** | Membership vs capability mismatch |
| Ownership rules | Medium | Owner-first must remain single rule across services |

### Consistency rule for Phase 25

> **One meaning per metric.** If Analytics and Finance disagree, Analytics must consume Finance definitions (or explicitly label a different metric). Do not invent a third calculator in Reports.

### Duplicate logic to retire or gate (not redesign)

- Multiple CSV builders (analytics export, finance export, reports wrap) — keep services, but pin shared money semantics.  
- Flutter `ExportHelper` already unifies download UX — keep.  
- Deprecated `integration_engine.dart` mocks — ensure no UI still presents them as truth.

### Phase 20 Marketing

Treat as **Unavailable** everywhere (already Reports posture). Phase 25 must **not** implement Marketing; certify that Unavailable labeling is consistent.

---

## 8. Step 4 — Performance gaps

| Surface | Risk | Hardening target |
|---------|------|------------------|
| Organizer analytics intelligence | High | Sequential multi-query + series bundle — profile & batch |
| Portfolio analytics | High | Per-event correlated subqueries × N events — cap/batch |
| Finance hub summary | Medium | Multiple round-trips — coalesce where safe |
| Reports export packs | Medium | Re-query loops — stream or reuse cached snapshots carefully (no invented data) |
| Dashboard mobile | Low–Med | Prefer single hub payloads already used |
| Webhook delivery | Medium | Sequential `deliverOne`; batch size 20 — monitor DLQ under load |
| Notification throughput | Medium | No queue beyond DB insert — document limits; optional bounded concurrency |
| Background jobs | Medium | Single-process timers — cert assumption: one API replica or proven SKIP LOCKED |

### Performance success criteria

- Event dashboard / finance / analytics usable for “large event” fixture defined in QA (document N tickets / N guests).  
- Export packs complete within agreed SLA or return async job status (only if required — prefer sync + pagination first).  
- Webhook sweeper clears due backlog without unbounded growth in cert soak.

---

## 9. Step 5 — Observability gaps

| Signal | Status | Gap |
|--------|--------|-----|
| `/health` | Partial | Exists via `HealthDetailService` — extend for automation backlog, webhook DLQ depth, messaging provider presence, Quaser secret configured |
| Metrics | Partial | In-memory Prometheus — add webhook success/fail/DLQ, automation job fail, integration delivery counters |
| Logs | Partial | Correlate automation run id / webhook delivery id with `request_id` where possible |
| Failures | Partial | Hub Deliveries UI exists (super-admin); need health alerts + organizer visibility where appropriate |
| Job monitoring | Gap | No first-class automation backlog health |
| Webhook monitoring | Partial | API listDeliveries; not health/metrics-backed |
| Automation monitoring | Partial | Runs API + Flutter Automations tab |
| Integration monitoring | Partial | Registry live probes; deepen for SMS/WhatsApp last_error |

### P0 observability

1. Health detail fields for: DB, email readiness, Quaser config, webhook DLQ count, automation failed/due counts.  
2. Metrics counters for webhook + automation outcomes.

### P1

3. Operator checklist / runbook section in certification report.  
4. Soak-test logging for notification volume.

---

## 10. Step 6 — UX readiness gaps

| Surface | Gap |
|---------|-----|
| Reports | Stronger pattern (banner + retry); catalog empty edge case |
| Automations | Runs errors raw; thin loading; empty not EOS-aligned |
| Organization Team | Directory errors can shrink silently; invite not role-gated in UI; SnackBar-only denials |
| Integration Hub | Super-admin Nest-backed ✅; raw errors / weak retry; **no organizer Flutter for `/organizers/me/integrations/*`** |
| Command Center | Overview/analytics/finance inconsistent error empties (`SizedBox.shrink` risk) |
| Workspace switching | Portal guard can render child while loading access |
| Navigation | 9-tab organizer bar cramped; Reports event-scoped vs shell Analytics dual surface; Integrations not in organizer IA |
| Permissions messaging | No organizer equivalent of admin FORBIDDEN classification |

### UX hardening rule

Normalize **loading / empty / error + Retry** on Business Ops surfaces. Deep-link organizer webhook status only if cert requires it — **do not redesign shell IA** unless a journey is unblockable without a deep-link.

---

## 11. Step 7 — Certification preparation

### Integrated QA strategy

One **Business Operations Integrated Live QA** after Phase 25 hardening closes P0s:

1. **Environment gate** — migrations 055–057 applied; `INTEGRATIONS_MODE` documented; email provider configured; Quaser secret set for prod-like mode.  
2. **Journey pack** — execute critical paths below end-to-end.  
3. **Regression pack** — frozen phases 14–24 smoke (publish, invite, live ops, finance, analytics, CRM, reports, org, automation, integrations).  
4. **Failure pack** — provider down → retry/DLQ; capability deny; webhook bad signature.  
5. **Certification report** — single closure doc for Phases 19–25 (and note Phase 20 Unavailable).

### Critical business journeys (must pass)

| ID | Journey |
|----|---------|
| J1 | Ticket purchase → Finance ledger → Report export pack (numbers agree) |
| J2 | Invite → RSVP → Automation run → Notification delivery audit |
| J3 | Vendor CRM stage change → Automation → optional outbound webhook delivery |
| J4 | Org invite → accept → member access; revoke/deny paths |
| J5 | Outbound webhook register → domain event → delivery success / retry / DLQ |
| J6 | Quaser inbound payment webhook still settles tickets/finance (no regression) |
| J7 | Staff without `finance.read` cannot access finance APIs (after capability hardening) |
| J8 | Refund → automation/integration fan-out without ledger corruption |

### Regression checklist (frozen domains)

- Publishing / invitations / live ops  
- Finance / analytics  
- Vendor CRM  
- Reporting exports  
- Organization team  
- Automation engine  
- Integrations registry + webhooks + email path  

### Production readiness criteria

| Criterion | Pass condition |
|-----------|----------------|
| Security | Org capabilities enforced; secrets encrypted/fail-closed in production |
| Reliability | No silent notification success; webhook DLQ operable |
| Consistency | Finance/Analytics/Reports money semantics aligned or explicitly labeled |
| Observability | Health + metrics cover automation & webhooks |
| UX | Critical surfaces show loading/empty/error with retry |
| QA | Integrated Live QA script + certification report signed off |
| Scope purity | No Phase 20 Marketing implementation; no redesigned frozen modules |

### Existing artifacts vs missing

| Exists today | Missing for 19–25 |
|--------------|-------------------|
| `PHASE10–13` Live QA / cert docs & scripts | **All** `PHASE19–25` Live QA / cert packs |
| Phase 21–24 completion reports | Phase 25 completion (after implementation) |
| Phase 20 scope only | Marketing remains Unavailable |

---

## 12. Implementation roadmap (Phase 25 only)

### Wave A — Security & consistency (P0)

1. Enforce organizer capabilities on finance / analytics / reports / ops / automations.  
2. Encrypt webhook secrets; production Quaser secret fail-closed.  
3. Reconcile Finance ↔ Analytics settlement/net definitions.  
4. Honest notification provider outcomes.

### Wave B — Reliability & observability (P0–P1)

5. Health + metrics for automation backlog and webhook DLQ.  
6. Notification retry policy or documented no-retry + monitoring.  
7. Audit trails for integration config mutations.  
8. Background job multi-instance safety documentation or hardening.

### Wave C — Performance & UX (P1)

9. Profile/fix large-event analytics & finance hub queries.  
10. Normalize error/empty/retry on Automations, Team, Hub, CC.  
11. Optional organizer Integrations status deep-link (consume APIs only).

### Wave D — Certification (required)

12. Author `scripts/phase25_business_ops_live_qa.mjs` (or equivalent) covering J1–J8.  
13. Generate `docs/PHASE25_BUSINESS_OPS_CERTIFICATION_REPORT.md` after Live QA.  
14. Generate `docs/PHASE25_PLATFORM_HARDENING_COMPLETION_REPORT.md` after Waves A–C.

### Explicitly out of scope

- Marketing (Phase 20) productization  
- Salesforce / Drive / Dropbox / GA  
- Payment provider redesign / multi-PSP  
- New notification system  
- Bull/Redis introduction unless P0 reliability cannot be met otherwise (**decision gate** — if needed, STOP and request approval)  
- Organizer shell IA redesign (9-tab) beyond minimal deep-links  

---

## 13. Dependency / decision gates

| If Phase 25 needs… | Action |
|--------------------|---------|
| Change Finance formulas used by Analytics | Document dependency; prefer Analytics consume Finance — no dual redesign |
| Introduce Redis/Bull for jobs | **STOP** — architectural addition; wait for approval |
| Implement Marketing | **STOP** — Phase 20; not Phase 25 |
| Redesign Publishing / Invitations / Ops | **STOP** — frozen |
| Change Quaser payment capture rules | **STOP** — frozen Finance path |

No further architectural decisions are required to **define** Phase 25. Optional Bull/Redis is a gate only if Wave B proves in-process sweepers insufficient.

---

## 14. Architecture question — answer

**After Phase 25, the final Business Operations architecture is the layered system already built in Phases 19–24, hardened and certified — not replaced.**

```
Core Business Systems  →  invent & own business truth
        ↓
Automation Layer       →  when/if to act (events → workflows)
        ↓
Integration Layer      →  where/how to leave the platform (email/SMS/webhooks)
        ↓
Reporting Layer        →  read-only packs over canonical data
        ↓
Organization Layer     →  who may see/act (owner + members + capabilities)
        ↓
Organizer Workspace    →  UX composition & deep-links
        ↓
Users                  →  organizers, staff, operators, attendees
```

All layers interact through **canonical domain events + shared services** (`NotificationService`, Finance/Analytics/Reports services, `EventsAccessService`). Phase 25 makes those interactions **secure, consistent, observable, and certifiable**.

---

## 15. Final result

✅ Phase 25 Scope Defined

**STOP.** Do not begin Phase 25 implementation until Completion Review / go-ahead for the hardening sprint.
