# PHASE 29 — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-02  
**Method:** Architecture-derived (Phases 1–28 + live security/identity code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **1–28** architecture-complete — Phase 29 may **consume** only; must not redesign frozen domains  
**Evolution layer:** Final platform maturity — identity/security trust surface after Control Plane  
**Parallel gate:** Integrated Live QA / certification for Phases 19–28 remains a **planning/execution gate**, not a substitute for Phase 29 product scope

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Enterprise Control Plane shipped (Phase 28); compliance + business ops complete |
| **Proposed domain** | Identity & Security Productization — **correct next maturity capability** |
| **Why this over API keys / devices / SSO suite** | MFA/SOC/session UI is theatrical beside real Nest authz + `platform_security_events`; Phase 28 already ranked this #2 |
| **Natural Phase 29** | Make MFA, Security Center honesty, and account/session controls **operable** — extend Supabase Auth + existing security APIs; do **not** redesign authentication or RBAC |
| **IA** | Security 360 / enterprise auth / admin identity surfaces consuming Nest + Supabase factors (not `SecurityEngine` / seeded MFA) |
| **Overall** | **✅ Phase 29 Scope Defined** |

After Control Plane, operators can govern tenants, vendors, and dictionaries — but login assurance and security ops UIs remain largely theatrical. The remaining maturity gap is **trustworthy identity & security operations**, not another admin OS or growth feature.

---

## 2. Platform state — what naturally follows

```
Attendee / Organizer / Business Ops
        ↓
Marketing (26) → Compliance (27) → Control Plane (28)
        ↓
??? Identity & security trust surface
```

| Layer | Status after Phase 28 |
|-------|----------------------|
| Core product loops | Architecture-complete — consume |
| Compliance / Control Plane | Implemented — consume |
| JWT auth + RBAC + tenant isolation | **Fully Implemented** |
| Org membership / capabilities | **Fully Implemented** (Phase 22) |
| Secrets encryption / throttling | **Fully Implemented** |
| `platform_security_events` + Nest security center API | **Partially Implemented** (backend real; Flutter mixed) |
| MFA / TOTP | **Frontend Only** (seeded provider; hardcoded enrollment secret) |
| Enterprise SSO (Entra/Okta/SAML) | **Frontend Only** chips (`enabled: false`); Google OAuth real |
| Session revoke / inventory | **Not Implemented** (Supabase session local; no Nest revoke OS) |
| Admin user suspend lifecycle | **Partial** (status enum + RolesGuard block; weak admin user ops UI) |
| `platform_api_keys` | **Hidden / Not Implemented** |
| Device trust | **Unavailable** (Phase 28 honest) |

**Next missing platform capability:** Operable **Identity & Security Productization** — Nest/Supabase-backed MFA, honest Security Center, and account/session controls that make Control Plane and Compliance evidence trustworthy.

---

## 3. Why Phase 29 follows Phase 28

1. **Operate → Harden → Grow → Trust → Control → Identity Assurance** is coherent maturity sequencing. Control Plane actions and Compliance audits assume authentic operators; MFA/SOC theater undermines that chain.  
2. **Foundations exist** — Supabase JWT auth, Roles/Permissions guards, `users.status`, `platform_security_events`, `GET super-admin/security/center`, SecurityEventService, throttling, secrets crypto.  
3. **Gap is productization, not invention** — Flutter MFA/SecurityEngine/SSO chips already exist as shells; they do not systematically consume Nest/Supabase MFA.  
4. **Stabilization-safe** — extends identity/security surfaces; does **not** redesign authentication architecture or RBAC matrices.  
5. **Phase 28 deferral alignment** — MFA / SOC honesty / API keys / devices were explicitly deferred; MFA is the highest-value, foundation-ready item.

### Parallel (not Phase 29)

Integrated Live QA for Phases 19–28 remains under **Live QA Planning**. Developer API Platform and Device enrollment are follow-on maturity candidates (Phase 30+), not the Phase 29 name.

---

## 4. Phase definition

### Official Phase Name

**Phase 29 — Identity & Security Productization**

*(Working short name: Identity Security / Trust Surface)*

### Business Goal

Give platform operators and privileged users **trustworthy authentication assurance and security operations** — real MFA, honest security event visibility, and operable account/session controls — using existing Supabase Auth, Nest security events, and RBAC — so Control Plane and Compliance evidence rest on verified operators without inventing a second identity or permission system.

### Technical Goal

1. Productize **MFA enrollment / verification** via Nest + Supabase Auth MFA (or equivalent Nest-backed TOTP factors) — replace seeded `identity_mfa_provider` and hardcoded QR secrets as truth  
2. Make **Security Center / Security 360** primary KPIs and feeds consume Nest `platform_security_events` / `super-admin/security/center` — demote `SecurityEngine` theater  
3. Add **admin user lifecycle** ops (suspend / reactivate `users.status`) with audit — reuse `RolesGuard` `ACCOUNT_BLOCKED` enforcement  
4. Add **session visibility / revoke** where Supabase Admin APIs allow — honest Unavailable if not  
5. Surface honest **Unavailable** for Entra/Okta/SAML until a dedicated federation phase  
6. Deep-link Control Plane + Compliance from security workspace (consume, do not redesign)

### Primary Users

| User | Need |
|------|------|
| Platform Admin / Super-admin | MFA, security center, user suspend, session revoke |
| Privileged organizers / staff | MFA for high-assurance ops (policy-gated) |
| Security / compliance operators | Honest event feeds tied to audit |
| Attendees / vendors | Indirect — no auth redesign required in P0 |
| Developers | Not primary — API keys deferred |

### Primary Journeys

| ID | Journey |
|----|---------|
| J1 | Admin enrolls MFA via Nest/Supabase → verifies → subsequent login requires factor |
| J2 | Security Center shows live Nest security events (not hardcoded 96% score) |
| J3 | Admin suspends a user → `users.status` updated → JWT principal blocked by RolesGuard |
| J4 | Admin lists/revokes sessions (or sees Unavailable with reason) |
| J5 | Enterprise auth shell removes hardcoded TOTP secret; SSO chips stay Unavailable when unfinished |
| J6 | Existing RBAC / org capabilities unchanged — no permission-matrix redesign |

### Success Criteria

- [ ] MFA enrollment/verify for admin tiers uses Nest/Supabase — not local seed maps as SoT  
- [ ] Security Center / Security360 primary feeds Nest-backed (or honest Unavailable)  
- [ ] Admin user suspend/reactivate exists with audit_log  
- [ ] No RBAC redesign; no parallel identity store  
- [ ] Hardcoded MFA secrets removed from enrollment UX  
- [ ] Frozen domains 1–28 consume-only  
- [ ] Device inventory not invented; API keys not required for Phase 29 PASS  
- [ ] Live QA gate remains tracked separately  

---

## 5. Security maturity audit (Step 1)

| Area | Status | Phase 29? |
|------|--------|-----------|
| Authentication (JWT / Supabase) | Fully Implemented | Extend MFA only — **do not redesign** |
| Authorization / RBAC | Fully Implemented | Consume |
| Organization membership | Fully Implemented | Consume |
| Tenant isolation | Fully Implemented | Consume |
| Session management | Partial (local Supabase; no revoke OS) | **Yes — P1** |
| Secrets management | Fully Implemented (crypto/env) | Consume; demote rotate-key theater |
| MFA | Frontend Only | **Yes — P0** |
| Audit security events | Partial (Nest real; UI mixed) | **Yes — P0** |
| Identity lifecycle | Partial | **Yes — P0 user suspend** |

---

## 6. Codebase audit (Step 3)

| Capability | Classification | Evidence |
|------------|----------------|----------|
| JWT / Supabase auth | **Fully Implemented** | Nest `supabase-jwt.strategy.ts`; Flutter `owanbe_api_auth.dart`, `identity_platform.dart` |
| RolesGuard / PermissionsGuard / matrix | **Fully Implemented** | APP_GUARDs; `permission-matrix.ts`; Phase 8 SQL |
| Org capabilities (Phase 22) | **Fully Implemented** | `organizer-team`, `events-access.service.ts` |
| TenantHeaderGuard / SkipTenant | **Fully Implemented** | Global guard + control-plane/super-admin skip |
| Rate limiting | **Fully Implemented** | `OwanbeThrottlerGuard` + ThrottlerModule buckets |
| Secrets crypto | **Fully Implemented** | `EmailSecretsCrypto`; webhook ciphertext |
| `platform_security_events` | **Fully Implemented** (backend) | `024`/`025` SQL; `security-event.service.ts` |
| Nest security center API | **Fully Implemented** | `GET super-admin/security/center` |
| Flutter Security Center / SecurityEngine | **Frontend Only / Partial** | Hardcoded KPIs; mock threats; Nest consumed only in places |
| MFA / TOTP | **Frontend Only** | `identity_mfa_provider.dart`; hardcoded secret in `enterprise_auth_shell.dart`; **no Nest MFA routes** |
| Google OAuth | **Fully Implemented** | `signInWithGoogle` |
| Entra / Okta / SAML chips | **Frontend Only** | `enabled: false` in enterprise auth shell |
| Session revoke inventory | **Not Implemented** | No Nest session-admin APIs |
| Admin user suspend API | **Partially Implemented** | Status enum + RolesGuard; weak dedicated admin user ops |
| `platform_api_keys` | **Hidden / Not Implemented** | `043` stub; zero Nest usage |
| Device trust | **Not Implemented** | Phase 28 Unavailable |

### Reusable systems (must consume)

- Supabase Auth (JWT + OAuth + MFA factors if enabled)  
- `users` / `user_status` / RolesService principal loading  
- Permissions + Roles APP_GUARDs (no redesign)  
- `SecurityEventService` / `platform_security_events`  
- `AuditLogService`  
- Control Plane + Compliance deep-links  
- Existing throttling and secrets crypto  

---

## 7. Feature discovery (Step 4) — what belongs in Phase 29

### In Phase 29 (P0–P2)

| Item | Priority |
|------|----------|
| Nest/Supabase MFA enroll + verify + status | P0 |
| Security Center / Security360 Nest honesty (demote SecurityEngine) | P0 |
| Admin user suspend / reactivate + audit | P0 |
| Remove hardcoded MFA enrollment secrets | P0 |
| Session list / revoke (Supabase Admin) or Unavailable | P1 |
| MFA policy for admin tiers | P1 |
| Align enterprise_auth_shell MFA path | P1 |
| Honest Unavailable for unfinished SSO / key rotation | P1 |
| Deep-link Control Plane + Compliance | P2 |
| Google SSO polish only | P2 |

### Explicitly out of Phase 29

| Item | Why |
|------|-----|
| RBAC / permission-matrix redesign | Forbidden — already complete |
| Authentication architecture replacement | Forbidden — extend Supabase only |
| Full Entra/Okta/SAML federation suite | Enterprise creep — separate later |
| Developer SDK / `platform_api_keys` product | Strong Phase 30 candidate |
| Device enrollment MDM | Needs approved schema; Phase 28 Unavailable |
| AI Copilot / Workflow Studio / Bull | Forbidden / wrong maturity |
| Control Plane / Compliance redesign | Frozen — consume |
| Marketplace ratings / i18n | Growth/expansion — not identity |

### Ranked alternatives considered

| Rank | Domain | Decision |
|------|--------|----------|
| 1 | Identity & Security Productization | **Selected** |
| 2 | Developer / Partner API Platform | Phase 30 candidate |
| 3 | Device trust / enrollment | Requires schema approval first |

---

## 8. Architecture impact (Step 5)

| Layer | Impact |
|-------|--------|
| **Control Plane** | Consume deep-links; operators gain MFA assurance — no MDM/vendor redesign |
| **Organization** | Org capability matrix untouched; MFA policy may gate privileged users later |
| **Compliance** | Stronger actor assurance for DSAR/export evidence — consume Compliance APIs |
| **Integrations** | Secrets crypto untouched; API keys not required this phase |
| **Users** | Lifecycle suspend/reactivate + MFA factors on identity — same `users` table |
| **Workspace** | Security 360 / enterprise auth shells rewired to Nest/Supabase |

**Invariant:**

```
Supabase Auth + users (canonical identity)
        ↓
Existing RBAC / Tenant / Org capabilities
        ↓
Identity & Security Productization (MFA / sessions / honest SOC)
        ↓
Control Plane + Compliance evidence (trusted operators)
```

---

## 9. Effort estimation (Step 6)

| Scope band | Estimate |
|------------|----------|
| MFA + Security Center honesty + user suspend + session revoke | **Large** |
| + full enterprise SSO federation (Entra/Okta/SAML) | Approaches **Enterprise** — **do not combine** |
| `platform_api_keys` alone | Medium (prefer Phase 30) |
| Device enrollment | Large + schema STOP |

**Recommended Phase 29 sizing:** **Large** (Identity & Security only).

---

## 10. Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| Phases 1–28 frozen | Hard | Consume only |
| Supabase Auth project MFA capability | Hard | Prefer platform MFA factors over inventing TOTP store |
| RolesGuard / PermissionsGuard | Hard | No redesign |
| `platform_security_events` | Hard | SOC honesty source |
| `users.status` | Hard | Lifecycle |
| Control Plane / Compliance | Soft | Deep-link |
| Supabase Admin API for session revoke | Soft | Unavailable if credentials/policy block |
| Device schema / API keys | Out | Follow-on |

---

## 11. Risks

| Risk | Mitigation |
|------|------------|
| Inventing a parallel TOTP table beside Supabase | Prefer Supabase MFA factors; Nest orchestrates only |
| Redesigning RBAC “while we’re here” | Explicit STOP — consume matrix |
| Bundling SSO federation + MFA + API keys + devices | Keep Large not Enterprise; defer federation/keys/devices |
| Leaving SecurityEngine as dual truth | Demote theater; Nest events win |
| Fake device trust to “complete” Security 360 | Keep Unavailable |
| Breaking attendee login flows | MFA policy scoped to admin tiers first |

---

## 12. Implementation roadmap (planning only — do not implement now)

### P0

1. Nest MFA status / enroll / verify endpoints (Supabase-backed)  
2. Flutter: replace seeded MFA provider as SoT; remove hardcoded secrets  
3. Wire Security Center / Security360 KPIs to Nest security APIs  
4. Admin user suspend/reactivate + audit_log  

### P1

5. Session list/revoke Nest APIs (or honest Unavailable)  
6. MFA required policy for `ADMIN_TIERS` / `super_admin`  
7. Enterprise auth shell MFA path aligned; SSO chips Unavailable  

### P2

8. Deep-links to Control Plane + Compliance  
9. Google OAuth polish only  

### Explicit non-goals this phase

- Entra/Okta/SAML productization  
- `platform_api_keys` / SDK portal  
- Device enrollment  
- Bull / AI / Workflow Studio  

---

## Deliverable checklist (this document)

| # | Item | Status |
|---|------|--------|
| 1 | Recommended Phase name | Identity & Security Productization |
| 2 | Security objective | Trustworthy MFA + honest SOC + session/user lifecycle |
| 3 | Existing foundations | JWT, RBAC, tenant isolation, security events, secrets, throttling |
| 4 | Missing capabilities | Nest MFA, SOC honesty, session revoke, admin user suspend UX |
| 5 | Architecture impact | Extends Users/Security; Control Plane/Compliance/Org consume-only |
| 6 | Risks | Parallel TOTP store, RBAC creep, Enterprise SSO bundling |
| 7 | Implementation roadmap | P0–P2 planning only |

---

## FINAL RESULT

✅ Phase 29 Scope Defined

---

## STOP

Do **not** begin Phase 29 implementation.

Wait for Phase 29 Scope Review / approval before any code changes.
