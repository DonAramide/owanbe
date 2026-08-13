# PHASE 30 — PLATFORM CERTIFICATION CHECKLIST

**Status:** Executable certification framework (Certification Mode)  
**Date:** 2026-08-03  
**Reference:** `docs/PHASE30_SCOPE_AND_GAP_ANALYSIS.md`  
**Harness:** `scripts/phase30_platform_certification_qa.mjs`  
**Evidence output:** `docs/evidence/phase30_certification_run.json`  
**Constraint:** Validate existing systems only — no new product capabilities

---

## 1. Certification framework

### 1.1 Scope

| In scope | Out of scope |
|----------|--------------|
| Integrated Live QA Phases 14–29 | SDK / partner API keys |
| Production readiness probes | AI Studio |
| Security readiness validation | SSO federation suite |
| Data consistency (Finance → Analytics → Reporting → Compliance) | i18n / multi-region |
| Certification evidence pack | Device MDM expansion |
| Architecture validation chain | Bull/Redis migration |
| | New business modules |

### 1.2 Evidence collection process

1. Confirm API process is up (`/health`, `/metrics` at process root — not under `/v1`).
2. Confirm DB connectivity via health `checks.database`.
3. Apply migrations through `062` (and related 055–061) before treating Unavailable as FAIL.
4. Run `node scripts/phase30_platform_certification_qa.mjs` with optional `API_ORIGIN`, `EVENT_ID`.
5. Script mints organizer + admin JWTs from `services/api/.env` `SUPABASE_JWT_SECRET` (or uses `ACCESS_TOKEN` / `ADMIN_ACCESS_TOKEN`).
6. Record each check as **PASS** | **FAIL** | **SKIP** | **PARTIAL** with HTTP status + notes.
7. Persist JSON evidence; copy summary into `PHASE30_PLATFORM_CERTIFICATION_REPORT.md`.
8. Mark Unavailable that matches architecture (honest) as **PASS (Unavailable honesty)** when response is coherent — not as product FAIL.

### 1.3 Pass / fail criteria

| Verdict | Criteria |
|---------|----------|
| **PASS** | HTTP 2xx (or documented honest Unavailable payload); body coherent; permissions enforced where expected |
| **PARTIAL** | Endpoint reachable but dependent schema/secret/config missing; or known Phase 29 session limitation |
| **FAIL** | Unexpected 5xx, auth bypass, dual money truth, invented business data, or silent fake success |
| **SKIP** | Missing `EVENT_ID` / role / env for that scenario; must not be counted as PASS |

**Certification gate (overall):**

- **CERTIFIED** — all P0 journeys PASS or honest Unavailable; no P0 FAIL; P1 security auth/RBAC PASS; data-ownership invariants PASS  
- **CERTIFIED WITH LIMITATIONS** — P0 mostly PASS; documented PARTIAL on migrations/secrets/sessions; no security FAIL  
- **NOT CERTIFIED** — any P0 security FAIL, money dual-truth FAIL, or auth/RBAC bypass  

---

## 2. Environment gate (must record before journeys)

| # | Check | Expected | Result |
|---|-------|----------|--------|
| E1 | API listening | Health 200 | |
| E2 | Database | `checks.database.status=ok` | |
| E3 | Migrations 055–062 | automation/webhook/compliance/identity relations exist | |
| E4 | Payments | `payments` configured or documented | |
| E5 | Quaser webhook secret | present in production; may be missing in dev | |
| E6 | Integrations mode | `development` or `production` documented | |
| E7 | Metrics scrape | `/metrics` Prometheus text | |
| E8 | Auth secret | `SUPABASE_JWT_SECRET` available for harness | |

---

## 3. P0 — Phases 14–18 QA pack (Attendee / Organizer core)

**Chain:** Publishing → Discovery → Ticket purchase → Invitation → RSVP → Entitlement → Check-in → Finance → Analytics

| ID | Scenario | API / flow | Expected | Result |
|----|----------|------------|----------|--------|
| A1 | Organizer event list / create surface | `GET`/`POST /v1/events` (auth) | 2xx or capability deny | |
| A2 | Publish path | `POST /v1/events/:id/publish` | 2xx when ready; validation errors otherwise | |
| A3 | Public discovery tiers | `GET /v1/events/:id/tiers` | Hidden/future tiers filtered | |
| A4 | Ticket order rules | `POST …/ticket-orders` | Commerce rules enforced (422 on illegal) | |
| A5 | Invitations hub | `GET /v1/events/:id/invitations` | 2xx for organizer | |
| A6 | RSVP validate | `GET /v1/invitations/validate` | Token validation or clear error | |
| A7 | Attendee guest invitations | `GET /v1/me/guest-invitations` | 2xx | |
| A8 | Door / check-in | `GET /v1/events/:id/door-summary` | 2xx with `ops.door` | |
| A9 | Finance hub | `GET /v1/organizers/me/finance/hub` | 2xx; Finance owns money | |
| A10 | Analytics portfolio | `GET /v1/organizers/me/analytics/portfolio` | 2xx; consumes finance truth | |
| A11 | Flutter smoke (manual) | Organizer publish → attendee discover → buy → RSVP → door | No parallel SoT | |

