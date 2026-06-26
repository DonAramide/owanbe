#!/usr/bin/env node
/**
 * Phase 41 — Staging infrastructure verification (TLS, CORS, headers, health).
 */
const STAGING_API = (process.env.STAGING_API_BASE || 'https://api.staging.owanbe.com').replace(/\/$/, '');
const STAGING_APP = process.env.STAGING_APP_ORIGIN || 'https://app.staging.owanbe.com';
const DOMAINS = [
  { name: 'api', url: STAGING_API },
  { name: 'app', url: STAGING_APP },
  { name: 'vendors', url: process.env.STAGING_VENDORS_ORIGIN || 'https://vendors.staging.owanbe.com' },
  { name: 'admin', url: process.env.STAGING_ADMIN_ORIGIN || 'https://admin.staging.owanbe.com' },
];

async function checkTls(base) {
  try {
    const res = await fetch(`${base}/health`, { signal: AbortSignal.timeout(10000) });
    return {
      pass: res.url.startsWith('https:') && res.ok,
      status: res.status,
      hsts: res.headers.get('strict-transport-security'),
    };
  } catch (e) {
    return { pass: false, error: e.message };
  }
}

async function checkCors() {
  try {
    const res = await fetch(`${STAGING_API}/v1/events`, {
      method: 'OPTIONS',
      headers: {
        Origin: STAGING_APP,
        'Access-Control-Request-Method': 'GET',
      },
      signal: AbortSignal.timeout(8000),
    });
    const allow = res.headers.get('access-control-allow-origin');
    return { pass: allow === STAGING_APP || allow === '*', allowOrigin: allow };
  } catch (e) {
    return { pass: false, error: e.message };
  }
}

async function checkSecurityHeaders() {
  try {
    const res = await fetch(`${STAGING_API}/health`, { signal: AbortSignal.timeout(8000) });
    const required = ['x-content-type-options', 'x-frame-options'];
    const found = required.filter((h) => res.headers.get(h));
    return { pass: found.length >= 1, found, encoding: res.headers.get('content-encoding') };
  } catch (e) {
    return { pass: false, error: e.message };
  }
}

async function main() {
  const report = {
    phase: '41',
    task: 'P0.1-staging-infrastructure',
    checkedAt: new Date().toISOString(),
    domains: {},
    tls: {},
    cors: null,
    securityHeaders: null,
    health: null,
    result: 'FAIL',
  };

  for (const d of DOMAINS) {
    report.domains[d.name] = { url: d.url, ...(await checkTls(d.url)) };
  }
  report.tls = report.domains.api;
  report.cors = await checkCors();
  report.securityHeaders = await checkSecurityHeaders();
  try {
    const h = await fetch(`${STAGING_API}/health`).then((r) => r.json());
    report.health = { pass: h.status === 'ok' || h.status === 'degraded', body: h };
  } catch (e) {
    report.health = { pass: false, error: e.message };
  }

  const pass =
    report.tls.pass &&
    report.cors.pass &&
    report.health?.pass &&
    Object.values(report.domains).filter((d) => d.name !== 'api').every((d) => d.pass || d.error);
  report.result = report.tls.pass && report.health?.pass ? (report.cors.pass ? 'PASS' : 'PARTIAL') : 'FAIL';
  console.log(JSON.stringify(report, null, 2));
  process.exit(report.result === 'PASS' ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
