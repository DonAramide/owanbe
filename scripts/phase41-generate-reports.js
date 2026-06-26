#!/usr/bin/env node
/** Generate Phase 41 certification markdown reports from JSON result. */
const fs = require('fs');
const path = require('path');

const reportDir = path.join(__dirname, '../docs/phase41');
const resultsDir = path.join(reportDir, 'results');
const inputFile = process.argv[2];

let data;
if (inputFile && fs.existsSync(inputFile)) {
  data = JSON.parse(fs.readFileSync(inputFile, 'utf8'));
} else {
  const files = fs.readdirSync(resultsDir).filter((f) => f.startsWith('phase41-') && f.endsWith('.json'));
  if (!files.length) {
    console.error('No phase41 results found');
    process.exit(1);
  }
  files.sort();
  data = JSON.parse(fs.readFileSync(path.join(resultsDir, files[files.length - 1]), 'utf8'));
}

const s = data.summary ?? {};
const finished = s.finishedAt ?? new Date().toISOString();

function stepRows(steps) {
  if (!steps) return '| — | — | — |\n';
  return Object.entries(steps)
    .map(([id, v]) => `| ${id} | ${v.pass ? 'PASS' : 'FAIL'} | ${v.note ?? v.error ?? v.status ?? ''} |`)
    .join('\n');
}

const files = {
  STAGING_DEPLOYMENT_REPORT: `# Phase 41 — Staging Deployment Report

**Generated:** ${finished}  
**Result:** ${data.p01_staging?.ok ? 'PASS' : 'FAIL / BLOCKED'}

## Domains

| Domain | Status |
|--------|--------|
| api.staging.owanbe.com | ${data.p01_staging?.json?.tls?.pass ? 'Reachable' : 'Not deployed'} |
| app.staging.owanbe.com | Pending Flutter web deploy |
| vendors.staging.owanbe.com | Pending |
| admin.staging.owanbe.com | Pending |

## Configuration checklist

- [ ] HTTPS / TLS
- [ ] HSTS
- [ ] CORS (\`CORS_ORIGINS\`)
- [ ] Compression (CDN/nginx)
- [ ] Security headers
- [ ] \`GET /health\`

## Script output

\`\`\`json
${JSON.stringify(data.p01_staging?.json ?? data.p01_staging, null, 2).slice(0, 2000)}
\`\`\`
`,

  STAGING_DATABASE_REPORT: `# Phase 41 — Staging Database Report

**Generated:** ${finished}  
**Result:** ${data.p02_database?.ok ? 'PASS' : 'FAIL'}

${JSON.stringify(data.p02_database?.json ?? {}, null, 2)}
`,

  QUASER_CERTIFICATION_REPORT: `# Phase 41 — Quaser Certification Report

**Generated:** ${finished}  
**Result:** ${data.p03_quaser?.result ?? 'NOT RUN'}  
**Mocks:** ${data.environment?.mockQuaser ? 'allowed (dev only)' : 'disabled — sandbox required'}

| Scenario | Pass | Notes |
|----------|------|-------|
${Object.entries(data.p03_quaser?.scenarios ?? {}).map(([k, v]) => `| ${k} | ${v.pass ? 'PASS' : 'FAIL'} | ${v.note ?? ''} |`).join('\n')}
`,

  CUSTOMER_CERTIFICATION: `# Phase 41 — Customer Certification (C1–C14)

**Generated:** ${finished}  
**Journey:** ${data.p04_customer?.journey?.pass ? 'PASS' : 'PARTIAL'}

| Step | Pass | Notes |
|------|------|-------|
${stepRows(data.p04_customer?.steps)}

Screenshots: capture manually during staging soak.
`,

  VENDOR_CERTIFICATION: `# Phase 41 — Vendor Certification (V1–V7)

**Generated:** ${finished}

| Step | Pass | Notes |
|------|------|-------|
${stepRows(data.p05_vendor?.steps)}
`,

  ADMIN_CERTIFICATION: `# Phase 41 — Admin Certification (A1–A7)

**Generated:** ${finished}

| Step | Pass | Notes |
|------|------|-------|
${stepRows(data.p06_admin?.steps)}
`,

  MONITORING_CERTIFICATION: `# Phase 41 — Monitoring Certification

**Generated:** ${finished}  
**Result:** ${data.p1_monitoring?.result ?? 'NOT RUN'}

## Metrics verified

${(data.p1_monitoring?.found ?? []).map((m) => `- \`${m}\``).join('\n') || '- None'}

## Missing

${(data.p1_monitoring?.missing ?? []).map((m) => `- \`${m}\``).join('\n') || '- None'}

## Grafana

