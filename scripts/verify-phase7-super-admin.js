#!/usr/bin/env node
/**
 * Phase 7 Super Admin Control Tower — verification gate (full sections 1–8).
 * Requires: Docker Postgres, migration 024, API on :8080 with ALLOW_DEV_SUPER_ADMIN_AUTH.
 */
const { Client } = require('../services/api/node_modules/pg');
const jwt = require('../services/api/node_modules/jsonwebtoken');

const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const SUPER_ADMIN_ID = process.env.SUPER_ADMIN_ID || '88888888-8888-4888-8888-888888888888';
const SUPER_ADMIN_EMAIL = process.env.SUPER_ADMIN_EMAIL || 'superadmin@owanbe.dev';
const JWT_SECRET = process.env.SUPABASE_JWT_SECRET || 'dev-jwt-secret-16chars';

const sections = {
  platformOverview: 'FAIL',
  tenantManagement: 'FAIL',
  platformFinance: 'FAIL',
  systemHealth: 'FAIL',
  featureFlags: 'FAIL',
  auditIntelligence: 'FAIL',
  platformAnalytics: 'FAIL',
  securityCenter: 'FAIL',
};

const evidence = {};

function signJwt() {
  return jwt.sign(
    {
      sub: SUPER_ADMIN_ID,
      email: SUPER_ADMIN_EMAIL,
      app_metadata: { tenant_id: TENANT_ID, roles: ['super_admin'] },
    },
    JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '1h' },
  );
}

