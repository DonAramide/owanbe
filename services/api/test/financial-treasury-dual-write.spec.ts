import { FinancialDualWriteCoordinatorService } from '../src/modules/qfe/financial-dual-write-coordinator.service';
import type { DualWriteTreasuryContext } from '../src/modules/qfe/qfe.types';
import type { QfeFeatureFlagsService } from '../src/modules/qfe/qfe-feature-flags.service';
import type { TreasuryLedgerWriterService } from '../src/modules/qfe/treasury-ledger-writer.service';
import type { QfeFinancialWriterService } from '../src/modules/qfe/qfe-financial-writer.service';
import { TreasuryReconciliationService } from '../src/modules/qfe/treasury-reconciliation.service';
import { treasurySettlementReference } from '../src/modules/qfe/financial-treasury-orchestration.service';
import { QuaserWebhookService } from '../src/modules/payments/quaser-webhook.service';

const ledgerEntries = [
  {
    accountId: 'escrow',
    direction: 'debit' as const,
    amountMinor: 1000n,
    currency: 'NGN',
    memo: 'payout from escrow',
  },
  {
    accountId: 'vendor',
    direction: 'credit' as const,
    amountMinor: 1000n,
    currency: 'NGN',
    memo: 'vendor payable',
  },
];

function makeCtx(): DualWriteTreasuryContext {
  return {
    input: {
      client: {} as DualWriteTreasuryContext['input']['client'],
      tenantId: 't1',
      payoutId: 'p1',
      bookingId: 'b1',
      paymentId: 'pay1',
      vendorId: 'v1',
      currency: 'NGN',
      amountMinor: 1000n,
      settlementReference: treasurySettlementReference('p1'),
    },
    escrowAccountId: 'escrow',
    vendorPayableAccountId: 'vendor',
  };
}

describe('FinancialDualWriteCoordinatorService', () => {
  it('runs ledger-only when QFE_DUAL_WRITE_TREASURY is off', async () => {
    const flags = { isTreasuryDualWriteEnabled: () => false } as QfeFeatureFlagsService;
    const ledgerWriter = {
      writePayoutReleaseJournal: jest.fn().mockResolvedValue({
        ledgerTransactionId: 'lt1',
        ledgerEntries,
      }),
    } as unknown as TreasuryLedgerWriterService;
    const financialWriter = {
      writeTreasurySettlementFinancial: jest.fn(),
    } as unknown as QfeFinancialWriterService;
    const treasuryReconcile = {
      assertPostingParity: jest.fn(),
    } as unknown as TreasuryReconciliationService;

    const coordinator = new FinancialDualWriteCoordinatorService(
      flags,
      ledgerWriter,
      financialWriter,
      treasuryReconcile,
    );

    const result = await coordinator.coordinateTreasurySettlement(makeCtx());

    expect(result.dualWriteEnabled).toBe(false);
    expect(result.ledgerTransactionId).toBe('lt1');
    expect(result.reason).toBe('ledger_only');
    expect(financialWriter.writeTreasurySettlementFinancial).not.toHaveBeenCalled();
  });

  it('writes QFE financial layer when flag is on and postings reconcile', async () => {
    const flags = { isTreasuryDualWriteEnabled: () => true } as QfeFeatureFlagsService;
    const ledgerWriter = {
      writePayoutReleaseJournal: jest.fn().mockResolvedValue({
        ledgerTransactionId: 'lt1',
        ledgerEntries,
      }),
    } as unknown as TreasuryLedgerWriterService;
    const financialWriter = {
      writeTreasurySettlementFinancial: jest.fn().mockResolvedValue({ financialTransactionId: 'ft1' }),
    } as unknown as QfeFinancialWriterService;
    const treasuryReconcile = {
      assertPostingParity: jest.fn().mockResolvedValue({
        ok: true,
        ledgerDebitTotal: 1000n,
        ledgerCreditTotal: 1000n,
        qfeDebitTotal: 1000n,
        qfeCreditTotal: 1000n,
      }),
    } as unknown as TreasuryReconciliationService;

    const coordinator = new FinancialDualWriteCoordinatorService(
      flags,
      ledgerWriter,
      financialWriter,
      treasuryReconcile,
    );

    const result = await coordinator.coordinateTreasurySettlement(makeCtx());

    expect(result.dualWriteEnabled).toBe(true);
    expect(result.financialTransactionId).toBe('ft1');
    expect(financialWriter.writeTreasurySettlementFinancial).toHaveBeenCalled();
    expect(treasuryReconcile.assertPostingParity).toHaveBeenCalled();
  });

  it('fails closed on posting mismatch when dual-write is enabled', async () => {
    const flags = { isTreasuryDualWriteEnabled: () => true } as QfeFeatureFlagsService;
    const ledgerWriter = {
      writePayoutReleaseJournal: jest.fn().mockResolvedValue({
        ledgerTransactionId: 'lt1',
        ledgerEntries,
      }),
    } as unknown as TreasuryLedgerWriterService;
    const financialWriter = {
      writeTreasurySettlementFinancial: jest.fn().mockResolvedValue({ financialTransactionId: 'ft1' }),
    } as unknown as QfeFinancialWriterService;
    const treasuryReconcile = {
      assertPostingParity: jest.fn().mockResolvedValue({
        ok: false,
        ledgerDebitTotal: 1000n,
        ledgerCreditTotal: 1000n,
        qfeDebitTotal: 0n,
        qfeCreditTotal: 0n,
      }),
      recordTreasuryMismatch: jest.fn(),
    } as unknown as TreasuryReconciliationService;

    const coordinator = new FinancialDualWriteCoordinatorService(
      flags,
      ledgerWriter,
      financialWriter,
      treasuryReconcile,
    );

    await expect(coordinator.coordinateTreasurySettlement(makeCtx())).rejects.toThrow(
      'QFE_TREASURY_DUAL_WRITE_MISMATCH',
    );
    expect(treasuryReconcile.recordTreasuryMismatch).toHaveBeenCalled();
  });
});

