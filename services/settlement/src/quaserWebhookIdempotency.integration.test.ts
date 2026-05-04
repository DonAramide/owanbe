import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PostgreSqlContainer } from '@testcontainers/postgresql';
import pg from 'pg';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';

import { applyQuaserPaymentCapture, logSettlement } from './applyQuaserCapture.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..', '..');

async function applySql(client: pg.PoolClient, relativePath: string): Promise<void> {
  const sql = readFileSync(join(repoRoot, relativePath), 'utf8');
  await client.query(sql);
}

describe('Quaser webhook settlement idempotency', () => {
  let container: PostgreSqlContainer;
  let pool: pg.Pool;

  beforeAll(async () => {
    container = await new PostgreSqlContainer('postgres:16-alpine').start();
    pool = new pg.Pool({ connectionString: container.getConnectionUri() });
    const client = await pool.connect();
    try {
      await applySql(client, 'infra/db/owanbe_core.sql');
      await applySql(client, 'infra/db/005_payment_settlement_idempotent.sql');
      await seedMinimalTenant(client);
    } finally {
      client.release();
    }
  }, 120_000);

  afterAll(async () => {
    await pool?.end();
    await container?.stop();
  });

  it('same webhook twice: first applies, second skips; single ledger txn', async () => {
    const client = await pool.connect();
    try {
      const ids = await seedPaymentScenario(client);
      const params = {
        paymentId: ids.paymentId,
        tenantId: ids.tenantId,
        provider: 'paystack' as const,
        routerEventId: 'evt_quaser_duplicate_test_001',
        eventType: 'payment.captured',
        payload: { reference: 'OWB-test' },
        pspClearingAccountId: ids.psp,
        escrowAccountId: ids.escrow,
        platformFeesAccountId: ids.fees,
        grossMinor: 100_000,
        feeMinor: 5_000,
      };

      await client.query('BEGIN');
      const first = await applyQuaserPaymentCapture(client, params);
      await client.query('COMMIT');
      expect(first).toMatchObject({ skipped: false, reason: 'applied', payment_id: ids.paymentId });
      expect(first).toHaveProperty('ledger_transaction_id');
      logSettlement(first, ids.paymentId);

      await client.query('BEGIN');
      const second = await applyQuaserPaymentCapture(client, params);
      await client.query('COMMIT');
      expect(second).toEqual({ skipped: true, reason: 'already_succeeded' });
      logSettlement(second, ids.paymentId);

      const { rows: payRows } = await client.query(
        `SELECT status, amount_captured_minor FROM payments WHERE id = $1`,
        [ids.paymentId]
      );
      expect(payRows[0].status).toBe('captured');
      expect(String(payRows[0].amount_captured_minor)).toBe('100000');

      const { rows: evRows } = await client.query(
        `SELECT COUNT(*)::int AS c FROM payment_events WHERE payment_id = $1`,
        [ids.paymentId]
      );
      expect(evRows[0].c).toBe(1);

      const { rows: ltRows } = await client.query(
        `SELECT COUNT(*)::int AS c FROM ledger_transactions WHERE payment_id = $1`,
        [ids.paymentId]
      );
      expect(ltRows[0].c).toBe(1);

      const { rows: llRows } = await client.query(
        `SELECT COUNT(*)::int AS c FROM ledger_lines ll
         JOIN ledger_transactions lt ON lt.id = ll.transaction_id
         WHERE lt.payment_id = $1`,
        [ids.paymentId]
      );
      expect(llRows[0].c).toBe(4);
    } finally {
      client.release();
    }
  });
});

async function seedMinimalTenant(client: pg.PoolClient): Promise<void> {
  await client.query(`
    INSERT INTO tenants (id, slug, name) VALUES
      ('11111111-1111-1111-1111-111111111111', 'default', 'Default Tenant')
    ON CONFLICT (id) DO NOTHING;
  `);
}

async function seedPaymentScenario(client: pg.PoolClient): Promise<{
  tenantId: string;
  paymentId: string;
  psp: string;
  escrow: string;
  fees: string;
}> {
  const tenantId = '11111111-1111-1111-1111-111111111111';
  const userId = '22222222-2222-2222-2222-222222222222';
  const vendorId = '33333333-3333-3333-3333-333333333333';
  const packageId = '44444444-4444-4444-4444-444444444444';
  const bookingId = '55555555-5555-5555-5555-555555555555';
  const paymentId = '66666666-6666-6666-6666-666666666666';

  await client.query(
    `
    INSERT INTO users (id, tenant_id, email, display_name, status)
    VALUES ($1, $2, 'u@test.local', 'Test User', 'active');
  `,
    [userId, tenantId]
  );

  await client.query(
    `INSERT INTO user_roles (user_id, role_id) VALUES ($1, (SELECT id FROM roles WHERE code = 'client' LIMIT 1))`,
    [userId]
  );

  await client.query(
    `
    INSERT INTO vendors (id, tenant_id, owner_user_id, business_name, slug, status, country_code, city)
    VALUES ($1, $2, $3, 'Test Vendor', 'test-vendor', 'active', 'NG', 'Lagos');
  `,
    [vendorId, tenantId, userId]
  );

  await client.query(
    `
    INSERT INTO vendor_packages (id, tenant_id, vendor_id, code, name, billing_unit, currency, unit_amount_minor)
    VALUES ($1, $2, $3, 'std', 'Standard', 'fixed', 'NGN', 100000);
  `,
    [packageId, tenantId, vendorId]
  );

  await client.query(
    `
    INSERT INTO bookings (
      id, tenant_id, client_user_id, vendor_id, package_id, status, currency, guest_count,
      event_starts_at, pricing_snapshot, subtotal_minor, platform_fee_minor, total_minor, version
    ) VALUES (
      $1, $2, $3, $4, $5, 'pending_payment', 'NGN', 10, now(),
      '{}', 100000, 5000, 100000, 1
    );
  `,
    [bookingId, tenantId, userId, vendorId, packageId]
  );

  await client.query(
    `
    INSERT INTO payments (id, tenant_id, booking_id, provider, status, currency, amount_captured_minor, amount_refunded_minor)
    VALUES ($1, $2, $3, 'paystack', 'authorized', 'NGN', 0, 0);
  `,
    [paymentId, tenantId, bookingId]
  );

  const psp = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const escrow = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  const fees = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

  await client.query(
    `
    INSERT INTO ledger_accounts (id, tenant_id, kind, currency, code)
    VALUES
      ($1, $2, 'external_psp', 'NGN', 'PSP_CLEARING_TEST'),
      ($3, $2, 'escrow', 'NGN', 'ESCROW_POOL_TEST'),
      ($4, $2, 'platform_fees', 'NGN', 'PLATFORM_FEES_TEST')
    ON CONFLICT (tenant_id, currency, code) DO NOTHING;
  `,
    [psp, tenantId, escrow, fees]
  );

  return { tenantId, paymentId, psp, escrow, fees };
}
