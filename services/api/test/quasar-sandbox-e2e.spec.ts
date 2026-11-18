import { createHash, createHmac } from 'crypto';
import { createServer, type Server } from 'http';
import type { AddressInfo } from 'net';
import { QuasarSecretsCrypto } from '../src/modules/quasar/quasar-secrets.crypto';
import { QuasarHttpClient, QuasarHttpError } from '../src/modules/quasar/quasar-client.service';
import { buildAuditDetail } from '../src/modules/quasar/quasar-audit.service';
import { verifyQuaserWebhookSignature } from '../src/modules/payments/quaser-signature.util';
import {
  payoutStateFromConfirmedQuasarStatus,
  payoutStateFromCreateResponse,
  ticketStateAfterFunding,
  type PayoutReadState,
  type TicketReadState,
} from '../src/modules/quasar/quasar-state';
import { minorUnitsFromQuasarAmount } from '../src/modules/quasar/quasar.policy';

const ORGANIZER_ID = '11111111-1111-4111-8111-111111111111';
const PAYER_ID = '22222222-2222-4222-8222-222222222222';
const QUASAR_TENANT_ID = '33333333-3333-4333-8333-333333333333';
const TICKET_PAYMENT_ID = '44444444-4444-4444-8444-444444444444';
const PAYOUT_ID = '55555555-5555-4555-8555-555555555555';
const EXPECTED_MINOR = '5000000';
const SIGNING_SECRET = 'sandbox-signing-secret';
const TENANT_KEY = 'sk_test_sandboxkey';

interface SandboxState {
  paths: string[];
  environments: string[];
  walletOwnerId: string | null;
  schoolId: string | null;
  metadataTenantId: string | null;
  transferCount: number;
  transferStatus: string;
  funded: boolean;
  insufficient: boolean;
  failNext: number;
  holdMs: number;
}

