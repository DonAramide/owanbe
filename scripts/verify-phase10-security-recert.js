#!/usr/bin/env node
/**
 * Phase 10 Sprint 10.5 — Security re-certification (delegates to Phase 8 gate + abuse test).
 */
const { spawnSync } = require('child_process');
const path = require('path');

const scripts = [
  'verify-phase8-identity-security.js',
  'verify-phase8-api-abuse.js',
];

function run(name) {
  const script = path.join(__dirname, name);
  const r = spawnSync('node', [script], { encoding: 'utf8', env: process.env });
  let json = {};
  try {
    json = JSON.parse(r.stdout.trim().split('\n').pop() || '{}');
  } catch {
    json = { raw: r.stdout?.slice(-500) };
  }
  return { name, exitCode: r.status, pass: r.status === 0, summary: json.result ?? json.gate ?? json };
}

async function main() {
  const results = scripts.map(run);
  const checks = {
    tenantIsolation: results[0].pass ? 'PASS' : 'FAIL',
    rbacAndJwt: results[0].pass ? 'PASS' : 'FAIL',
    rateLimiting: results[1].pass ? 'PASS' : 'FAIL',
    auditLogging: results[0].pass ? 'PASS' : 'FAIL',
    noRegressions: results.every((r) => r.pass) ? 'PASS' : 'FAIL',
  };
  const passed = Object.values(checks).filter((v) => v === 'PASS').length;
  const result = passed === 5 ? 'PASS' : 'FAIL';

  console.log(
    JSON.stringify(
      {
        sprint: '10.5',
        result,
        score: `${passed}/5`,
        checks,
        delegated: results,
      },
      null,
      2,
    ),
  );
  process.exit(result === 'PASS' ? 0 : 1);
}

main();