describe('treasurySettlementReference', () => {
  it('uses stable payout-scoped reference for idempotency', () => {
    expect(treasurySettlementReference('550e8400-e29b-41d4-a716-446655440000')).toBe(
      'treasury_settlement:550e8400-e29b-41d4-a716-446655440000',
    );
  });
});

describe('TreasuryReconciliationService', () => {
  it('uses a non-empty reconciliation window for mismatch jobs', async () => {
    const client = {
      query: jest
        .fn()
        .mockResolvedValueOnce({ rows: [{ id: 'job1' }] })
        .mockResolvedValueOnce({ rows: [] }),
    };
    const service = new TreasuryReconciliationService();

    await service.recordTreasuryMismatch(client as never, {
      tenantId: '550e8400-e29b-41d4-a716-446655440001',
      payoutId: '550e8400-e29b-41d4-a716-446655440002',
      paymentId: '550e8400-e29b-41d4-a716-446655440003',
      bookingId: '550e8400-e29b-41d4-a716-446655440004',
      settlementReference: treasurySettlementReference('550e8400-e29b-41d4-a716-446655440002'),
      reconcile: {
        ok: false,
        ledgerDebitTotal: 1000n,
        ledgerCreditTotal: 1000n,
        qfeDebitTotal: 0n,
        qfeCreditTotal: 0n,
      },
    });

    expect(client.query.mock.calls[0][0]).toContain("now() + interval '1 millisecond'");
  });
});

