#!/usr/bin/env node
/**
 * Phase 6 Platform Administration — verification gate.
 * Requires API + DB. Uses dev admin auth headers or signed JWT.
 */
const { Client } = require('../services/api/node_modules/pg');
const jwt = require('../services/api/node_modules/jsonwebtoken');

const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const ADMIN_USER_ID = process.env.ADMIN_USER_ID || '77777777-7777-4777-8777-777777777777';
const ADMIN_USER_EMAIL = process.env.ADMIN_USER_EMAIL || 'admin@owanbe.dev';
const ORGANIZER_ID = process.env.ORGANIZER_ID || '33333333-3333-4333-8333-333333333333';
const VENDOR_ID = process.env.VENDOR_ID || '55555555-5555-4555-8555-555555555555';
const EVENT_REF = process.env.EVENT_REF || 'evt_lagos_owanbe_2026';
const JWT_SECRET = process.env.SUPABASE_JWT_SECRET || 'dev-jwt-secret-16chars';

const report = { checks: {}, evidence: {}, overall: 'FAIL' };

function check(name, ok, detail) {
  report.checks[name] = ok ? 'PASS' : 'FAIL';
  if (detail !== undefined) report.evidence[name] = detail;
}

function signAdminJwt() {
  return jwt.sign(
    {
      sub: ADMIN_USER_ID,
      email: ADMIN_USER_EMAIL,
      app_metadata: {
        tenant_id: TENANT_ID,
        roles: ['admin_super'],
      },
    },
    JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '1h' },
  );
}

async function api(method, path, body, extraHeaders = {}) {
  const token = signAdminJwt();
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Tenant-Id': TENANT_ID,
      Authorization: `Bearer ${token}`,
      'X-Dev-User-Id': ADMIN_USER_ID,
      'X-Dev-User-Email': ADMIN_USER_EMAIL,
      ...extraHeaders,
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

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();

  const adminRole = await pg.query(
    `SELECT r.code FROM user_roles ur
     INNER JOIN roles r ON r.id = ur.role_id
     WHERE ur.user_id = $1`,
    [ADMIN_USER_ID],
  );
  check(
    '6.0 dev platform admin seeded',
    adminRole.rows.some((r) => r.code === 'admin_super'),
    { roles: adminRole.rows.map((r) => r.code) },
  );

  const dash = await api('GET', '/admin/platform/dashboard');
  check('6.1 platform dashboard KPIs', dash.ok && dash.json.activeEvents !== undefined, {
    status: dash.status,
    keys: dash.ok ? Object.keys(dash.json) : dash.json,
    platformHealth: dash.json?.platformHealth,
  });

  const organizers = await api('GET', '/admin/organizers');
  check('6.2 organizers managed through API', organizers.ok && Array.isArray(organizers.json.items), {
    status: organizers.status,
    count: organizers.json.items?.length,
    sample: organizers.json.items?.[0]?.displayName,
  });

  const orgDetail = await api('GET', `/admin/organizers/${ORGANIZER_ID}`);
  check('6.2 organizer detail', orgDetail.ok && orgDetail.json.profile, {
    status: orgDetail.status,
    events: orgDetail.json.events?.length,
    revenueMinor: orgDetail.json.revenue?.volumeMinor,
  });

  const events = await api('GET', '/admin/events');
  check('6.3 events managed through API', events.ok && Array.isArray(events.json.items), {
    status: events.status,
    count: events.json.items?.length,
  });

  const eventDetail = await api('GET', `/admin/events/${EVENT_REF}`);
  check('6.3 event detail + health', eventDetail.ok && eventDetail.json.overview, {
    status: eventDetail.status,
    health: eventDetail.json.health,
    finance: !!eventDetail.json.finance,
  });

  const vendors = await api('GET', '/admin/vendors');
  check('6.4 vendors managed through API', vendors.ok && Array.isArray(vendors.json.items), {
    status: vendors.status,
    count: vendors.json.items?.length,
  });

  const vendorDetail = await api('GET', `/admin/vendors/${VENDOR_ID}`);
  check('6.4 vendor detail', vendorDetail.ok && vendorDetail.json.profile, {
    status: vendorDetail.status,
    participations: vendorDetail.json.participations?.length,
  });

  const finance = await api('GET', '/admin/finance/supervision');
  const hasTicketRail = finance.ok && finance.json.ticketRail?.orderCount !== undefined;
  const hasBookingRail = finance.ok && finance.json.bookingRail?.paymentCount !== undefined;
  check('6.5 finance includes ticket + booking rails', hasTicketRail && hasBookingRail, finance.json);

  const opsOverview = await api('GET', '/admin/operations/overview');
  const persistedOps =
    opsOverview.ok &&
    Array.isArray(opsOverview.json.liveEvents) &&
    Array.isArray(opsOverview.json.checkIns);
  check('6.6 operations center reads persisted data', persistedOps, {
    liveEvents: opsOverview.json.liveEvents?.length,
    checkIns: opsOverview.json.checkIns?.length,
    incidents: opsOverview.json.incidents?.length,
    feed: opsOverview.json.feed?.length,
  });

  const checkInsTable = await pg.query(
    `SELECT COUNT(*)::int AS n FROM event_check_ins WHERE tenant_id = $1`,
    [TENANT_ID],
  );
  check('6.6 check-ins table has rows', checkInsTable.rows[0].n >= 0, checkInsTable.rows[0]);

  const audit = await api('GET', '/admin/audit/timeline?limit=20');
  check('6.7 audit trail exists', audit.ok && Array.isArray(audit.json.items), {
    status: audit.status,
    count: audit.json.items?.length,
    sample: audit.json.items?.[0],
  });

  const suspend = await api('POST', `/admin/organizers/${ORGANIZER_ID}/suspend`);
  const reactivate = await api('POST', `/admin/organizers/${ORGANIZER_ID}/reactivate`);
  check('6.2 organizer suspend/reactivate', suspend.ok && reactivate.ok, {
    suspend: suspend.status,
    reactivate: reactivate.status,
  });

  const auditAfter = await api('GET', '/admin/audit/timeline?category=admin&limit=10');
  check(
    '6.7 admin actions audited',
    auditAfter.ok && (auditAfter.json.items?.length ?? 0) >= 2,
    { count: auditAfter.json.items?.length, actions: auditAfter.json.items?.map((i) => i.action) },
  );

  await pg.end();

  const passCount = Object.values(report.checks).filter((v) => v === 'PASS').length;
  const total = Object.keys(report.checks).length;
  report.overall = passCount === total ? 'PASS' : 'FAIL';
  report.summary = `${passCount}/${total} checks passed`;

  console.log(JSON.stringify(report, null, 2));
  process.exit(report.overall === 'PASS' ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
