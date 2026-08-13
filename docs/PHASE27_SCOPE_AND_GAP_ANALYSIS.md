# PHASE 27 — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-02  
**Method:** Architecture-derived (Phases 1–26 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **1–26** architecture-complete — Phase 27 may **consume** only; must not redesign frozen domains  
**Evolution layer:** Phases **26–30** = platform maturity — each phase needs a clear platform-level objective  
**Parallel gate:** Integrated Live QA / certification for Business Ops (19–25) and Marketing (26) remains a **planning/execution gate**, not a substitute for Phase 27 product scope

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Grow loop shipped (Marketing 26); operate + harden already complete |
| **Proposed domain** | Enterprise Compliance & Data Governance — **correct next maturity capability** |
| **Why this over AI / SDK / MDM / queues** | Nest compliance substrate exists but is unwired; Security 360 Compliance is display-only; highest trust/enterprise unlock without redesign |
| **Natural Phase 27** | Make export / retention / deletion **operable** for platform admins — consume audit_log, security events, existing ComplianceModule |
| **IA** | Admin / Super-admin Compliance workspace consuming Nest `/compliance/*` (not Flutter SecurityEngine cosmetics) |
| **Overall** | **✅ Phase 27 Scope Defined** |

After Marketing, the platform can create, operate, report, automate, integrate, and grow. The next maturity gap is **trust operations**: enforceable data subject and retention workflows that enterprises expect — not another growth feature or AI surface.

---

## 2. Platform state — what naturally follows

```
Attendee Platform
        ↓
Organizer Platform
        ↓
Business Operations (CRM → Reports → Org → Automation → Integrations → Hardening)
        ↓
Marketing & Growth (26)
        ↓
??? Enterprise trust / data governance maturity
```

| Layer | Status after Phase 26 |
|-------|----------------------|
| Core product loops | Architecture-complete — consume |
| Marketing | Implemented — consume |
| Hardening | Implemented; Live QA checklist prepared, not fully executed |
| Compliance product | **Partial** — Nest routes thin; Flutter mostly unwired / cosmetic |
| Super-admin MDM / Governance / Copilot / Workflow Studio | **Mock / Frontend Only** |
| Developer API keys / SDK | **Not Implemented** (SQL stub) |
| Job queues (Bull/Redis) | Deferred pending Live QA proof |

**Next missing platform capability:** Operable **Compliance & Data Governance** — export, retention policy management, deletion-request lifecycle — wired to real Nest APIs and honest admin UX.

---

## 3. Why Phase 27 follows Phase 26

1. **Operate → Harden → Grow → Trust** is coherent maturity sequencing. Marketing increased outbound PII contact surface; compliance ops become more urgent.  
2. **Foundations exist** — `ComplianceModule` (`/compliance/export`, `/retention`, `/deletion-requests`), retention/deletion tables, `audit_log`, security events (Phase 8 lineage).  
3. **Gap is productization, not invention** — Admin UIs call dashboards/disputes/audits but **do not** systematically consume `/compliance/*`; Security 360 Compliance tab is display metrics + snackbars.  
4. **Stabilization-safe** — extends admin/compliance surfaces; does not redesign Marketing, Finance, or Automation.  
5. **Not popularity-driven** — AI copilots, marketplace ratings, and SDK portals score high on “interesting” but weak on evidence and foundations relative to compliance.

### Parallel (not Phase 27)

Integrated Live QA / certification for Phases 19–26 should continue under **Live QA Planning**. It is a **gate**, not the Phase 27 domain name.

---

## 4. Phase definition

### Official Phase Name

**Phase 27 — Enterprise Compliance & Data Governance**

*(Working short name: Compliance)*

### Business Goal

Give platform operators a trustworthy way to **export tenant/user data packages**, **manage retention policies**, and **process deletion requests** — using existing compliance APIs, audit trails, and security events — so Owambe can meet enterprise and regulatory expectations without inventing a parallel data warehouse or identity system.

### Technical Goal

1. Wire Admin / Super-admin Compliance UX to Nest `/compliance/*` (replace display-only Compliance tab behavior)  
2. Deepen **deletion-request lifecycle** (requested → reviewing → processing → completed / rejected) without inventing new identity stores  
3. Make **retention policies** readable/updatable and attach enforcement hooks where safe (jobs consuming existing tables — no Bull unless approved)  
4. Ensure **export** packages compose canonical sources (users, events, orders metadata as already scoped in Phase 8) — read-only composition  
5. Surface honest **Unavailable** where tooling is incomplete  
6. Extend audit logging for compliance operator actions  

### Primary Users

| User | Need |
|------|------|
| Platform Admin / Super-admin | Run exports, retention, deletion ops |
| Compliance / support operators | Track deletion requests and audit evidence |
| Organizers / attendees | Indirect beneficiaries (DSAR fulfillment) — no new identity UX required in P0 |
| Developers | Not primary — SDK is out of scope |

### Primary Journeys

| ID | Journey |
|----|---------|
| J1 | Admin opens Compliance → lists retention policies from Nest (not static metrics) |
| J2 | Admin requests data export for tenant/user → downloadable package from existing export service |
| J3 | Admin creates / reviews deletion request → status transitions → completion evidence in audit_log |
| J4 | Security 360 Compliance tab deep-links or embeds real compliance status (or shows Unavailable) |
| J5 | Failed / blocked deletion shows reason without silent success |
| J6 | Role-gated access (existing admin tiers) — no RBAC redesign |

### Success Criteria

- [ ] Flutter Compliance surfaces call Nest `/compliance/*` for primary flows  
- [ ] No parallel PII warehouse or second user store  
- [ ] Deletion requests have a real lifecycle beyond insert-only  
- [ ] Retention policies are operable (read + controlled update)  
- [ ] Security 360 cosmetic Compliance metrics are demoted or replaced with live data  
- [ ] Frozen domains 1–26 consume-only  
- [ ] Marketing / notifications / finance rules unchanged  
- [ ] Live QA gate remains tracked separately  

---

## 5. Strategic platform audit (Step 1)

| Area | Gap | Phase 27? |
|------|-----|-----------|
| Enterprise readiness | Compliance ops thin / unwired | **Yes — primary** |
| Scalability | In-process job sweepers | No (unless Live QA forces decision) |
| Customer experience | Attendee/organizer loops complete | No |
| Platform ecosystem / developer APIs | API keys unused | Later |
| Administration | Launch Ops real; MDM/governance mock | Later (large productization) |
| Compliance | Nest partial; UI cosmetic | **Yes** |
| Security | Hardening done; Security 360 mixed | Consume / wire Compliance tab |
| Intelligence / AI | Mock copilots | Explicitly not |
| Marketplace expansion | Synthetic ratings | Later |
| Data capabilities | Export exists thin | **Yes — deepen export** |
| Marketing maturity | Promo codes deferred | Later growth polish |

---

## 6. Codebase audit (Step 3)

| Capability | Classification | Evidence |
|------------|----------------|----------|
| Compliance Nest APIs | **Partially Implemented** | `ComplianceModule` — export / retention / deletion-requests |
| Compliance Flutter (admin) | **Partially Implemented / adjacent** | Dashboard/disputes/audit screens — weak `/compliance` wiring |
| Security 360 Compliance | **Frontend Only** | Display metrics; snackbar actions; no Nest compliance client |
| Launch Ops | **Fully Implemented** | Nest + Flutter admin |
| MDM | **Frontend Only / Hidden SQL** | `master_data_engine.dart`; `039_enterprise_mdm.sql` unused by Nest |
| Vendor Governance UI | **Mock** | In-memory engines; Nest guard thin |
| Platform Copilot | **Mock** | Seeded recommendations |
| Workflow Studio | **Mock** | Local engine; `040` unused by Nest workflows product |
| Developer API keys | **Not Implemented** | `043` `platform_api_keys`; no Nest usage |
| Marketplace ratings | **Frontend Only** | Nest `ratingAverage: null`; client seed reviews |
| Featured/boost | **Partially Implemented** | Metadata/Discover; no organizer boost product |
| Background jobs | **Partially Implemented** | In-process `setInterval` + DB queues |
| Promo codes | **Not Implemented** | Deferred Phase 26 |
| Phase 25 Live QA | **Partial** | Checklist + scaffold; cert deferred |

### Reusable systems (must consume)

- `ComplianceService` / controller routes  
- `audit_log`, `platform_security_events`  
- Retention / deletion request tables (Phase 8)  
- Admin auth / role tiers (`admin_super`, `admin_ops`, etc.)  
- Existing export aggregations — extend, do not fork Finance/Analytics  

---

## 7. Feature discovery (Step 4) — what belongs in Phase 27

### In Phase 27 (P0–P2)

| Item | Priority |
|------|----------|
| Wire Admin Compliance UI to Nest export / retention / deletion | P0 |
| Deletion request lifecycle + operator actions | P0 |
| Retention policy list + controlled updates | P0 |
| Audit trail for compliance actions | P0 |
| Security 360 Compliance tab → real status or Unavailable | P1 |
| Export package completeness review (compose existing sources) | P1 |
| Retention enforcement sweeper (in-process, like Phase 25 jobs) | P2 |
| Organizer-visible DSAR status (optional thin) | P2 |

### Explicitly NOT Phase 27

| Item | Why |
|------|-----|
| LLM / Platform Copilot productization | Mock; needs separate decision |
| MDM / Workflow Studio Nest productization | Orphan SQL + large redesign surface |
| Developer portal / public SDK | Premature vs trust ops |
| Bull/Redis introduction | Architectural gate — STOP if required |
| Marketplace ratings / featured marketplace | Growth, not trust maturity |
| Promo codes | Marketing deferred item |
| Redesign Security module / Auth | Frozen hardening patterns — extend only |

---

## 8. Architecture impact (Step 5)

```
Core Business Systems  ← remain canonical PII/order sources for export composition
        ↓
Automation Layer       ← optional later hooks for retention jobs (consume engine if needed)
        ↓
Integration Layer      ← unchanged; no new notification system
        ↓
Reporting Layer        ← optional compliance evidence exports (read-only)
        ↓
Organization Layer     ← unchanged (organizer capabilities); platform admin roles consume
        ↓
Admin / Super-admin Workspace ← Compliance IA wired to Nest
        ↓
Users / Data subjects  ← deletion/export fulfillment without new identity model
```

| Layer | Impact |
|-------|--------|
| Core business | Read for export; controlled anonymize/delete paths only via compliance service |
| Automation | Optional P2 retention ticks — do not rebuild Automation |
| Integrations | None required |
| Reporting | May expose compliance evidence packs later — not invent metrics |
| Organization | No change to organizer matrix |
| Workspace | Admin Compliance + Security 360 consumer |
| Users | Subject of DSAR — no parallel profile store |

---

## 9. Dependencies

| Dependency | Type |
|------------|------|
| Phase 8 compliance tables + Nest module | Hard — consume |
| Admin role guards | Hard — consume |
| Audit / security event tables | Hard — consume |
| Phase 25 Live QA / cert | Soft parallel gate — do not block scope definition; should progress alongside |
| Phase 26 Marketing | Soft — increases PII outbound surface; no code dependency |

If deletion requires redesign of Auth/Users identity model: **STOP**, document, wait for approval.

---

## 10. Risks

| Risk | Mitigation |
|------|------------|
| Destructive deletes breaking Finance/Tickets | Soft-delete / anonymize patterns; never invent ledger rewrites |
| Treating Security 360 cosmetics as done | Explicit replacement criteria in success list |
| Scope creep into MDM/Governance OS | Out-of-scope list; separate future phase |
| Introducing Bull for retention | Prefer in-process sweeper; STOP if insufficient |
| Over-collecting export data | Stick to Phase 8 composition boundaries; document fields |
| Skipping Live QA forever | Track as parallel certification gate |

---

## 11. Effort estimation (Step 6)

| Dimension | Estimate |
|-----------|----------|
| Overall Phase 27 | **Medium–Large** |
| P0 API wiring + deletion lifecycle + retention CRUD | **Medium** |
| P1 Security 360 + export completeness | **Medium** |
| P2 enforcement sweeper + optional organizer DSAR | **Medium** |
| Full MDM/Governance Nest OS | **Enterprise** — out of scope |

Smaller than inventing a developer platform; larger than a pure wiring sprint if deletion lifecycle is incomplete today.

---

## 12. Implementation roadmap (definition only)

### Wave 0 — Gates

1. Acknowledge Phase 26 Completion Review  
2. Continue Integrated Live QA Planning in parallel  

### Wave A — P0 Compliance ops

3. Audit Nest `ComplianceService` gaps (lifecycle, permissions)  
4. Wire Admin Compliance screens to `/compliance/*`  
5. Deletion request state machine + audit  

### Wave B — P1 Trust UX

6. Retention policy operator UX  
7. Security 360 Compliance consumes live APIs  
8. Export package QA against frozen domain data owners  

### Wave C — P2 Enforcement

9. Retention enforcement sweeper (in-process)  
10. Regression: auth, tickets, finance, marketing send paths  

---

## 13. Runner-up alternatives (why not Phase 27)

| Alternative | Why not now |
|-------------|-------------|
| Developer API keys / SDK | Schema stub; Hub/webhooks already cover partner egress; trust ops first |
| Super-admin MDM / Governance / Workflow Studio | Mock + orphan SQL = large parallel OS |
| Bull/Redis workers | Deferred unless Live QA proves need |
| Marketplace ratings / featured | Popular; weak platform-maturity leverage |
| Promo codes | Marketing deferred; growth polish |
| LLM AI assistants | Explicitly deferred; mock copilots |

---

## 14. Final result

✅ Phase 27 Scope Defined

**STOP.** Do not begin Phase 27 implementation until Phase 26 Completion Review is cleared. Continue Integrated Live QA Planning as a parallel certification track.
