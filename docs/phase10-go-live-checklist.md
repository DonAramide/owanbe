# Phase 10 — Go-Live Checklist

**Target release:** `v1.0.0-production-ready` (after Phase 10 gate PASS)

## Production Environment

- [ ] `NODE_ENV=production`
- [ ] `INTEGRATIONS_MODE=production`
- [ ] Postgres managed instance with connection pooling
- [ ] API deployed behind load balancer (min 2 instances)
- [ ] Mobile app points to production `OWANBE_API_BASE`

## Secrets (never commit)

- [ ] `SUPABASE_JWT_SECRET` — rotated from dev default
- [ ] `QUASER_ROUTER_API_KEY` + `QUASER_WEBHOOK_SECRET`
- [ ] `RESEND_API_KEY` or `NOTIFICATION_WEBHOOK_URL`
- [ ] `SUPABASE_SERVICE_ROLE_KEY` (API only, not mobile)
- [ ] `ALERT_WEBHOOK_URL` for on-call

## Domains & TLS

- [ ] API domain (e.g. `api.owanbe.app`) with TLS 1.2+
- [ ] `PUBLIC_API_BASE_URL=https://api.owanbe.app`
- [ ] Quaser webhook URL registered: `https://api.owanbe.app/webhooks/quaser`
- [ ] Mobile Supabase project configured for production auth

## Monitoring

- [ ] `/health` probed every 30s
- [ ] `/metrics` scraped by Prometheus/Grafana
- [ ] Alert webhook tested (send test CRITICAL alert)
- [ ] Super Admin Security Center reviewed pre-launch

## Backups

- [ ] Daily Postgres backup scheduled
- [ ] Restore drill completed (see disaster recovery runbook)
- [ ] `verify-phase10-disaster-recovery.js` PASS

## Support Runbooks

- [ ] `docs/phase10-disaster-recovery-runbook.md`
- [ ] `docs/phase10-operational-dashboard-checklist.md`
- [ ] `docs/phase8-identity-security-report.md`
- [ ] `docs/phase9-production-integrations-report.md`
- [ ] On-call rotation defined

## Gate Verification

```bash
node scripts/verify-phase10-launch-readiness.js
```

All six sections must PASS before declaring **v1.0.0-production-ready**.
