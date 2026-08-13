# PHASE 28 — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-02  
**Method:** Architecture-derived (Phases 1–27 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **1–27** architecture-complete — Phase 28 may **consume** only; must not redesign frozen domains  
**Evolution layer:** Final platform maturity — each phase needs a clear platform-level objective  
**Parallel gate:** Integrated Live QA / certification for Business Ops (19–25), Marketing (26), and Compliance (27) remains a **planning/execution gate**, not a substitute for Phase 28 product scope

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Trust ops shipped (Compliance 27); operate / harden / grow already complete |
| **Proposed domain** | Enterprise Administration & Control Plane — **correct next maturity capability** |
| **Why this over AI / SDK / Bull / marketplace** | Launch Ops is Nest-real; MDM, Vendor Governance, Tenant Admin remain Flutter mock + orphan SQL; largest enterprise gap after trust |
| **Natural Phase 28** | Productize platform admin governance surfaces against Nest + existing canonical tables — replace theatrical control plane |
| **IA** | Super-admin / Platform Admin control plane consuming Nest MDM + governance + tenant APIs (not in-memory engines) |
| **Overall** | **✅ Phase 28 Scope Defined** |

After Compliance, operators can export, retain, and anonymize with audit evidence — but the rest of the **enterprise control plane** (dictionaries, vendor lifecycle governance, tenant administration) is still parallel mock UX beside one real island (Launch Ops). That asymmetry is the remaining maturity gap.

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
Compliance & Data Governance (27)
        ↓
??? Enterprise control plane / admin OS maturity
```

| Layer | Status after Phase 27 |
|-------|----------------------|
| Core product loops | Architecture-complete — consume |
| Marketing | Implemented — consume |
| Compliance | Implemented — consume |
| Hardening | Implemented; Live QA checklist prepared, not fully executed |
| Launch Ops | **Fully Implemented** (Nest + Flutter) |
| MDM / master data | **Frontend Only + Hidden SQL** (`039_enterprise_mdm.sql` unused by Nest) |
| Vendor / Tenant Governance | **Frontend Only / Mock** (thin Nest guard only) |
| MFA / SOC evidence UI | **Frontend Only / Mock** |
| Developer API keys / SDK | **Not Implemented** (`platform_api_keys` stub; no Nest usage) |
| Job queues (Bull/Redis) | Deferred — in-process sweepers only |
| Platform Copilot / Workflow Studio | **Mock / Frontend Only** |

**Next missing platform capability:** Operable **Enterprise Administration & Control Plane** — Nest-backed MDM, vendor governance lifecycle, and tenant administration that replace in-memory engines and consume canonical business data.

---

## 3. Why Phase 28 follows Phase 27

1. **Operate → Harden → Grow → Trust → Control** is coherent maturity sequencing. Compliance without an admin control plane leaves operators able to fulfill DSARs but unable to govern platform dictionaries, vendor standing, or tenants against Nest truth.  
2. **Foundations exist** — Launch Ops Nest APIs; `039_enterprise_mdm.sql`; vendor/tenant tables; thin `governance.guard.ts`; admin auth tiers; `audit_log`.  
3. **Gap is productization, not invention** — Super-admin MDM / Governance / Tenant screens already exist as Flutter shells; they do not systematically consume Nest.  
4. **Stabilization-safe** — extends platform-admin surfaces; does not redesign Attendee, Organizer ops, Finance, Marketing, or Compliance.  
5. **Not popularity-driven** — AI copilots, marketplace ratings, and SDK portals score high on “interesting” but weak on evidence and foundations relative to the control plane.

### Parallel (not Phase 28)

Integrated Live QA / certification for Phases 19–27 should continue under **Live QA Planning**. It is a **gate**, not the Phase 28 domain name.

---

## 4. Phase definition

### Official Phase Name

**Phase 28 — Enterprise Administration & Control Plane**

*(Working short name: Enterprise Admin / Control Plane)*

### Business Goal

Give platform operators a trustworthy **enterprise administration OS** — master data dictionaries, vendor governance lifecycle, and tenant administration — backed by Nest and canonical tables — so Owambe can be operated as an enterprise platform after Compliance, without inventing parallel CRM, Finance, or identity systems.

### Technical Goal

1. Wire Super-admin MDM workspace to Nest APIs over (or honestly migrating) `039_enterprise_mdm` / existing config dictionaries — replace `master_data_engine.dart` as source of truth  
2. Productize **Vendor Governance** against Nest + existing vendor/negotiation standing (extend thin `governance.guard` — do not invent a second vendor store)  
3. Productize **Tenant Administration** read/control surfaces against Nest tenants/users/flags — replace mock export/health theater  
4. Emit **audit_log** for admin control-plane actions  
5. Surface honest **Unavailable** where tooling is incomplete  
6. Deep-link Launch Ops + Compliance as adjacent real admin islands (consume, do not redesign)

### Primary Users

| User | Need |
|------|------|
| Platform Admin / Super-admin | Govern MDM, vendors, tenants |
| Ops / support operators | Enforce vendor standing; inspect tenant health |
| Compliance operators | Adjacent consumers of accurate admin truth |
| Organizers / attendees | Indirect — governed platform rules |
| Developers | Not primary — API keys/SDK deferred to later maturity |

### Primary Journeys

| ID | Journey |
|----|---------|
| J1 | Admin opens MDM → lists/edits dictionary entities from Nest (not in-memory engine) |
| J2 | Admin opens Vendor Governance → views standing / restrictions from Nest vendor truth |
| J3 | Admin opens Tenant Admin → lists tenants / flags / health from Nest (or honest Unavailable) |
| J4 | Control-plane actions write `audit_log` entries |
| J5 | Failed / unauthorized actions show reason without silent mock success |
| J6 | Role-gated access (existing admin tiers + permissions) — no RBAC redesign |

### Success Criteria

- [ ] Flutter MDM / Vendor Governance / Tenant Admin primary flows call Nest (or show Unavailable)  
- [ ] No parallel vendor/tenant/finance stores  
- [ ] `master_data_engine` / `vendor_governance_engine` demoted or removed as canonical sources  
- [ ] Admin actions produce audit evidence  
- [ ] Frozen domains 1–27 consume-only  
- [ ] Compliance / Marketing / Finance / Automation unchanged as owners  
- [ ] Live QA gate remains tracked separately  

---

## 5. Strategic platform audit (Step 1)

| Area | Gap | Phase 28? |
|------|-----|-----------|
| Enterprise administration | MDM / Tenant Admin mock | **Yes — primary** |
| Platform governance | Vendor Governance mock; Nest guard thin | **Yes — primary** |
| Customer intelligence | No cohort/CLV/personalization | No |
| Advanced operations | Workflow Studio mock | No (would fork Phase 23) |
| Scalability | In-process sweepers; no Bull | No (gate / later) |
| Developer ecosystem | `platform_api_keys` unused; no SDK | Later (strong candidate Phase 29+) |
| Partner ecosystem | Outbound webhooks real; ratings synthetic | Later |
| Security maturity | MFA/SOC UI theatrical | Strong adjacent candidate; see §7 |
| Data intelligence | Analytics compose-only (correct) | No redesign |
| AI readiness | Copilot seeded mock | Explicitly not |
| Global readiness | No i18n; NGN-hardcoded UX | Later expansion |

---

## 6. Codebase audit (Step 3)

| Capability | Classification | Evidence |
|------------|----------------|----------|
| Launch Ops | **Fully Implemented** | Nest `launch-ops-dashboard.service.ts`; Flutter Launch Ops screens |
| Platform Admin dashboards (organizers/events/vendors/finance/audit) | **Fully Implemented / Partial** | Nest `platform-admin/*`; Flutter admin portal |
| Compliance (Phase 27) | **Fully Implemented** | Nest `/compliance/*`; Admin Compliance + Security 360 live tab |
| MDM | **Frontend Only + Hidden SQL** | `master_data_engine.dart`, `mdm_workspace_screen.dart`; `infra/db/039_enterprise_mdm.sql`; **zero** Nest `mdm_` usage |
| Vendor Governance UI | **Frontend Only / Mock** | `vendor_governance_engine.dart`, `vendor_governance_screen.dart` |
| Vendor Governance Nest | **Partially Implemented** | Thin standing checks (e.g. negotiation suspended/blocked) — not lifecycle OS |
| Tenant Admin UI | **Frontend Only / Mock** | Mock health / mock export patterns in super-admin tenant screens |
| Outbound webhooks | **Fully Implemented** | Nest outbound webhook + hub (Phase 24) |
| `platform_api_keys` | **Not Implemented** | `043_integration_hub.sql` stub; no Nest reads |
| Public SDK / developer portal | **Not Implemented** | Deferred historically |
| Marketplace ratings | **Frontend Only** | Nest `ratingAverage: null`; Flutter seed reviews |
| Featured / Discover boost | **Partially Implemented** | Event metadata + Discover; no paid boost product |
| Organizer automation (Phase 23) | **Fully Implemented** | Nest + Flutter; consume |
| Workflow Studio | **Frontend Only / Mock** | Local `workflow_engine.dart`; not Nest Studio product |
| Bull / Redis | **Not Implemented** | Absent from API `package.json`; `setInterval` sweepers |
| MFA | **Frontend Only / Mock** | `identity_mfa_provider.dart`; no Nest TOTP APIs |
| SOC / Security Center KPIs | **Frontend Only / Mock** | Hardcoded scores / theater |
| Platform Copilot | **Frontend Only / Mock** | `ai_platform_engine.dart` seeded recommendations |
| i18n / multi-region | **Not Implemented** | English-only; no region productization |
| Multi-currency | **Partially Implemented** | DB `CHAR(3)`; Flutter NGN-centric UX |
| Phase 25 Live QA | **Partial** | Checklist + scaffold scripts; cert deferred |

### Reusable systems (must consume)

- Launch Ops + Platform Admin Nest modules  
- `vendors`, `tenants`, `users`, feature flags, negotiation standing  
- `audit_log` / `AuditLogService`  
- Admin role tiers + `RequirePermissions`  
- Existing Compliance and Integrations hubs (deep-link, do not fork)  
- SQL `039_enterprise_mdm` — wire or migrate honestly; do not invent a second dictionary store  

---

## 7. Feature discovery (Step 4) — what belongs in Phase 28

### In Phase 28 (P0–P2)

| Item | Priority |
|------|----------|
| Nest MDM APIs + wire Flutter MDM workspace | P0 |
| Nest Vendor Governance lifecycle over canonical vendors | P0 |
| Nest Tenant Admin read model + controlled ops (flags/status) | P0 |
| Audit logging for control-plane actions | P0 |
| Demote/remove in-memory engines as truth | P1 |
| Honest Unavailable for unfinished admin tools | P1 |
| Deep-link Launch Ops + Compliance from control plane | P2 |

### Adjacent candidates (not primary Phase 28 unless P2 stretch)

| Item | Notes |
|------|-------|
| Nest MFA / TOTP productization | Completes trust stack; large identity surface — prefer Phase 29 if control plane already large |
| Activate `platform_api_keys` | Natural after control plane can authorize/audit partners |

### Explicitly out of Phase 28

| Item | Why |
|------|-----|
| LLM / Platform Copilot productization | Seeded Flutter only; no Nest intelligence substrate |
| Workflow Studio visual builder | Would fork Phase 23 preset automation |
| Bull / Redis introduction | Infra STOP gate — not product maturity name |
| Marketplace ratings / paid boost suite | Invents marketplace truth; growth polish |
| Promo codes / attribution pixels | Deferred Marketing polish |
| Full i18n + multi-region | Expansion before control-plane certification |
| Customer personalization / AI analytics | No data model; Analytics must stay compose-only |
| New RBAC / identity redesign | Forbidden — consume existing |
| Compliance redesign | Frozen Phase 27 — consume |

### Ranked alternatives considered

| Rank | Domain | Decision |
|------|--------|----------|
| 1 | Enterprise Admin & Control Plane | **Selected** |
| 2 | Identity & Security Productization (MFA/SOC) | Strong Phase 29 candidate |
| 3 | Developer / Partner API Platform (`platform_api_keys`) | Strong Phase 29/30 candidate after admin + identity |

---

## 8. Architecture impact (Step 5)

| Layer | Impact |
|-------|--------|
| **Core Business Systems** | Read/govern only — vendors, tenants, config dictionaries; no ownership change for tickets/finance/guests |
| **Automation** | Untouched (Phase 23 consume) |
| **Integrations** | Untouched egress; may later authorize keys — not required for P0 |
| **Reporting** | Untouched; optional admin audit packs later |
| **Organization** | Organizer org/team matrix untouched |
| **Compliance** | Consume deep-links; no DSAR redesign |
| **Workspace** | Super-admin / platform-admin shells wired to Nest |
| **Users** | Tenant/user admin reads; no auth redesign |

**Invariant:**

```
Canonical Business Data
        ↓
Enterprise Control Plane (Nest)
        ↓
Audit Evidence
        ↓
Authorized Platform Operators
```

---

## 9. Effort estimation (Step 6)

| Scope band | Estimate |
|------------|----------|
| Nest MDM + Vendor Governance + Tenant Admin + Flutter wire-up + audit | **Large** |
| If MFA Nest + SOC evidence included in same phase | Approaches **Enterprise** — **do not combine** without explicit approval |
| API keys alone | Medium (better as follow-on) |

**Recommended Phase 28 sizing:** **Large** (control plane only). Defer MFA and Developer Platform to subsequent maturity phases unless Completion Review expands scope.

---

## 10. Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| Phases 1–27 frozen | Hard | Consume only |
| Admin auth / permissions | Hard | Reuse tiers + permissions |
| Vendors / tenants / feature flags tables | Hard | Canonical sources |
| `039_enterprise_mdm.sql` | Soft | Wire or migrate with honesty |
| Phase 27 Compliance | Soft | Deep-link only |
| Phase 24 Integrations | Soft | Do not fork webhooks |
| Integrated Live QA (19–27) | Parallel gate | Certification, not Phase 28 scope |
| Bull/Redis | STOP if required | Document + wait for approval |

---

## 11. Risks

| Risk | Mitigation |
|------|------------|
| Re-implementing MDM as a second config store | Prefer wire `039` or migrate existing event-config dictionaries — one owner |
| Vendor Governance inventing KYC warehouse | Compose vendors + negotiation standing + audit only |
| Scope creep into MFA + SDK in same sprint | Keep Phase 28 = control plane; size Large not Enterprise |
| Mock engines left as dual truth | Demote engines; Nest wins |
| Touching frozen Marketing/Finance | Read-only; no campaign/ledger redesign |
| Treating Live QA as Phase 28 | Keep gate separate |

---

## 12. Implementation roadmap (planning only — do not implement now)

### P0

1. Nest MDM module (CRUD/list for dictionaries defined in `039` or approved mapping)  
2. Nest Vendor Governance APIs over canonical vendor standing  
3. Nest Tenant Admin read/control APIs (list, flags, status)  
4. Audit events for mutations  
5. Flutter: replace MDM / Vendor Governance / Tenant Admin engines with Nest clients  

### P1

6. Remove or quarantine in-memory engines as non-canonical  
7. Honest Unavailable states  
8. Permission checks aligned to existing admin matrix  

### P2

9. Deep-links to Launch Ops + Compliance  
10. Optional thin governance report CSV via existing reporting/compliance CSV patterns  

### Explicit non-goals this phase

- AI Copilot, Workflow Studio productization, Bull, SDK portal, marketplace ratings, i18n, promo codes  

---

## Deliverable checklist (this document)

| # | Item | Status |
|---|------|--------|
| 1 | Recommended Phase name | Enterprise Administration & Control Plane |
| 2 | Business objective | Nest-backed enterprise admin OS |
| 3 | Technical objective | Wire MDM / Vendor Governance / Tenant Admin |
| 4 | Existing foundations | Launch Ops, `039`, vendors/tenants, thin governance guard, audit |
| 5 | Missing capabilities | Nest MDM, Nest governance OS, Nest tenant admin, demote mocks |
| 6 | Architecture impact | Control plane over canonical data; frozen domains consume-only |
| 7 | Dependencies | Auth, tables, `039`, parallel Live QA gate |
| 8 | Risks | Dual truth, scope creep to MFA/SDK, forbidden redesigns |
| 9 | Implementation roadmap | P0–P2 planning only |

---

## FINAL RESULT

✅ Phase 28 Scope Defined

---

## STOP

Do **not** begin Phase 28 implementation.

Wait for Phase 28 Scope Review / approval before any code changes.