function startSandbox(): Promise<{ baseUrl: string; state: SandboxState; close: () => Promise<void> }> {
  const state: SandboxState = {
    paths: [],
    environments: [],
    walletOwnerId: null,
    schoolId: null,
    metadataTenantId: null,
    transferCount: 0,
    transferStatus: 'AWAITING_APPROVAL',
    funded: false,
    insufficient: false,
    failNext: 0,
    holdMs: 0,
  };
  const idempotency = new Map<string, unknown>();
  let closed = false;
  const server: Server = createServer(async (req, res) => {
    try {
    req.on('error', () => undefined);
    const path = (req.url ?? '').split('?')[0] ?? '';
    state.paths.push(path);
    if (path.includes('admin/auth/login')) {
      res.writeHead(500);
      res.end('admin login must not be called');
      return;
    }
    if (state.holdMs > 0) await new Promise((resolve) => setTimeout(resolve, state.holdMs));
    if (state.failNext > 0) {
      state.failNext -= 1;
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ responseCode: '99', message: 'unavailable' }));
      return;
    }
    const chunks: Buffer[] = [];
    for await (const chunk of req) chunks.push(chunk as Buffer);
    const body = chunks.length ? (JSON.parse(Buffer.concat(chunks).toString('utf8')) as Record<string, unknown>) : {};
    if (typeof body.environment === 'string') state.environments.push(body.environment);
    const auth = req.headers.authorization ?? '';
    if (auth.startsWith('Bearer sk_live_')) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ responseCode: '01', message: 'live keys are disabled' }));
      return;
    }
    const json = (status: number, payload: unknown) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(payload));
    };
    if (req.method === 'POST' && path.endsWith('/integration/platform/tenants')) {
      json(201, { responseCode: '00', data: { data: { id: QUASAR_TENANT_ID, slug: body.slug, code: 'OWA001', vertical: 'owanbe' } } });
      return;
    }
    if (req.method === 'POST' && path.endsWith('/api-keys')) {
      json(201, { responseCode: '00', data: { secretKey: TENANT_KEY } });
      return;
    }
    if (req.method === 'POST' && path.endsWith('/webhooks/endpoints')) {
      json(201, { responseCode: '00', data: { signingSecret: SIGNING_SECRET } });
      return;
    }
    if (req.method === 'POST' && path.includes('/virtual-account')) {
      state.walletOwnerId = String(body.merchantWalletOwnerId ?? '');
      const metadata = (body.metadata ?? {}) as Record<string, unknown>;
      json(201, {
        responseCode: '00',
        data: { account_number: '0123456789', bankName: 'Sandbox Bank', reference: 'va_1' },
      });
      void metadata;
      return;
    }
    if (req.method === 'GET' && path.endsWith('/payments')) {
      json(200, {
        responseCode: '00',
        data: {
          items: state.funded
            ? [{ status: 'SUCCESS', amount: '50000.00', metadata: { ticketPaymentId: TICKET_PAYMENT_ID } }]
            : [],
        },
      });
      return;
    }
    if (req.method === 'POST' && path.endsWith('/transfers')) {
      const key = String(req.headers['idempotency-key'] ?? '');
      if (idempotency.has(key)) {
        json(201, { responseCode: '00', data: idempotency.get(key) });
        return;
      }
      if (state.insufficient) {
        json(400, { responseCode: '40', message: 'insufficient balance' });
        return;
      }
      const metadata = (body.metadata ?? {}) as Record<string, unknown>;
      state.schoolId = String(metadata.schoolId ?? '');
      state.metadataTenantId = String(metadata.tenantId ?? '');
      state.transferCount += 1;
      const payload = { reference: body.reference, status: 'AWAITING_APPROVAL', amount: body.amount };
      idempotency.set(key, payload);
      json(201, { responseCode: '00', data: payload });
      return;
    }
    if (req.method === 'GET' && path.includes('/transfers/')) {
      const reference = decodeURIComponent(path.split('/').pop() ?? '');
      json(200, { responseCode: '00', data: { reference, status: state.transferStatus } });
      return;
    }
    json(404, { responseCode: '44', message: 'not found' });
    } catch {
      if (!res.headersSent) res.writeHead(499);
      res.end();
    }
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const address = server.address() as AddressInfo;
      resolve({
        baseUrl: `http://127.0.0.1:${address.port}/api/v1`,
        state,
        close: () =>
          new Promise((done) => {
            if (closed) {
              done();
              return;
            }
            closed = true;
            server.close(() => done());
          }),
      });
    });
  });
}

function clientFor(baseUrl: string, timeoutMs = 20_000) {
  const client = new QuasarHttpClient({
    baseUrl: () => baseUrl,
    clientId: () => 'OWANBE',
    clientSecret: () => 'qpc_test_secret',
    keyEnvironment: () => 'test',
    timeoutMs: () => timeoutMs,
  });
  client.sleep = async () => undefined;
  return client;
}

function sign(body: string) {
  return createHmac('sha256', SIGNING_SECRET).update(body).digest('hex');
}

