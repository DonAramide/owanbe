import { Injectable, Inject } from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

export interface PoolLedgerAccountIds {
  pspClearingId: string;
  escrowPoolId: string;
  platformFeesId: string;
}

@Injectable()
export class LedgerService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  private codePspClearing(currency: string) {
    return `quaser_psp_clearing_${currency}`;
  }
  private codeEscrowPool(currency: string) {
    return `escrow_pool_${currency}`;
  }
  private codePlatformFees(currency: string) {
    return `platform_fees_${currency}`;
  }
  private codeVendorPayable(vendorId: string, currency: string) {
    return `vendor_payable_${vendorId}_${currency}`;
  }

  async ensurePoolLedgerAccounts(
    client: Pool | PoolClient,
    tenantId: string,
    currency: string,
  ): Promise<PoolLedgerAccountIds> {
    const cur = currency.toUpperCase();
    await client.query(
      `INSERT INTO ledger_accounts (tenant_id, kind, currency, code, metadata)
       VALUES ($1, 'external_psp', $2, $3, '{}'::jsonb)
       ON CONFLICT (tenant_id, currency, code) DO NOTHING`,
      [tenantId, cur, this.codePspClearing(cur)],
    );
    await client.query(
      `INSERT INTO ledger_accounts (tenant_id, kind, currency, code, metadata)
       VALUES ($1, 'escrow', $2, $3, '{}'::jsonb)
       ON CONFLICT (tenant_id, currency, code) DO NOTHING`,
      [tenantId, cur, this.codeEscrowPool(cur)],
    );
    await client.query(
      `INSERT INTO ledger_accounts (tenant_id, kind, currency, code, metadata)
       VALUES ($1, 'platform_fees', $2, $3, '{}'::jsonb)
       ON CONFLICT (tenant_id, currency, code) DO NOTHING`,
      [tenantId, cur, this.codePlatformFees(cur)],
    );

    const { rows } = await client.query<{ id: string; code: string }>(
      `SELECT id, code FROM ledger_accounts
       WHERE tenant_id = $1 AND currency = $2 AND code = ANY($3::text[])`,
      [tenantId, cur, [this.codePspClearing(cur), this.codeEscrowPool(cur), this.codePlatformFees(cur)]],
    );
    const byCode = new Map(rows.map((r) => [r.code, r.id]));
    const psp = byCode.get(this.codePspClearing(cur));
    const escrow = byCode.get(this.codeEscrowPool(cur));
    const fees = byCode.get(this.codePlatformFees(cur));
    if (!psp || !escrow || !fees) {
      throw new Error('ledger_accounts bootstrap failed for tenant/currency');
    }
    return { pspClearingId: psp, escrowPoolId: escrow, platformFeesId: fees };
  }

  async ensureVendorPayableAccount(
    client: Pool | PoolClient,
    tenantId: string,
    vendorId: string,
    currency: string,
  ): Promise<string> {
    const cur = currency.toUpperCase();
    const code = this.codeVendorPayable(vendorId, cur);
    await client.query(
      `INSERT INTO ledger_accounts (tenant_id, kind, currency, code, vendor_id, metadata)
       VALUES ($1, 'vendor_payable', $2, $3, $4, '{}'::jsonb)
       ON CONFLICT (tenant_id, currency, code) DO NOTHING`,
      [tenantId, cur, code, vendorId],
    );
    const { rows } = await client.query<{ id: string }>(
      `SELECT id FROM ledger_accounts WHERE tenant_id = $1 AND currency = $2 AND code = $3`,
      [tenantId, cur, code],
    );
    const id = rows[0]?.id;
    if (!id) {
      throw new Error('vendor_payable ledger account missing');
    }
    return id;
  }

  private codeOrganizerPayable(organizerId: string, currency: string) {
    return `organizer_payable_${organizerId}_${currency}`;
  }

  private codeOrganizerPayoutClearing(currency: string) {
    return `organizer_payout_clearing_${currency}`;
  }

  async ensureOrganizerPayoutClearingAccount(
    client: Pool | PoolClient,
    tenantId: string,
    currency: string,
  ): Promise<string> {
    const cur = currency.toUpperCase();
    const code = this.codeOrganizerPayoutClearing(cur);
    await client.query(
      `INSERT INTO ledger_accounts (tenant_id, kind, currency, code, metadata)
       VALUES ($1, 'organizer_payout_clearing', $2, $3, '{}'::jsonb)
       ON CONFLICT (tenant_id, currency, code) DO NOTHING`,
      [tenantId, cur, code],
    );
    const { rows } = await client.query<{ id: string }>(
      `SELECT id FROM ledger_accounts WHERE tenant_id = $1 AND currency = $2 AND code = $3`,
      [tenantId, cur, code],
    );
    const id = rows[0]?.id;
    if (!id) throw new Error('organizer_payout_clearing ledger account missing');
    return id;
  }

  async applyOrganizerPayoutReleaseLedger(
    client: PoolClient,
    params: {
      tenantId: string;
      ticketOrderId: string;
      payoutId: string;
      amountMinor: bigint;
      currency: string;
      organizerPayableAccountId: string;
      organizerPayoutClearingAccountId: string;
    },
  ): Promise<string> {
    const idem = `organizer_payout_release:${params.payoutId}`;
    const ins = await client.query<{ id: string }>(
      `INSERT INTO ledger_transactions (tenant_id, ticket_order_id, idempotency_key, reason, commerce_kind)
       VALUES ($1, $2, $3, 'payout_organizer_release', 'PAYOUT'::commerce_kind)
       ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
       RETURNING id`,
      [params.tenantId, params.ticketOrderId, idem],
    );
    let txnId = ins.rows[0]?.id;
    if (!txnId) {
      const ex = await client.query<{ id: string }>(
        `SELECT id FROM ledger_transactions WHERE tenant_id = $1 AND idempotency_key = $2`,
        [params.tenantId, idem],
      );
      txnId = ex.rows[0]?.id;
    }
    if (!txnId) throw new Error('organizer payout ledger transaction missing');

    const { rows: lineCount } = await client.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_lines WHERE transaction_id = $1`,
      [txnId],
    );
    if (lineCount[0]?.n === '0') {
      const amt = String(params.amountMinor);
      const cur = params.currency.toUpperCase();
      await client.query(
        `INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
         VALUES
           ($1, $2, 'debit', $3::bigint, $4, 'organizer payout release'),
           ($1, $5, 'credit', $3::bigint, $4, 'organizer payout clearing')`,
        [
          txnId,
          params.organizerPayableAccountId,
          amt,
          cur,
          params.organizerPayoutClearingAccountId,
        ],
      );
    }
    return txnId;
  }

  async applyTicketRefundLedger(
    client: PoolClient,
    params: {
      tenantId: string;
      ticketOrderId: string;
      refundCaseId: string;
      organizerId: string;
      refundMinor: bigint;
      feeReversalMinor: bigint;
      currency: string;
      organizerPayableAccountId: string;
      escrowAccountId: string;
      platformFeesAccountId: string;
      pspClearingAccountId: string;
    },
  ): Promise<string> {
    const idem = `ticket_refund:${params.refundCaseId}`;
    const ins = await client.query<{ id: string }>(
      `INSERT INTO ledger_transactions (tenant_id, ticket_order_id, idempotency_key, reason, commerce_kind)
       VALUES ($1, $2, $3, 'payment_refund_ticket', 'TICKET'::commerce_kind)
       ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
       RETURNING id`,
      [params.tenantId, params.ticketOrderId, idem],
    );
    let txnId = ins.rows[0]?.id;
    if (!txnId) {
      const ex = await client.query<{ id: string }>(
        `SELECT id FROM ledger_transactions WHERE tenant_id = $1 AND idempotency_key = $2`,
        [params.tenantId, idem],
      );
      txnId = ex.rows[0]?.id;
    }
    if (!txnId) throw new Error('ticket refund ledger transaction missing');

    const { rows: lineCount } = await client.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_lines WHERE transaction_id = $1`,
      [txnId],
    );
    if (lineCount[0]?.n === '0') {
      const cur = params.currency.toUpperCase();
      const refund = String(params.refundMinor);
      const fee = String(params.feeReversalMinor);
      const totalOut = String(params.refundMinor + params.feeReversalMinor);

      if (params.refundMinor > 0n) {
        await client.query(
          `INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
           VALUES ($1, $2, 'debit', $3::bigint, $4, 'ticket refund organizer reversal')`,
          [txnId, params.organizerPayableAccountId, refund, cur],
        );
      }
      if (params.feeReversalMinor > 0n) {
        await client.query(
          `INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
           VALUES ($1, $2, 'debit', $3::bigint, $4, 'ticket refund fee reversal')`,
          [txnId, params.platformFeesAccountId, fee, cur],
        );
      }
      if (params.refundMinor + params.feeReversalMinor > 0n) {
        await client.query(
          `INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
           VALUES ($1, $2, 'credit', $3::bigint, $4, 'ticket refund to psp clearing')`,
          [txnId, params.pspClearingAccountId, totalOut, cur],
        );
      }
    }
    return txnId;
  }

  async ensureOrganizerPayableAccount(
    client: Pool | PoolClient,
    tenantId: string,
    organizerId: string,
    currency: string,
  ): Promise<string> {
    const cur = currency.toUpperCase();
    const code = this.codeOrganizerPayable(organizerId, cur);
    await client.query(
      `INSERT INTO ledger_accounts (tenant_id, kind, currency, code, organizer_id, metadata)
       VALUES ($1, 'organizer_payable', $2, $3, $4, '{}'::jsonb)
       ON CONFLICT (tenant_id, currency, code) DO NOTHING`,
      [tenantId, cur, code, organizerId],
    );
    const { rows } = await client.query<{ id: string }>(
      `SELECT id FROM ledger_accounts WHERE tenant_id = $1 AND currency = $2 AND code = $3`,
      [tenantId, cur, code],
    );
    const id = rows[0]?.id;
    if (!id) {
      throw new Error('organizer_payable ledger account missing');
    }
    return id;
  }

  /**
   * Idempotent escrow → vendor_payable release for a payout row (ledger only; caller updates payout).
   */
  async applyPayoutReleaseLedger(
    client: PoolClient,
    params: {
      tenantId: string;
      bookingId: string;
      paymentId: string;
      payoutId: string;
      amountMinor: bigint;
      currency: string;
      escrowAccountId: string;
      vendorPayableAccountId: string;
    },
  ): Promise<string> {
    const idem = `payout_release:${params.payoutId}`;
    const ins = await client.query<{ id: string }>(
      `INSERT INTO ledger_transactions (tenant_id, booking_id, payment_id, idempotency_key, reason)
       VALUES ($1, $2, $3, $4, 'payout_escrow_release')
       ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
       RETURNING id`,
      [params.tenantId, params.bookingId, params.paymentId, idem],
    );
    let txnId = ins.rows[0]?.id;
    if (!txnId) {
      const ex = await client.query<{ id: string }>(
        `SELECT id FROM ledger_transactions WHERE tenant_id = $1 AND idempotency_key = $2`,
        [params.tenantId, idem],
      );
      txnId = ex.rows[0]?.id;
    }
    if (!txnId) {
      throw new Error('payout ledger transaction missing');
    }

    const { rows: lineCount } = await client.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_lines WHERE transaction_id = $1`,
      [txnId],
    );
    if (lineCount[0]?.n === '0') {
      const cur = params.currency.toUpperCase();
      const amt = String(params.amountMinor);
      await client.query(
        `INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
         VALUES
           ($1, $2, 'debit', $3::bigint, $4, 'payout from escrow'),
           ($1, $5, 'credit', $3::bigint, $4, 'vendor payable')`,
        [txnId, params.escrowAccountId, amt, cur, params.vendorPayableAccountId],
      );
    }
    return txnId;
  }

  async applyRefundLedger(
    client: PoolClient,
    params: {
      tenantId: string;
      bookingId: string;
      paymentId: string;
      refundKey: string;
      amountMinor: bigint;
      currency: string;
      escrowAccountId: string;
      pspClearingAccountId: string;
    },
  ): Promise<string> {
    const ins = await client.query<{ id: string }>(
      `INSERT INTO ledger_transactions (tenant_id, booking_id, payment_id, idempotency_key, reason)
       VALUES ($1, $2, $3, $4, 'payment_refund')
       ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
       RETURNING id`,
      [params.tenantId, params.bookingId, params.paymentId, params.refundKey],
    );
    let txnId = ins.rows[0]?.id;
    if (!txnId) {
      const ex = await client.query<{ id: string }>(
        `SELECT id FROM ledger_transactions WHERE tenant_id = $1 AND idempotency_key = $2`,
        [params.tenantId, params.refundKey],
      );
      txnId = ex.rows[0]?.id;
    }
    if (!txnId) throw new Error('refund ledger transaction missing');

    const { rows: lineCount } = await client.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_lines WHERE transaction_id = $1`,
      [txnId],
    );
    if (lineCount[0]?.n === '0') {
      const amt = String(params.amountMinor);
      const cur = params.currency.toUpperCase();
      await client.query(
        `INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
         VALUES
         ($1, $2, 'debit', $3::bigint, $4, 'refund from escrow'),
         ($1, $5, 'credit', $3::bigint, $4, 'refund to psp clearing')`,
        [txnId, params.escrowAccountId, amt, cur, params.pspClearingAccountId],
      );
    }
    return txnId;
  }

  async applyChargebackLedger(
    client: PoolClient,
    params: {
      tenantId: string;
      bookingId: string;
      paymentId: string;
      chargebackKey: string;
      amountMinor: bigint;
      currency: string;
      vendorPayableAccountId: string;
      pspClearingAccountId: string;
    },
  ): Promise<string> {
    const ins = await client.query<{ id: string }>(
      `INSERT INTO ledger_transactions (tenant_id, booking_id, payment_id, idempotency_key, reason)
       VALUES ($1, $2, $3, $4, 'payment_chargeback')
       ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
       RETURNING id`,
      [params.tenantId, params.bookingId, params.paymentId, params.chargebackKey],
    );
    let txnId = ins.rows[0]?.id;
    if (!txnId) {
      const ex = await client.query<{ id: string }>(
        `SELECT id FROM ledger_transactions WHERE tenant_id = $1 AND idempotency_key = $2`,
        [params.tenantId, params.chargebackKey],
      );
      txnId = ex.rows[0]?.id;
    }
    if (!txnId) throw new Error('chargeback ledger transaction missing');

    const { rows: lineCount } = await client.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_lines WHERE transaction_id = $1`,
      [txnId],
    );
    if (lineCount[0]?.n === '0') {
      const amt = String(params.amountMinor);
      const cur = params.currency.toUpperCase();
      await client.query(
        `INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
         VALUES
         ($1, $2, 'debit', $3::bigint, $4, 'chargeback vendor liability'),
         ($1, $5, 'credit', $3::bigint, $4, 'chargeback psp clearing')`,
        [txnId, params.vendorPayableAccountId, amt, cur, params.pspClearingAccountId],
      );
    }
    return txnId;
  }
}