async function api(method, path, body) {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${signJwt()}`,
      'X-Dev-User-Id': SUPER_ADMIN_ID,
      'X-Dev-User-Email': SUPER_ADMIN_EMAIL,
    },
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

async function waitForPg(maxAttempts = 30) {
  for (let i = 0; i < maxAttempts; i++) {
    const pg = new Client({ connectionString: DATABASE_URL });
    try {
      await pg.connect();
      await pg.query('SELECT 1');
      await pg.end();
      return true;
    } catch {
      try {
        await pg.end();
      } catch {
        /* ignore */
      }
      await new Promise((r) => setTimeout(r, 2000));
    }
  }
  return false;
}

async function flagFromDb(pg, tenantId, flagKey) {
  const r = await pg.query(
    `SELECT enabled FROM tenant_feature_flags WHERE tenant_id = $1 AND flag_key = $2`,
    [tenantId, flagKey],
  );
  return r.rows[0]?.enabled;
}

async function tenantStatusFromDb(pg, tenantId) {
  const r = await pg.query(`SELECT status FROM tenants WHERE id = $1`, [tenantId]);
  return r.rows[0]?.status;
}

async function main() {
  const pgReady = await waitForPg();
  if (!pgReady) {
    console.log(
      JSON.stringify(
        {
          overall: 'FAIL',
          error: 'Postgres not reachable. Start Docker: docker compose up -d postgres',
          sections,
        },
        null,
        2,
      ),
    );
    process.exit(1);
  }

  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();

  const role = await pg.query(
    `SELECT r.code FROM user_roles ur INNER JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = $1`,
    [SUPER_ADMIN_ID],
  );
  if (!role.rows.some((r) => r.code === 'super_admin')) {
    evidence.bootstrap = { error: 'super_admin role not seeded — run apply-phase7-migration.js' };
  }

  // ── SECTION 1: Platform Overview ──
  const overview = await api('GET', '/super-admin/platform/overview');
  evidence.section1 = overview.ok
    ? {
        totalEvents: overview.json.totalEvents,
        totalOrganizers: overview.json.totalOrganizers,
        totalVendors: overview.json.totalVendors,
        totalAttendees: overview.json.totalAttendees,
        platformRevenueMinor: overview.json.platformRevenueMinor,
        platformFeesMinor: overview.json.platformFeesMinor,
        platformHealth: overview.json.platformHealth,
      }
    : { status: overview.status, error: overview.json };
  sections.platformOverview =
    overview.ok &&
    overview.json.totalEvents !== undefined &&
    overview.json.platformRevenueMinor !== undefined
      ? 'PASS'
      : 'FAIL';

  // ── SECTION 2: Tenant Management ──
  const listBefore = await api('GET', '/super-admin/tenants');
  const slug = `phase7_gate_${Date.now()}`;
  const created = await api('POST', '/super-admin/tenants', { slug, name: `Gate Tenant ${slug}` });
  const gateTenantId = created.json?.id;

  let statusBefore = null;
  let statusAfterSuspend = null;
  let statusAfterReactivate = null;

  if (gateTenantId) {
    statusBefore = await tenantStatusFromDb(pg, gateTenantId);
    await api('POST', `/super-admin/tenants/${gateTenantId}/suspend`);
    statusAfterSuspend = await tenantStatusFromDb(pg, gateTenantId);
    await api('POST', `/super-admin/tenants/${gateTenantId}/reactivate`);
    statusAfterReactivate = await tenantStatusFromDb(pg, gateTenantId);
  }

  evidence.section2 = {
    listCount: listBefore.json.items?.length,
    tenant_id: gateTenantId,
    statusBefore,
    statusAfterSuspend,
    statusAfterReactivate,
    createStatus: created.status,
  };
  sections.tenantManagement =
    listBefore.ok &&
    created.ok &&
    statusBefore === 'active' &&
    statusAfterSuspend === 'suspended' &&
    statusAfterReactivate === 'active'
      ? 'PASS'
      : 'FAIL';

  // ── SECTION 3: Platform Finance ──
  const finance = await api('GET', '/super-admin/finance/platform');
  const s = finance.json?.summary ?? {};
  evidence.section3 = finance.ok
    ? {
        ticketRevenueMinor: s.ticketRevenueMinor,
        bookingRevenueMinor: s.bookingRevenueMinor,
        platformFeesMinor: s.platformFeesMinor,
        refundVolumeMinor: s.refundVolumeMinor,
        payoutVolumeMinor: s.payoutVolumeMinor,
        totalVolumeMinor: s.totalVolumeMinor,
      }
    : { status: finance.status, error: finance.json };
  sections.platformFinance =
    finance.ok &&
    s.ticketRevenueMinor !== undefined &&
    s.bookingRevenueMinor !== undefined &&
    s.platformFeesMinor !== undefined
      ? 'PASS'
      : 'FAIL';

  // ── SECTION 4: System Health ──
  const health = await api('GET', '/super-admin/system/health');
  const c = health.json?.components ?? {};
  evidence.section4 = health.ok
    ? {
        overall: health.json.overall,
        database: c.database,
        api: c.api,
        queue: c.queue,
        webhooks: c.webhooks,
        reconciliation: c.reconciliation,
        checkedAt: health.json.checkedAt,
      }
    : { status: health.status, error: health.json };
  sections.systemHealth =
    health.ok &&
    c.database === 'operational' &&
    c.api === 'operational' &&
    c.queue !== undefined &&
    c.webhooks !== undefined
      ? 'PASS'
      : 'FAIL';

  // ── SECTION 5: Feature Flags ──
  const flagsBefore = await api('GET', `/super-admin/feature-flags/${TENANT_ID}`);
  const ticketBefore = await flagFromDb(pg, TENANT_ID, 'ticket_commerce');
  const liveBefore = await flagFromDb(pg, TENANT_ID, 'live_operations');

  await api('POST', `/super-admin/feature-flags/${TENANT_ID}`, {
    flagKey: 'ticket_commerce',
    enabled: !ticketBefore,
  });
  const ticketAfterToggle = await flagFromDb(pg, TENANT_ID, 'ticket_commerce');

  await api('POST', `/super-admin/feature-flags/${TENANT_ID}`, {
    flagKey: 'live_operations',
    enabled: !liveBefore,
  });
  const liveAfterToggle = await flagFromDb(pg, TENANT_ID, 'live_operations');

  // Restore original values
  await api('POST', `/super-admin/feature-flags/${TENANT_ID}`, {
    flagKey: 'ticket_commerce',
    enabled: ticketBefore ?? true,
  });
  await api('POST', `/super-admin/feature-flags/${TENANT_ID}`, {
    flagKey: 'live_operations',
    enabled: liveBefore ?? true,
  });

  evidence.section5 = {
    ticket_commerce: { before: ticketBefore, afterToggle: ticketAfterToggle },
    live_operations: { before: liveBefore, afterToggle: liveAfterToggle },
    apiFlags: flagsBefore.json?.flags?.map((f) => ({ key: f.key, enabled: f.enabled })),
  };
  sections.featureFlags =
    flagsBefore.ok &&
    ticketAfterToggle === !ticketBefore &&
    liveAfterToggle === !liveBefore
      ? 'PASS'
      : 'FAIL';

  // ── SECTION 6: Audit Intelligence (generate actions first) ──
  if (gateTenantId) {
    await api('POST', `/super-admin/tenants/${gateTenantId}/suspend`);
    await api('POST', `/super-admin/tenants/${gateTenantId}/reactivate`);
  }
  await api('POST', `/super-admin/feature-flags/${TENANT_ID}`, {
    flagKey: 'ticket_commerce',
    enabled: true,
  });

  const audit = await api('GET', '/super-admin/audit/timeline?limit=30');
  const actions = (audit.json.items ?? []).map((i) => i.action);
  const hasTenantAction = actions.some((a) => a.includes('tenant'));
  const hasFlagAction = actions.some((a) => a.includes('feature_flag'));
  evidence.section6 = {
    count: audit.json.items?.length,
    sampleActions: actions.slice(0, 10),
    hasTenantAction,
    hasFlagAction,
    recent: audit.json.items?.slice(0, 5),
  };
  sections.auditIntelligence =
    audit.ok && audit.json.items?.length > 0 && (hasTenantAction || hasFlagAction)
      ? 'PASS'
      : 'FAIL';

  // ── SECTION 7: Platform Analytics ──
  const ranges = ['7d', '30d', '90d', '365d'];
  const analyticsResults = {};
  let analyticsOk = true;
  for (const range of ranges) {
    const r = await api('GET', `/super-admin/analytics/platform?range=${range}`);
    analyticsResults[range] = r.ok
      ? {
          revenueGrowth: r.json.revenueGrowth,
          eventGrowth: r.json.eventGrowth,
          vendorGrowth: r.json.vendorGrowth,
          attendeeGrowth: r.json.attendeeGrowth,
        }
      : { status: r.status, error: r.json };
    if (!r.ok) analyticsOk = false;
  }
  evidence.section7 = analyticsResults;
  sections.platformAnalytics = analyticsOk ? 'PASS' : 'FAIL';

  // ── SECTION 8: Security Center ──
  const security = await api('GET', '/super-admin/security/center');
  evidence.section8 = security.ok
    ? {
        failedLogins: security.json.summary?.failedLogins,
        permissionEscalations: security.json.summary?.permissionEscalations,
        suspiciousActivity: security.json.summary?.suspiciousActivity,
        financeExceptions: security.json.summary?.financeExceptions,
        eventCount: security.json.events?.length,
        sampleEvent: security.json.events?.[0],
      }
    : { status: security.status, error: security.json };
  sections.securityCenter =
    security.ok &&
    security.json.summary !== undefined &&
    Array.isArray(security.json.events)
      ? 'PASS'
      : 'FAIL';

  await pg.end();

  const allPass = Object.values(sections).every((v) => v === 'PASS');
  const result = {
    overall: allPass ? 'PASS' : 'FAIL',
    sections,
    evidence,
    summary: `${Object.values(sections).filter((v) => v === 'PASS').length}/8 sections passed`,
  };

  console.log(JSON.stringify(result, null, 2));
  process.exit(allPass ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