describe('Quasar sandbox end to end', () => {
  let sandbox: Awaited<ReturnType<typeof startSandbox>>;

  beforeAll(async () => {
    sandbox = await startSandbox();
  });

  afterAll(async () => {
    await sandbox.close();
  });

  it('proves organizer tenant, funded ticket, and payout only after confirmed SUCCESS', async () => {
    const client = clientFor(sandbox.baseUrl);
    const crypto = new QuasarSecretsCrypto({ get: () => 'sandbox-encryption-key-at-least-32-chars' } as never);
    const seen = new Set<string>();
    const audits: unknown[] = [];
    let ticket: TicketReadState = 'initiated';
    let payout: PayoutReadState = 'pending';

    const tenant = await client.createTenant({
      name: 'Ada Events',
      slug: 'owanbe-organizer-ada',
      idempotencyKey: `owanbe-tenant-organizer-${ORGANIZER_ID}`,
    });
    expect(tenant.id).toBe(QUASAR_TENANT_ID);
    expect(tenant.vertical).toBe('owanbe');

    const key = await client.createTenantApiKey({
      quasarTenantId: QUASAR_TENANT_ID,
      name: 'Owanbe — Ada Events',
      idempotencyKey: `owanbe-key-${QUASAR_TENANT_ID}-test`,
    });
    const secretKey = String(key.data.secretKey);
    expect(secretKey.startsWith('sk_test_')).toBe(true);
    expect(sandbox.state.environments).toEqual(['test']);
    const ciphertext = crypto.encrypt(secretKey);
    expect(ciphertext).not.toContain('sk_test_');
    expect(crypto.decrypt(ciphertext)).toBe(secretKey);

    const webhook = await client.registerWebhook({
      apiKey: secretKey,
      url: 'http://127.0.0.1/webhooks/quasar/' + QUASAR_TENANT_ID,
      idempotencyKey: `owanbe-webhook-${QUASAR_TENANT_ID}`,
    });
    expect(webhook.signingSecret).toBe(SIGNING_SECRET);

    const account = await client.createVirtualAccount({
      apiKey: secretKey,
      payerId: PAYER_ID,
      idempotencyKey: `owanbe-va-${PAYER_ID}-NGN`,
      body: {
        currency: 'NGN',
        email: 'ada@example.com',
        firstName: 'Ada',
        lastName: 'Attendee',
        phone: '+2348012345678',
        merchantWalletOwnerId: ORGANIZER_ID,
        metadata: {
          eventId: 'evt_1',
          ticketPaymentId: TICKET_PAYMENT_ID,
          payerId: PAYER_ID,
          expectedTotalMinor: EXPECTED_MINOR,
        },
      },
    });
    expect(account.account_number).toBe('0123456789');
    expect(sandbox.state.walletOwnerId).toBe(ORGANIZER_ID);
    ticket = 'awaiting_transfer';
    expect(ticket).not.toBe('paid');

    const deliver = (event: string, data: Record<string, unknown>, signature?: string) => {
      const raw = JSON.stringify({ event, data, timestamp: '2026-10-07T00:00:00Z' });
      const header = signature ?? sign(raw);
      if (!verifyQuaserWebhookSignature(SIGNING_SECRET, Buffer.from(raw), header)) {
        audits.push(buildAuditDetail({ action: 'webhook.rejected', outcome: 'invalid_signature' }));
        throw new Error('invalid signature');
      }
      const eventKey = createHash('sha256').update(raw).digest('hex');
      if (seen.has(eventKey)) {
        audits.push(buildAuditDetail({ action: 'webhook.duplicate', outcome: 'ignored' }));
        return { duplicate: true };
      }
      seen.add(eventKey);
      audits.push(buildAuditDetail({ event, data }));
      if (event === 'virtual_account.funded') {
        const funded = minorUnitsFromQuasarAmount(data);
        ticket = ticketStateAfterFunding(funded === EXPECTED_MINOR);
      }
      if (event === 'transfer.success') payout = payoutStateFromConfirmedQuasarStatus('SUCCESS');
      if (event === 'transfer.failed') {
        payout = payoutStateFromConfirmedQuasarStatus(String(data.status ?? 'FAILED'));
      }
      return { duplicate: false };
    };

    deliver('virtual_account.funded', { amount: '50000.00', metadata: { ticketPaymentId: TICKET_PAYMENT_ID, payerId: PAYER_ID } });
    expect(ticket).toBe('paid');
    expect(deliver('virtual_account.funded', { amount: '50000.00', metadata: { ticketPaymentId: TICKET_PAYMENT_ID, payerId: PAYER_ID } }).duplicate).toBe(true);
    expect(seen.size).toBe(1);

    expect(() => deliver('virtual_account.funded', { amount: '1.00' }, 'deadbeef')).toThrow(/invalid signature/);
    expect(ticket).toBe('paid');

    const reference = `owanbe_payout_${PAYOUT_ID}`;
    const created = await client.createTransfer({
      apiKey: secretKey,
      idempotencyKey: reference,
      body: {
        amount: '50000.00',
        currency: 'NGN',
        reference,
        destination: { account_number: '0123456789', bank_code: '058', account_name: 'Ada Events' },
        metadata: { tenantId: QUASAR_TENANT_ID, schoolId: ORGANIZER_ID },
      },
    });
    expect(created.status).toBe('AWAITING_APPROVAL');
    payout = payoutStateFromCreateResponse(String(created.status));
    expect(payout).toBe('awaiting_approval');
    expect(payout).not.toBe('paid');
    expect(sandbox.state.schoolId).toBe(ORGANIZER_ID);
    expect(sandbox.state.metadataTenantId).toBe(QUASAR_TENANT_ID);

    const replay = await client.createTransfer({
      apiKey: secretKey,
      idempotencyKey: reference,
      body: {
        amount: '50000.00',
        currency: 'NGN',
        reference,
        destination: { account_number: '0123456789', bank_code: '058', account_name: 'Ada Events' },
        metadata: { tenantId: QUASAR_TENANT_ID, schoolId: ORGANIZER_ID },
      },
    });
    expect(replay.reference).toBe(reference);
    expect(sandbox.state.transferCount).toBe(1);
    expect(payoutStateFromCreateResponse(String(replay.status))).not.toBe('paid');

    const pending = await client.getTransfer(secretKey, reference);
    expect(payoutStateFromConfirmedQuasarStatus(String(pending.status))).toBe('awaiting_approval');

    sandbox.state.transferStatus = 'SUCCESS';
    const confirmed = await client.getTransfer(secretKey, reference);
    payout = payoutStateFromConfirmedQuasarStatus(String(confirmed.status));
    expect(payout).toBe('paid');

    deliver('transfer.success', { reference, status: 'SUCCESS' });
    expect(payout).toBe('paid');
    expect(JSON.stringify(audits)).not.toContain(TENANT_KEY);
    expect(JSON.stringify(audits)).not.toContain('qpc_test_secret');
    expect(sandbox.state.paths.some((path) => path.includes('admin/auth/login'))).toBe(false);
  });

  it('does not mark a payout paid on insufficient balance, failure, rejection, timeout, or downtime', async () => {
    const client = clientFor(sandbox.baseUrl);
    sandbox.state.insufficient = true;
    await expect(
      client.createTransfer({
        apiKey: TENANT_KEY,
        idempotencyKey: 'owanbe_payout_low',
        body: { amount: '1.00', currency: 'NGN', reference: 'owanbe_payout_low', destination: {}, metadata: {} },
      }),
    ).rejects.toThrow(/insufficient balance/);
    expect(payoutStateFromCreateResponse('AWAITING_APPROVAL')).not.toBe('paid');
    sandbox.state.insufficient = false;

    expect(payoutStateFromConfirmedQuasarStatus('FAILED')).toBe('failed');
    expect(payoutStateFromConfirmedQuasarStatus('REJECTED')).toBe('rejected');
    expect(payoutStateFromCreateResponse('SUCCESS')).toBe('awaiting_approval');
    expect(ticketStateAfterFunding(false)).toBe('awaiting_transfer');

    sandbox.state.holdMs = 300;
    const slow = clientFor(sandbox.baseUrl, 40);
    await expect(slow.getTransfer(TENANT_KEY, 'missing')).rejects.toBeInstanceOf(QuasarHttpError);
    sandbox.state.holdMs = 0;

    sandbox.state.failNext = 2;
    const recovered = await client.getTransfer(TENANT_KEY, 'owanbe_payout_' + PAYOUT_ID);
    expect(recovered.status).toBe('SUCCESS');

    await sandbox.close();
    const down = clientFor(sandbox.baseUrl, 200);
    await expect(down.getTransfer(TENANT_KEY, 'offline')).rejects.toBeInstanceOf(QuasarHttpError);
  });
});
