#!/usr/bin/env node
/**
 * Phase 8 — Identity, Access & Security Hardening gate.
 * Requires: Postgres with migration 025, API on :8080, SUPABASE_JWT_SECRET aligned.
 */
const { Client } = require('../services/api/node_modules/pg');
const { signDevJwt, signInvalidJwt } = require('./lib/sign-dev-jwt');

const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const TENANT_A = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const TENANT_B = '99999999-9999-4999-8999-999999999999';
const ORGANIZER_ID = '22222222-2222-4222-8222-222222222222';
const ADMIN_ID = '77777777-7777-4777-8777-777777777777';
const SUPER_ADMIN_ID = '88888888-8888-4888-8888-888888888888';
const CLIENT_ONLY_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

const gate = {
  authentication: 'FAIL',
  authorization: 'FAIL',
  tenantIsolation: 'FAIL',
  securityMonitoring: 'FAIL',
  compliance: 'FAIL',
};

const evidence = {};

function bearer(userId, email, tenantId, roles, opts = {}) {
  return signDevJwt({ userId, email, tenantId, roles, ...opts });
}

async function api(method, path, { token, tenantId, body, headers = {} } = {}) {
  const h = { Accept: 'application/json', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (tenantId) h['X-Tenant-Id'] = tenantId;
  if (body) h['Content-Type'] = 'application/json';
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: h,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { ok: res.ok, status: res.status, json, text };
}

async function waitForApi(max = 30) {
  for (let i = 0; i < max; i++) {
    try {
      const r = await fetch(`${API_BASE.replace('/v1', '')}/health`);
      if (r.ok) return true;
    } catch {
      /* retry */
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  return false;
}

async function seedTenantB(pg) {
  await pg.query(
    `INSERT INTO tenants (id, slug, name) VALUES ($1, 'tenant-b-isolation', 'Tenant B Isolation')
     ON CONFLICT (slug) DO NOTHING`,
    [TENANT_B],
  );
  await pg.query(
    `INSERT INTO users (id, tenant_id, email, display_name, status)
     VALUES ($1, $2, 'client-b@owanbe.dev', 'Client B', 'active')
     ON CONFLICT DO NOTHING`,
    [CLIENT_ONLY_ID, TENANT_B],
  );
  await pg.query(
    `INSERT INTO user_roles (user_id, role_id)
     SELECT $1, r.id FROM roles r WHERE r.code = 'client'
     ON CONFLICT DO NOTHING`,
    [CLIENT_ONLY_ID],
  );
  await pg.query(
    `INSERT INTO compliance_retention_policies (tenant_id) VALUES ($1) ON CONFLICT DO NOTHING`,
    [TENANT_B],
  );
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();

  try {
    if (!(await waitForApi())) {
      throw new Error('API not reachable on /health');
    }

    await seedTenantB(pg);

    // ── Sprint 8.1 Authentication ──
    const noAuth = await api('GET', '/organizers/me/events', { tenantId: TENANT_A });
    const invalid = await api('GET', '/organizers/me/events', {
      token: signInvalidJwt(),
      tenantId: TENANT_A,
    });
    const expired = await api('GET', '/organizers/me/events', {
      token: bearer(ORGANIZER_ID, 'attendee@owanbe.dev', TENANT_A, ['organizer'], { expired: true }),
      tenantId: TENANT_A,
    });
    const validOrganizer = bearer(ORGANIZER_ID, 'attendee@owanbe.dev', TENANT_A, ['organizer']);
    const refreshOk = await api('GET', '/organizers/me/events', {
      token: validOrganizer,
      tenantId: TENANT_A,
    });
    evidence.authentication = {
      noAuthStatus: noAuth.status,
      invalidStatus: invalid.status,
      expiredStatus: expired.status,
      validStatus: refreshOk.status,
    };
    if (
      noAuth.status === 401 &&
      invalid.status === 401 &&
      expired.status === 401 &&
      refreshOk.ok
    ) {
      gate.authentication = 'PASS';
    }

    // ── Sprint 8.2 RBAC ──
    const clientToken = bearer(CLIENT_ONLY_ID, 'client-b@owanbe.dev', TENANT_B, ['client']);
    const deniedCreate = await api('POST', '/events', {
      token: clientToken,
      tenantId: TENANT_B,
      body: { title: 'Should Fail', slug: 'should-fail', startsAt: new Date().toISOString() },
    });
    const permMatrix = await pg.query(
      `SELECT r.code AS role, p.code AS permission
       FROM role_permissions rp
       INNER JOIN roles r ON r.id = rp.role_id
       INNER JOIN permissions p ON p.code = rp.permission_code
       ORDER BY r.code, p.code`,
    );
    const organizerPerms = await pg.query(
      `SELECT p.code FROM user_roles ur
       INNER JOIN roles r ON r.id = ur.role_id
       INNER JOIN role_permissions rp ON rp.role_id = r.id
       INNER JOIN permissions p ON p.code = rp.permission_code
       WHERE ur.user_id = $1`,
      [ORGANIZER_ID],
    );
    evidence.authorization = {
      clientCreateDenied: deniedCreate.status,
      permissionPairs: permMatrix.rows.length,
      organizerPermissions: organizerPerms.rows.map((r) => r.code),
    };
    if (deniedCreate.status === 403 && permMatrix.rows.length >= 10 && organizerPerms.rows.length >= 3) {
      gate.authorization = 'PASS';
    }

    // ── Sprint 8.3 Tenant isolation ──
    const crossTenant = await api('GET', '/events/evt_lagos_owanbe_2026/manage', {
      token: clientToken,
      tenantId: TENANT_B,
    });
    const ownTenant = await api('GET', '/events/evt_lagos_owanbe_2026', {
      tenantId: TENANT_A,
    });
    evidence.tenantIsolation = {
      crossTenantStatus: crossTenant.status,
      publicCatalogOk: ownTenant.ok,
      skipTenantEndpoints: ['GET /health', 'POST /webhooks/quaser', '/super-admin/*'],
    };
    if ((crossTenant.status === 403 || crossTenant.status === 404) && ownTenant.ok) {
      gate.tenantIsolation = 'PASS';
    }

    // ── Sprint 8.4 Security monitoring ──
    await pg.query(
      `INSERT INTO platform_security_events (tenant_id, event_type, severity, details)
       VALUES ($1, 'failed_login', 'warning', '{"gate":"phase8"}'::jsonb)`,
      [TENANT_A],
    );
    const superToken = bearer(SUPER_ADMIN_ID, 'superadmin@owanbe.dev', TENANT_A, ['super_admin']);
    const securityCenter = await api('GET', '/super-admin/security/center', { token: superToken });
    const summary = securityCenter.json?.summary ?? {};
    evidence.securityMonitoring = {
      securityCenterOk: securityCenter.ok,
      summaryKeys: Object.keys(summary),
      failedLogins: summary.failedLogins,
    };
    if (
      securityCenter.ok &&
      typeof summary.failedLogins === 'number' &&
      'rateLimitViolations' in summary &&
      'sessionAbuse' in summary
    ) {
      gate.securityMonitoring = 'PASS';
    }

    // ── Sprint 8.6 Compliance ──
    const adminToken = bearer(ADMIN_ID, 'admin@owanbe.dev', TENANT_A, ['admin_super']);
    const complianceExport = await api('GET', '/compliance/export', {
      token: adminToken,
      tenantId: TENANT_A,
    });
    const retention = await api('GET', '/compliance/retention', {
      token: adminToken,
      tenantId: TENANT_A,
    });
    evidence.compliance = {
      exportOk: complianceExport.ok,
      hasPiiClassification: Boolean(complianceExport.json?.piiClassification),
      retentionOk: retention.ok,
    };
    if (complianceExport.ok && retention.ok && complianceExport.json?.piiClassification) {
      gate.compliance = 'PASS';
    }

    const passed = Object.values(gate).filter((v) => v === 'PASS').length;
    const total = Object.keys(gate).length;
    const result = passed === total ? 'PASS' : 'FAIL';

    console.log(
      JSON.stringify(
        {
          phase: 8,
          baseline: 'v0.8.0-super-admin-complete',
          result,
          score: `${passed}/${total}`,
          gate,
          evidence,
        },
        null,
        2,
      ),
    );
    process.exit(result === 'PASS' ? 0 : 1);
  } finally {
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
