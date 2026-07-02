# Phase 43.4 — Security Hardening Report

**Date:** 2026-06-04  
**Scope:** API, Flutter clients, integrations  
**Prior art:** `docs/phase41/SECURITY_CERTIFICATION.md`

---

## Executive summary

Owanbe API implements defense-in-depth: JWT validation, tenant header guard, RBAC permissions matrix, Quaser HMAC webhooks, rate limiting, and security headers. Production builds disable mock persistence. Remaining gaps are operational (secrets enforcement at boot, metrics endpoint auth, CORS schema) rather than missing auth primitives.

**Security posture:** Strong foundation — **CONDITIONAL PASS** pending staging secret audit and `/metrics` hardening.

---

## Verification matrix

| Control | Status | Evidence | Gap |
|---------|--------|----------|-----|
| JWT validation | PASS | `passport-jwt`, payload util tests | Token refresh UX on mobile |
| RBAC | PASS | `PermissionsGuard`, `RolesGuard` specs | — |
| Tenant isolation | PASS | `tenant-header.guard`, isolation spec | Log used header before Phase 43 fix |
| Role escalation | PASS | Guards reject cross-tenant | — |
| Permission matrix | PASS | Commerce/finance policy spec | Document matrix in admin |
| Public routes | PASS | Explicit `@Public()` decorators | Review new routes each release |
| Storage uploads | PASS | Proxy + tenant path | Size limits — verify config |
| Media proxy | PASS | Signed/proxied access | — |
| Webhook verification | PASS | Quaser HMAC util spec | `QUASER_WEBHOOK_SECRET` not required at boot in prod schema |
| Quaser signature | PASS | `quaser-signature.util.spec.ts` | Sandbox E2E partial (Phase 41) |
| Rate limiting | PASS | `OwanbeThrottlerGuard` spec | In-memory — not distributed |
| CORS | PARTIAL | Env-driven origins | `CORS_ORIGINS` not in Joi boot schema |
| Security headers | PASS | Helmet-style middleware | — |
| Session expiry | PASS | JWT `exp` enforced | Mobile refresh handling |
| Audit logging | PASS | Super-admin audit writes | PII in notification debug logs |
| Dependency CVEs | REVIEW | `npm audit` on CI | Run before release |

---

## JWT & session

- Bearer tokens validated on protected routes.
- `TenantHeaderGuard` aligns `x-tenant-id` with JWT tenant claim — prevents cross-tenant header spoofing.
- Mobile stores session via Supabase auth; API calls attach tenant header from session.

---

## RBAC & permissions

- Role → permission mapping tested in `permissions.guard.spec.ts`.
- Finance/commerce dual-write policy tested.
- Vendor vs organizer vs admin routes use distinct guard stacks.

---

## Tenant isolation

- SQL queries parameterized with `tenant_id` from actor context.
- `tenant-isolation.spec.ts` covers cross-tenant rejection.
- **Fixed (Phase 43):** Request logs now use resolved `req.tenantId`.

---

## Public routes & webhooks

- Health (`/health`) and metrics (`/metrics`) exposed — metrics should be internal-only in production (P1).
- Quaser webhooks require valid signature — util tests pass; production requires secret rotation runbook.

---

## Storage & media

- Uploads flow through API storage proxy with tenant scoping.
- Metric: `storage_proxy_upload_total`.

---

## Flutter client

- `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` in `mobile/assets/env/supabase.env`.
- No stack traces in customer portal UI after Phase 43.6 pass.
- Secrets in client: Supabase anon key only (expected public).

---

## PII & logging

- Notification service may log recipient identifiers at debug level — **mask in production log level**.
- Request logs include `userId`, `tenantId`, `eventId` — acceptable for ops; no passwords/tokens.

---

## Recommendations

| ID | Action | Priority |
|----|--------|----------|
| SEC-1 | Require `QUASER_WEBHOOK_SECRET` when `NODE_ENV=production` | P0 |
| SEC-2 | Authenticate `/metrics` (mTLS or bearer) | P1 |
| SEC-3 | Add `CORS_ORIGINS` to env validation schema | P1 |
| SEC-4 | Distributed rate limit (Redis) for multi-pod | P1 |
| SEC-5 | Redact PII in notification logs | P2 |

---

## Verification

- `node scripts/verify-phase10-security-recert.js`
- `services/api` guard unit tests (10 files)
- Manual: attempt cross-tenant API call — expect 403