describe('QuaserWebhookService payment capture handling', () => {
  const paymentId = '550e8400-e29b-41d4-a716-446655440003';
  const tenantId = '550e8400-e29b-41d4-a716-446655440001';
  const bookingId = '550e8400-e29b-41d4-a716-446655440004';
  const clientUserId = '550e8400-e29b-41d4-a716-446655440008';

  function makeCaptureService(params?: {
    paymentStatus?: string;
    underReview?: boolean;
    bookingTotal?: string;
    bookingFee?: string;
    confirmRowCount?: number;
    observedBookingStatus?: string;
    applyResult?: Record<string, unknown>;
  }) {
    const client = {
      query: jest.fn(async (sql: string) => {
        if (sql === 'BEGIN' || sql === 'COMMIT' || sql === 'ROLLBACK') return { rows: [] };
        if (sql.includes('FROM payments WHERE id = $1 FOR UPDATE')) {
          return {
            rows: [
              {
                id: paymentId,
                tenant_id: tenantId,
                booking_id: bookingId,
                currency: 'NGN',
                status: params?.paymentStatus ?? 'initiated',
                under_review: params?.underReview ?? false,
                quaser_reference: 'qr1',
                metadata: {},
              },
            ],
          };
        }
        if (sql.includes('FROM bookings WHERE id = $1 AND tenant_id = $2 FOR UPDATE')) {
          return {
            rows: [
              {
                total_minor: params?.bookingTotal ?? '1000',
                platform_fee_minor: params?.bookingFee ?? '100',
                status: 'pending_payment',
                client_user_id: clientUserId,
              },
            ],
          };
        }
        if (sql.includes('SELECT COUNT(*)::text AS c')) {
          return { rows: [{ c: '1' }] };
        }
        if (sql.includes('owanbe_apply_quaser_payment_capture')) {
          return {
            rows: [
              {
                owanbe_apply_quaser_payment_capture: params?.applyResult ?? { reason: 'applied' },
              },
            ],
          };
        }
        if (sql.includes('UPDATE bookings')) {
          return {
            rowCount: params?.confirmRowCount ?? 1,
            rows: (params?.confirmRowCount ?? 1) > 0 ? [{ id: bookingId }] : [],
          };
        }
        if (sql.includes('SELECT status::text FROM bookings')) {
          return { rows: [{ status: params?.observedBookingStatus ?? 'cancelled' }] };
        }
        return { rows: [] };
      }),
      release: jest.fn(),
    };
    const pool = { connect: jest.fn().mockResolvedValue(client) };
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'PAYMENT_S2S_VERIFY_THRESHOLD_MINOR') return 500000;
        if (key === 'QUASER_ROUTER_BASE_URL') return '';
        if (key === 'QUASER_ROUTER_API_KEY') return '';
        return '';
      }),
    };
    const ledger = {
      ensurePoolLedgerAccounts: jest.fn().mockResolvedValue({
        pspClearingId: '550e8400-e29b-41d4-a716-446655440009',
        escrowPoolId: '550e8400-e29b-41d4-a716-446655440010',
        platformFeesId: '550e8400-e29b-41d4-a716-446655440011',
      }),
    };
    const quaser = { verifyPayment: jest.fn() };
    const reconciliation = { recordInlineIssue: jest.fn() };
    const alerts = { trigger: jest.fn() };
    const service = new QuaserWebhookService(
      pool as never,
      config as never,
      ledger as never,
      quaser as never,
      reconciliation as never,
      alerts as never,
      {} as never,
      { applyCapture: jest.fn() } as never,
      { completePayout: jest.fn() } as never,
    );

    const invoke = (payload?: Record<string, unknown>) =>
      (service as never as {
        handlePaymentCaptured: (
          payload: Record<string, unknown>,
          eventType: string,
          eventId: string,
        ) => Promise<{ ok: boolean; duplicate?: boolean; reason?: string }>;
      }).handlePaymentCaptured(
        { payment_id: paymentId, amount_minor: '1000', ...(payload ?? {}) },
        'payment.captured',
        'evt1',
      );

    return { alerts, client, ledger, quaser, reconciliation, invoke };
  }

  it('acks duplicate captured payment and only confirms booking', async () => {
    const { client, ledger, invoke } = makeCaptureService({ paymentStatus: 'captured' });

    const result = await invoke();

    expect(result).toEqual({ ok: true, duplicate: true, reason: 'already_captured' });
    expect(ledger.ensurePoolLedgerAccounts).not.toHaveBeenCalled();
    expect(client.query).toHaveBeenCalledWith('COMMIT');
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes('owanbe_apply_quaser_payment_capture'))).toBe(
      false,
    );
  });

  it('rejects amount mismatch before ledger capture', async () => {
    const { alerts, client, ledger, invoke } = makeCaptureService();

    const result = await invoke({ amount_minor: '999' });

    expect(result).toEqual({ ok: false, reason: 'amount_mismatch' });
    expect(alerts.trigger).toHaveBeenCalledWith(
      'payment_mismatch',
      { paymentId, expectedTotal: '1000', amountFromRouter: '999', tenantId },
      'CRITICAL',
    );
    expect(ledger.ensurePoolLedgerAccounts).not.toHaveBeenCalled();
    expect(client.query).toHaveBeenCalledWith('ROLLBACK');
  });

  it('captures payment and confirms pending booking once', async () => {
    const { client, ledger, invoke } = makeCaptureService();

    const result = await invoke();

    expect(result).toEqual({ ok: true, reason: 'applied' });
    expect(ledger.ensurePoolLedgerAccounts).toHaveBeenCalled();
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes('owanbe_apply_quaser_payment_capture'))).toBe(
      true,
    );
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes('UPDATE bookings'))).toBe(true);
    expect(client.query).toHaveBeenCalledWith('COMMIT');
  });

  it('records reconciliation issue when captured payment cannot confirm booking', async () => {
    const { client, reconciliation, invoke } = makeCaptureService({
      confirmRowCount: 0,
      observedBookingStatus: 'cancelled',
    });

    const result = await invoke();

    expect(result).toEqual({ ok: true, reason: 'applied' });
    expect(reconciliation.recordInlineIssue).toHaveBeenCalledWith(
      client,
      expect.objectContaining({
        tenantId,
        paymentId,
        bookingId,
        severity: 'critical',
      }),
    );
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes('UPDATE payments'))).toBe(true);
    expect(client.query).toHaveBeenCalledWith('COMMIT');
  });
});

