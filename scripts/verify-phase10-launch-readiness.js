#!/usr/bin/env node
/**
 * Phase 10 — Launch Readiness gate (orchestrates sprints 10.1–10.6).
 */
const { spawnSync } = require('child_process');
const path = require('path');

const SPRINTS = [
  { key: 'observability', script: 'verify-phase10-observability.js', label: 'Observability' },
  { key: 'goLiveChecklist', script: 'verify-phase10-go-live-checklist.js', label: 'Go-Live Checklist' },
  { key: 'disasterRecovery', script: 'verify-phase10-disaster-recovery.js', label: 'Disaster Recovery' },
  { key: 'loadTesting', script: 'verify-phase10-load-testing.js', label: 'Load Testing' },
  { key: 'e2eCertification', script: 'verify-phase10-e2e-certification.js', label: 'E2E Certification' },
  { key: 'securityRecertification', script: 'verify-phase10-security-recert.js', label: 'Security Recertification' },
];

function runSprint(script) {
  const timeoutMs = script.includes('load-testing') ? 900_000 : 600_000;
  const r = spawnSync('node', [path.join(__dirname, script)], {
    encoding: 'utf8',
    env: {
      ...process.env,
      PHASE10_LOAD_COOLDOWN_MS: process.env.PHASE10_LOAD_COOLDOWN_MS || '5000',
      PHASE10_REQUEST_GAP_MS: process.env.PHASE10_REQUEST_GAP_MS || '2100',
    },
    timeout: timeoutMs,
  });
  let json = {};
  try {
    const lines = (r.stdout || '').trim().split('\n');
    for (let i = lines.length - 1; i >= 0; i--) {
      if (lines[i].startsWith('{')) {
        json = JSON.parse(lines.slice(i).join('\n'));
        break;
      }
    }
  } catch {
    json = { parseError: true, tail: r.stdout?.slice(-400) };
  }
  return {
    exitCode: r.status,
    pass: r.status === 0 || json.result === 'PASS',
    result: json.result ?? (r.status === 0 ? 'PASS' : 'FAIL'),
    detail: json,
    stderr: r.stderr?.slice(-300),
  };
}

async function main() {
  const gate = {};
  const evidence = {};

  for (const sprint of SPRINTS) {
    const out = runSprint(sprint.script);
    gate[sprint.key] = out.pass ? 'PASS' : 'FAIL';
    evidence[sprint.key] = out.detail;
    if (out.stderr) evidence[`${sprint.key}_stderr`] = out.stderr;
  }

  const passed = Object.values(gate).filter((v) => v === 'PASS').length;
  const result = passed === 6 ? 'PASS' : 'FAIL';

  console.log(
    JSON.stringify(
      {
        phase: 10,
        baseline: 'v0.9.0-security-pass + Phase 9 Production Integrations',
        targetRelease: result === 'PASS' ? 'v1.0.0-production-ready' : null,
        result,
        score: `${passed}/6`,
        gate,
        evidence,
      },
      null,
      2,
    ),
  );
  process.exit(result === 'PASS' ? 0 : 1);
}

main();
