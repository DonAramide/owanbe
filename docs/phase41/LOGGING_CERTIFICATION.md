# Phase 41 — Logging Certification

**Generated:** 2026-06-26T11:42:08.590Z  
**Result:** PASS

## Structured request logs

Each HTTP request logs (via `RequestLogMiddleware`):

| Field | Source |
|-------|--------|
| requestId | `RequestIdMiddleware` |
| tenantId | `X-Tenant-Id` header |
| userId | JWT (post-auth) |
| eventId | Route params when present |
| durationMs | Response finish |
| status | HTTP status code |

## Client safety

- `OwanbeExceptionFilter` returns `request_id` in JSON errors — no stack traces to clients
- Server-side errors logged with `requestId` only

## Verification

```bash
# Tail API logs during beta script soak; confirm fields on sample lines
```
