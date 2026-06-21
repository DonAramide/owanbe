# Phase 10 — Disaster Recovery Runbook

**Baseline:** v0.9.0-security-pass + Phase 9 Production Integrations

## 1. Database Backup

### Automated (production)
- Schedule daily `pg_dump` with 30-day retention (object storage).
- Verify backup size trend weekly.

```bash
pg_dump "$DATABASE_URL" -Fc -f "owanbe-$(date +%Y%m%d).dump"
```

### Verification
```bash
node scripts/verify-phase10-disaster-recovery.js
```

## 2. Database Restore

1. Stop API traffic (maintenance mode / scale to 0).
2. Restore to a new database instance first (staging validation).
3. Point `DATABASE_URL` to restored instance.
4. Run smoke test: `node scripts/verify-phase10-e2e-certification.js`.

```bash
pg_restore -d owanbe_restored owanbe-YYYYMMDD.dump
```

## 3. Application Rollback

1. Revert to last known-good image/tag (`v0.9.0-security-pass` minimum).
2. Migrations 016–024 are frozen — do not roll back schema without DBA review.
3. Phase 8+ migrations (025+) are additive; rollback is code-only when possible.

## 4. Webhook Recovery

Payment and payout state is reconciled via idempotent Quaser webhooks.

1. Inspect `reconciliation_reports` for open items.
2. Run admin reconciliation: `POST /v1/admin/finance/reconciliation/run`.
3. Recover missing capture ledger: `POST /v1/admin/finance/reconciliation/recover-capture`.
4. Replay webhooks from Quaser dashboard for missed events (never trust payload tenant_id).

## 5. Queue Recovery

Owanbe has no external message queue. Recovery paths:

- **Finance timeout sweep** — marks stale payments/payouts failed (`FINANCE_TIMEOUT_SWEEP_MS`).
- **Idempotent webhooks** — safe to replay.
- **Notification deliveries** — inspect `notification_deliveries` for failed rows; retry manually.

## 6. RTO / RPO Targets (launch)

| Component | RPO | RTO |
|-----------|-----|-----|
| Postgres | 24h (daily backup) | 4h |
| API | 0 (stateless) | 30m |
| Quaser webhooks | Event-sourced | 1h replay |

## 7. Escalation

1. On-call engineer — restore API + DB connectivity.
2. Platform admin — reconciliation + finance freeze.
3. Super admin — tenant feature flag disable (`ticket_commerce`, `finance`).