describe('QuaserWebhookService payout QFE mismatch handling', () => {
  function makePayoutService(params?: {
    payoutStatus?: string;
    paymentStatus?: string;
    treasury?: { postSettlementJournal: jest.Mock };
  }) {
    const payoutStatus = params?.payoutStatus ?? 'processing';
    const paymentStatus = params?.paymentStatus ?? 'captured';
    const client = {
      query: jest.fn(async (sql: string) => {
        if (sql === 'BEGIN' || sql === 'COMMIT' || sql === 'ROLLBACK') return { rows: [] };
        if (sql.includes('FROM payouts WHERE id = $1')) {
          return {
            rows: [
              {
                id: '550e8400-e29b-41d4-a716-446655440002',
                tenant_id: '550e8400-e29b-41d4-a716-446655440001',
                status: payoutStatus,
                under_review: false,
                booking_id: '550e8400-e29b-41d4-a716-446655440004',
                payment_id: '550e8400-e29b-41d4-a716-446655440003',
                vendor_id: '550e8400-e29b-41d4-a716-446655440005',
                currency: 'NGN',
                amount_minor: '1000',
                quaser_reference: 'qr1',
              },
            ],
          };
        }
        if (sql.includes('FROM payments WHERE id = $1 AND tenant_id = $2')) {
          return { rows: [{ status: paymentStatus }] };
        }
        return { rows: [] };
      }),
      release: jest.fn(),
    };
    const pool = {
      connect: jest.fn().mockResolvedValue(client),
      query: jest.fn().mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM payouts WHERE id = $1')) {
          return { rows: [{ id: '550e8400-e29b-41d4-a716-446655440002' }] };
        }
        if (sql.includes('SELECT id FROM organizer_payouts WHERE id = $1')) {
          return { rows: [] };
        }
        return { rows: [] };
      }),
    };
    const treasury = params?.treasury ?? {
      postSettlementJournal: jest.fn().mockResolvedValue({
        skipped: false,
        reason: 'dual_write_posted',
        settlementReference: treasurySettlementReference('550e8400-e29b-41d4-a716-446655440002'),
        ledgerTransactionId: '550e8400-e29b-41d4-a716-446655440006',
        financialTransactionId: '550e8400-e29b-41d4-a716-446655440007',
        dualWriteEnabled: true,
      }),
    };
    const service = new QuaserWebhookService(
      pool as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      treasury as never,
      { applyCapture: jest.fn() } as never,
      { completePayout: jest.fn() } as never,
    );

    const invoke = () =>
      (service as never as {
        handlePayoutEvent: (
          payload: Record<string, unknown>,
          eventType: string,
          eventId: string,
        ) => Promise<{ ok: boolean; duplicate?: boolean; reason?: string }>;
      }).handlePayoutEvent(
        { payout_id: '550e8400-e29b-41d4-a716-446655440002' },
        'payout.completed',
        'evt1',
      );

    return { client, treasury, invoke };
  }

  it('commits mismatch evidence without completing the payout', async () => {
    const { client, invoke } = makePayoutService({
      treasury: {
        postSettlementJournal: jest.fn().mockRejectedValue(new Error('QFE_TREASURY_DUAL_WRITE_MISMATCH')),
      },
    });

    const result = await invoke();

    expect(result).toEqual({ ok: false, reason: 'qfe_treasury_dual_write_mismatch' });
    expect(client.query).toHaveBeenCalledWith('COMMIT');
    expect(client.query).not.toHaveBeenCalledWith('ROLLBACK');
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes("SET status = 'completed'"))).toBe(
      false,
    );
  });

  it('acks duplicate completed payout webhooks without reposting treasury journal', async () => {
    const { client, treasury, invoke } = makePayoutService({ payoutStatus: 'completed' });

    const result = await invoke();

    expect(result).toEqual({ ok: true, duplicate: true });
    expect(treasury.postSettlementJournal).not.toHaveBeenCalled();
    expect(client.query).toHaveBeenCalledWith('COMMIT');
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes("SET status = 'completed'"))).toBe(
      false,
    );
  });

  it('does not complete payout when captured payment precondition is missing', async () => {
    const { client, treasury, invoke } = makePayoutService({ paymentStatus: 'authorized' });

    const result = await invoke();

    expect(result).toEqual({ ok: false, reason: 'payment_not_captured' });
    expect(treasury.postSettlementJournal).not.toHaveBeenCalled();
    expect(client.query).toHaveBeenCalledWith('ROLLBACK');
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes("SET status = 'completed'"))).toBe(
      false,
    );
  });

  it('completes payout once when treasury journal is already posted with a ledger transaction', async () => {
    const { client, invoke } = makePayoutService({
      treasury: {
        postSettlementJournal: jest.fn().mockResolvedValue({
          skipped: true,
          reason: 'already_posted',
          settlementReference: treasurySettlementReference('550e8400-e29b-41d4-a716-446655440002'),
          ledgerTransactionId: '550e8400-e29b-41d4-a716-446655440006',
          financialTransactionId: '550e8400-e29b-41d4-a716-446655440007',
          dualWriteEnabled: true,
        }),
      },
    });

    const result = await invoke();

    expect(result).toEqual({ ok: true, reason: 'payout_completed' });
    expect(client.query).toHaveBeenCalledWith('COMMIT');
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes("SET status = 'completed'"))).toBe(
      true,
    );
  });

  it('does not complete payout when treasury replay has no ledger transaction', async () => {
    const { client, invoke } = makePayoutService({
      treasury: {
        postSettlementJournal: jest.fn().mockResolvedValue({
          skipped: true,
          reason: 'already_posted',
          settlementReference: treasurySettlementReference('550e8400-e29b-41d4-a716-446655440002'),
          dualWriteEnabled: false,
        }),
      },
    });

    const result = await invoke();

    expect(result).toEqual({ ok: true, duplicate: true, reason: 'treasury_already_posted' });
    expect(client.query).toHaveBeenCalledWith('ROLLBACK');
    expect(client.query.mock.calls.some(([sql]) => String(sql).includes("SET status = 'completed'"))).toBe(
      false,
    );
  });
});
