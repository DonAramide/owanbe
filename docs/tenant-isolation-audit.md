# Phase 8 — Tenant Isolation Audit

Baseline: `v0.8.0-super-admin-complete`  
Migration: `025_phase8_security.sql`

## Scope

Every tenant-scoped endpoint must enforce isolation via:

1. **`X-Tenant-Id` header** validated by `TenantHeaderGuard` against JWT `app_metadata.tenant_id`
2. **SQL queries** scoped with `tenant_id = $n` (or join through tenant-scoped parent rows)
3. **`@SkipTenant()`** only where cross-tenant or infra access is intentional

## `@SkipTenant` Usages (documented)

| Location | Route prefix | Reason |
|----------|--------------|--------|
| `health.controller.ts` | `GET /health` | Infra liveness probe — no tenant context |
| `quaser-webhook.controller.ts` | `POST /webhooks/quaser` | External payment webhook — tenant resolved from payload |
| `super-admin.controller.ts` | `/super-admin/*` | Control tower — intentional cross-tenant reads/writes |

## Domain Audit

### Events

| Endpoint | Isolation mechanism | Cross-tenant risk |
|----------|---------------------|-------------------|
| `GET /events` | `@TenantId()` → `listPublic(tenantId)` | Low — catalog filtered |
| `GET /events/:id/manage` | Organizer ownership check in service | Medium — verified in gate |
| `POST /events` | Commerce actor tenant + organizer link | Low |

### Tickets / Commerce

| Endpoint | Isolation mechanism |
|----------|---------------------|
| Ticket orders | `commerceActor.tenantId` on all writes |
| Entitlements | Join through `events.tenant_id` |

### Finance

| Endpoint | Isolation mechanism |
|----------|---------------------|
| Organizer finance | `tenant_id` on summaries + payouts |
| Admin finance | `@TenantId()` on all `/admin/*` routes |
| Super-admin finance | `@SkipTenant()` — super_admin role only |

### Operations

| Endpoint | Isolation mechanism |
|----------|---------------------|
| Check-ins / incidents | Event scoped via organizer/vendor membership |

## Verification

- Gate script: `node scripts/verify-phase8-identity-security.js` (tenant isolation section)
- Unit tests: `services/api/test/tenant-isolation.spec.ts`
- Cross-tenant JWT with wrong `X-Tenant-Id` must not return another tenant's private data

## Tenant B Fixture

Gate seeds tenant `99999999-9999-4999-8999-999999999999` with client-only user for negative tests.
