# Phase 8 Compliance Readiness

Generated as part of Phase 8 gate evidence. Re-run export via:

```bash
curl -H "Authorization: Bearer $ADMIN_JWT" -H "X-Tenant-Id: $TENANT_ID" \
  http://localhost:8080/v1/compliance/export
```

## PII Classification

Users carry `pii_classification`: `standard` | `sensitive` | `restricted` (migration 025).

## Retention Policies

Per-tenant defaults in `compliance_retention_policies`:

| Domain | Default retention |
|--------|-------------------|
| Audit log | 365 days |
| Finance records | 2555 days (~7 years) |

## Data Deletion Workflow

`data_deletion_requests` table tracks:

- `pending` → `processing` → `completed` | `rejected`
- API: `POST /v1/compliance/deletion-requests` (requires `tenant.manage`)

## Audit Export Bundle

`GET /v1/compliance/export` returns:

- Retention policy snapshot
- PII classification counts + user list
- Audit log (latest 5000 rows)
- Security events (latest 1000 rows)
- Deletion requests

## Gate Verification

Compliance section passes when export and retention endpoints succeed with admin JWT + `tenant.manage` permission.