**Permissions:** Staff without finance capability → `ORG_CAPABILITY_DENIED` on finance (see B4).

---

## 4. P0 — Phases 19–29 Business Operations QA pack

**Chain:** Vendor CRM → Reporting → Organization → Automation → Integrations → Marketing → Compliance → Control Plane → Identity Security

| ID | Scenario | API / flow | Expected | Result |
|----|----------|------------|----------|--------|
| B1 | Reporting catalog | `GET /v1/organizers/me/reports/catalog` | 2xx; packs from canonical sources | |
| B2 | Team / org | `GET /v1/organizers/me/team` + membership | 2xx | |
| B3 | Automations list | `GET /v1/organizers/me/automations` | 2xx or honest schema Unavailable | |
| B4 | Automation observability | `GET …/automations/observability` | 2xx or Unavailable | |
| B5 | Integrations status | `GET …/integrations/status` | 2xx | |
| B6 | Webhook deliveries | `GET …/integrations/webhooks/deliveries` | 2xx or Unavailable | |
| B7 | Marketing channels/campaigns | `GET …/marketing/channels` + campaigns | 2xx or honest Unavailable | |
| B8 | Compliance dashboard | `GET /v1/compliance/dashboard` (admin) | 2xx | |
| B9 | Compliance retention / activity | retention + activity | 2xx | |
| B10 | Control Plane dashboard | `GET /v1/control-plane/dashboard` | 2xx | |
| B11 | Control Plane MDM domains | `GET …/mdm/domains` | 2xx | |
| B12 | Control Plane devices | `GET …/devices` | Honest Unavailable OK | |
| B13 | Identity MFA (self) | `GET /v1/me/security/mfa` | 2xx | |
| B14 | Identity sessions (self) | `GET /v1/me/security/sessions` | 2xx or PARTIAL | |
| B15 | Identity Security Center | `GET /v1/identity-security/center` (admin) | 2xx | |
| B16 | Vendor CRM / governance | Control Plane vendors or vendor ops list | 2xx or capability deny | |
| B17 | Audit trails | compliance activity / identity center / control-plane activity | Non-empty structure or empty list — not invented rows | |

---

## 5. P1 — Production readiness review

| ID | Area | Validation | Result |
|----|------|------------|--------|
| P1 | Environment configuration | Health integrationsMode + payments + notifications | |
| P2 | Database migrations | Missing-relation checks in health → PARTIAL until applied | |
| P3 | Secrets | JWT secret present; Quaser webhook secret for prod | |
| P4 | Monitoring | `/metrics` scrapeable | |
| P5 | Logging | API returns `request_id` on errors | |
| P6 | Error handling | Structured `{code,message,request_id}` | |
| P7 | Recovery paths | Health surfaces Unavailable subsystems without crashing API | |

---

## 6. P1 — Security readiness

| ID | Area | Validation | Result |
|----|------|------------|--------|
| S1 | Authentication | Bearer required on protected routes (401/403 without) | |
| S2 | MFA | `/me/security/mfa` + admin MFA paths exist | |
| S3 | Sessions | Visibility/revoke; PARTIAL if Auth Admin limited | |
| S4 | RBAC | Organizer vs admin_super vs staff capability matrix | |
| S5 | Organization capabilities | Finance/analytics deny for insufficient caps | |
| S6 | Tenant isolation | `X-Tenant-Id` + JWT tenant; cross-tenant deny | |
| S7 | Audit evidence | Security / compliance / control-plane activity endpoints | |

---

## 7. P1 — Data consistency review

| ID | Invariant | How to verify | Result |
|----|-----------|---------------|--------|
| D1 | Finance owns money truth | Finance hub / event summary are SoT for monetary totals | |
| D2 | Analytics consumes finance | Portfolio/event intelligence `monetarySource=organizer_finance` (or equivalent) | |
| D3 | Reporting consumes canonical data | Report packs cite finance/ops sources — no parallel ledger | |
| D4 | Compliance governs lifecycle | Retention / deletion / export APIs do not invent business rows | |

---

## 8. Final architecture validation chain

```
Identity → Authorization → Business Systems → Automation → Integrations
  → Reporting → Compliance → Audit Evidence
```

Mark each layer reachable and non-redesigned:

| Layer | Consume-only? | Live probe | Result |
|-------|---------------|------------|--------|
| Identity | Yes | MFA / sessions / center | |
| Authorization | Yes | RBAC + org caps | |
| Business Systems | Yes | Events / tickets / finance / CRM | |
| Automation | Yes | Automations + health | |
| Integrations | Yes | Status + webhooks | |
| Reporting | Yes | Catalog | |
| Compliance | Yes | Dashboard | |
| Audit Evidence | Yes | Activity feeds | |

---

## 9. Deferred (post-certification) — do not execute as Phase 30

- Partner API keys / SDK  
- SSO (Entra/Okta/SAML)  
- Device MDM expansion  
- i18n / multi-region  
- Bull/Redis as phase  
- AI Studio  

---

## 10. Sign-off

| Role | Name | Date | Verdict |
|------|------|------|---------|
| Engineering / QA | | | |
| Platform Certification Review | | | **WAIT** — do not start future phase |
|
