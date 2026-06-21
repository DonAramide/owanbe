#!/usr/bin/env node
/**
 * Phase 8 Sprint 8.5 — API abuse smoke tests (rate limit + auth rejection).
 */
const { signDevJwt } = require('./lib/sign-dev-jwt');

const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';

async function hit(path, token) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: {
      Accept: 'application/json',
      Authorization: token ? `Bearer ${token}` : undefined,
      'X-Tenant-Id': TENANT_ID,
    },
  });
  return res.status;
}

async function main() {
  const invalidStatuses = [];
  for (let i = 0; i < 5; i++) {
    invalidStatuses.push(await hit('/organizers/me/events', 'not-a-jwt'));
  }
  const all401 = invalidStatuses.every((s) => s === 401);

  const token = signDevJwt({
    userId: '22222222-2222-4222-8222-222222222222',
    email: 'attendee@owanbe.dev',
    tenantId: TENANT_ID,
    roles: ['organizer'],
  });
  const burst = [];
  for (let i = 0; i < 250; i++) {
    burst.push(hit('/events', token));
  }
  const burstStatuses = await Promise.all(burst);
  const throttled = burstStatuses.some((s) => s === 429);

  const result = all401 ? 'PASS' : 'FAIL';
  console.log(
    JSON.stringify(
      {
        sprint: '8.5',
        authRejection: all401 ? 'PASS' : 'FAIL',
        rateLimitObserved: throttled,
        invalidStatuses: [...new Set(invalidStatuses)],
        burst429Count: burstStatuses.filter((s) => s === 429).length,
        result,
      },
      null,
      2,
    ),
  );
  process.exit(result === 'PASS' ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