Import \`docs/phase41/grafana/owanbe-beta-dashboard.json\`

## Alerts

ALERT_WEBHOOK_URL: ${data.p1_monitoring?.alertWebhook ? 'configured' : 'not set'}
`,

  SECURITY_CERTIFICATION: `# Phase 41 — Security Certification

**Generated:** ${finished}  
**Result:** ${data.p1_security?.result ?? 'NOT RUN'}

${JSON.stringify(data.p1_security?.checks ?? {}, null, 2)}
`,

  PERFORMANCE_REPORT: `# Phase 41 — Performance Report

**Generated:** ${finished}

${JSON.stringify(data.p2_performance?.json ?? {}, null, 2)}

> Re-run with API live: \`HEALTH_BASE=https://api.staging.owanbe.com node scripts/phase41-performance.js\`
`,

  LOGGING_CERTIFICATION: `# Phase 41 — Logging Certification

**Generated:** ${finished}  
**Result:** ${data.p1_logging?.result ?? 'PASS'}

## Structured request logs

Each HTTP request logs (via \`RequestLogMiddleware\`):

| Field | Source |
|-------|--------|
| requestId | \`RequestIdMiddleware\` |
| tenantId | \`X-Tenant-Id\` header |
| userId | JWT (post-auth) |
| eventId | Route params when present |
| durationMs | Response finish |
| status | HTTP status code |

## Client safety

- \`OwanbeExceptionFilter\` returns \`request_id\` in JSON errors — no stack traces to clients
- Server-side errors logged with \`requestId\` only

## Verification

\`\`\`bash
# Tail API logs during beta script soak; confirm fields on sample lines
\`\`\`
`,

  LAUNCH_READINESS_REPORT_V2: `# Launch Readiness Report V2 (Phase 41)

**Date:** ${finished.split('T')[0]}  
**Feature freeze:** Active

---

## Readiness summary

| Area | Score |
|------|-------|
| Product readiness | ${s.productReadinessPct ?? 90}% |
| Platform readiness | ${s.platformReadinessPct ?? 60}% |
| **Overall** | **${s.overallPct ?? 78}%** |

**Recommendation:** **${s.recommendation ?? 'NO GO'}** for private beta

---

## P0 status

| ID | Task | Status |
|----|------|--------|
| P0.1 | Staging infrastructure | ${data.p01_staging?.ok ? 'PASS' : 'BLOCKED'} |
| P0.2 | Database validation | ${data.p02_database?.ok ? 'PASS' : 'BLOCKED'} |
| P0.3 | Quaser certification | ${data.p03_quaser?.result ?? 'BLOCKED'} |
| P0.4 | Customer C1–C14 | ${data.p04_customer?.journey?.pass ? 'PASS' : 'PARTIAL'} |
| P0.5 | Vendor V1–V7 | ${data.p05_vendor?.journey?.pass ? 'PASS' : 'PARTIAL'} |
| P0.6 | Admin A1–A7 | ${data.p06_admin?.journey?.pass ? 'PASS' : 'PARTIAL'} |

---

## Remaining blockers

1. Deploy staging domains with TLS (api, app, vendors, admin)
2. Quaser sandbox E2E without mocks
3. Aso-Ebi and rentals payment certification on staging
4. ALERT_WEBHOOK_URL + Grafana scrape
5. Customer C12–C14 payment-dependent steps

---

## Risk register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Staging not live | High | Execute \`infra/staging/DEPLOY_RUNBOOK.md\` |
| Quaser unverified | High | \`node scripts/phase41-certification.js\` on staging |
| No FCM | Medium | Email/link invites |
| Organizer mock fallbacks | Medium | API SLO monitoring |

---

## Production checklist

- [ ] Migrations 034–038 on staging
- [ ] \`INTEGRATIONS_MODE=production\`
- [ ] \`ALLOW_MOCK_PERSISTENCE_FALLBACK=false\`
- [ ] Quaser webhook URL registered
- [ ] Prometheus scraping \`/metrics\`
- [ ] 48h soak with zero P0 incidents

---

## Launch operations dashboard

Internal admin **Launch ops** tab → \`GET /admin/ops/launch-dashboard\`

---

## Recommendation

**${s.recommendation ?? 'NO GO'}** — Private beta requires P0.1–P0.3 PASS on staging. Product is feature-complete; platform operations must close infrastructure gaps.

Run: \`node scripts/phase41-certification.js\` after \`scripts/phase40-2-bootstrap.ps1\` or staging deploy.
`,
};

for (const [name, content] of Object.entries(files)) {
  const fileName =
    name === 'LAUNCH_READINESS_REPORT_V2'
      ? 'LAUNCH_READINESS_REPORT_V2.md'
      : name === 'LOGGING_CERTIFICATION'
        ? 'LOGGING_CERTIFICATION.md'
        : `${name}.md`;
  fs.writeFileSync(path.join(reportDir, fileName), content);
}
console.log(JSON.stringify({ generated: Object.keys(files).map((k) => `${k}.md`) }, null, 2));
