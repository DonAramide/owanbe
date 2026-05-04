import { Injectable, Inject, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { withActor } from '../../database/with-actor';
import { LedgerService } from './ledger.service';
import { AuditLogService } from '../../audit/audit-log.service';
import { AlertsService } from './alerts.service';

@Injectable()
export class FinancialAdjustmentsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly ledger: LedgerService,
    private readonly audit: AuditLogService,
    private readonly alerts: AlertsService,
  ) {}

  async refundPayment(params: {
    tenantId: string;
    paymentId: string;
    actorUserId: string;
    amountMinor?: string;
    reason?: string;
    idempotencyKey?: string;
  }) {
    return withActor(this.pool, params.actorUserId, async (c) => {
      const { rows } = await c.query<{
        id: string;
        booking_id: string;
        status: string;
        currency: string;
        amount_captured_minor: string;
        amount_refunded_minor: string;
        under_review: boolean;
      }>(
        `SELECT id, booking_id, status::text, currency, amount_captured_minor::text,
                amount_refunded_minor::text, under_review
         FROM payments WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
        [params.paymentId, params.tenantId],
      );
      const p = rows[0];
      if (!p) throw new UnprocessableEntityException({ code: 'NOT_FOUND', message: 'Payment not found' });
      if (p.under_review) {
        throw new UnprocessableEntityException({
          code: 'UNDER_REVIEW',
          message: 'Payment is under review and cannot be adjusted',
        });
      }
      if (p.status !== 'captured' && p.status !== 'partially_refunded') {
        throw new UnprocessableEntityException({
          code: 'INVALID_STATE',
          message: `Refund not allowed from status ${p.status}`,
        });
      }
      const captured = BigInt(p.amount_captured_minor);
      const refunded = BigInt(p.amount_refunded_minor);
      const remaining = captured - refunded;
      const amount = params.amountMinor ? BigInt(params.amountMinor) : remaining;
      if (amount <= 0n || amount > remaining) {
        throw new UnprocessableEntityException({
          code: 'INVALID_REFUND_AMOUNT',
          message: 'Refund amount must be > 0 and <= remaining captured amount',
        });
      }

      const accounts = await this.ledger.ensurePoolLedgerAccounts(c, params.tenantId, p.currency);
      const idem =
        params.idempotencyKey?.trim() ||
        `refund:${params.paymentId}:${amount.toString()}:${params.reason ?? 'n/a'}`;
      const txnId = await this.ledger.applyRefundLedger(c, {
        tenantId: params.tenantId,
        bookingId: p.booking_id,
        paymentId: p.id,
        refundKey: idem,
        amountMinor: amount,
        currency: p.currency,
        escrowAccountId: accounts.escrowPoolId,
        pspClearingAccountId: accounts.pspClearingId,
      });

      const nextRefunded = refunded + amount;
      const full = nextRefunded === captured;
      await c.query(
        `UPDATE payments
         SET amount_refunded_minor = $2::bigint,
             status = $3::payment_status,
             metadata = metadata || $4::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [
          p.id,
          nextRefunded.toString(),
          full ? 'refunded' : 'partially_refunded',
          JSON.stringify({ refund_reason: params.reason ?? null }),
        ],
      );
      if (full) {
        await c.query(
          `UPDATE bookings SET status = 'refunded', updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [p.booking_id, params.tenantId],
        );
      }
      await this.audit.logAction({
        tenantId: params.tenantId,
        actorUserId: params.actorUserId,
        action: 'PAYMENT_REFUND',
        resourceType: 'payment',
        resourceId: p.id,
        metadata: { amountMinor: amount.toString(), ledgerTransactionId: txnId, full },
      });
      return { ok: true, paymentId: p.id, ledgerTransactionId: txnId, refundedMinor: nextRefunded.toString() };
    });
  }

  async applyChargeback(params: {
    tenantId: string;
    paymentId: string;
    actorUserId: string;
    amountMinor: string;
    eventId: string;
    suspendVendorPayouts?: boolean;
  }) {
    if (!params.eventId?.trim()) {
      throw new UnprocessableEntityException({
        code: 'EVENT_ID_REQUIRED',
        message: 'Chargeback eventId is required',
      });
    }
    return withActor(this.pool, params.actorUserId, async (c) => {
      const { rows } = await c.query<{
        id: string;
        booking_id: string;
        status: string;
        currency: string;
        under_review: boolean;
        amount_captured_minor: string;
        vendor_id: string;
      }>(
        `SELECT p.id, p.booking_id, p.status::text, p.currency, p.under_review, p.amount_captured_minor::text, b.vendor_id
         FROM payments p
         INNER JOIN bookings b ON b.id = p.booking_id
         WHERE p.id = $1 AND p.tenant_id = $2
         FOR UPDATE`,
        [params.paymentId, params.tenantId],
      );
      const p = rows[0];
      if (!p) throw new UnprocessableEntityException({ code: 'NOT_FOUND', message: 'Payment not found' });
      if (p.status !== 'captured' && p.status !== 'partially_refunded') {
        throw new UnprocessableEntityException({
          code: 'INVALID_STATE',
          message: `Chargeback not allowed from status ${p.status}`,
        });
      }
      if (!params.amountMinor?.trim()) {
        throw new UnprocessableEntityException({
          code: 'AMOUNT_REQUIRED',
          message: 'Chargeback amountMinor is required',
        });
      }
      const amount = BigInt(params.amountMinor);
      if (amount <= 0n || amount > BigInt(p.amount_captured_minor)) {
        throw new UnprocessableEntityException({
          code: 'INVALID_CHARGEBACK_AMOUNT',
          message: 'Chargeback amount must be > 0 and <= captured amount',
        });
      }

      const accounts = await this.ledger.ensurePoolLedgerAccounts(c, params.tenantId, p.currency);
      const vendorPayableId = await this.ledger.ensureVendorPayableAccount(
        c,
        params.tenantId,
        p.vendor_id,
        p.currency,
      );
      const idem = `chargeback:${params.paymentId}:${params.eventId}`;
      const txnId = await this.ledger.applyChargebackLedger(c, {
        tenantId: params.tenantId,
        bookingId: p.booking_id,
        paymentId: p.id,
        chargebackKey: idem,
        amountMinor: amount,
        currency: p.currency,
        vendorPayableAccountId: vendorPayableId,
        pspClearingAccountId: accounts.pspClearingId,
      });

      await c.query(
        `UPDATE payments
         SET under_review = TRUE,
             metadata = metadata || $2::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [
          p.id,
          JSON.stringify({ chargeback: { eventId: params.eventId, amountMinor: params.amountMinor } }),
        ],
      );
      if (params.suspendVendorPayouts) {
        await c.query(
          `UPDATE vendors
           SET metadata = metadata || '{"payout_hold": true}'::jsonb, updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [p.vendor_id, params.tenantId],
        );
      }
      await this.audit.logAction({
        tenantId: params.tenantId,
        actorUserId: params.actorUserId,
        action: 'PAYMENT_CHARGEBACK',
        resourceType: 'payment',
        resourceId: p.id,
        metadata: { ledgerTransactionId: txnId, amountMinor: params.amountMinor },
      });
      await this.alerts.trigger(
        'chargeback_received',
        { tenantId: params.tenantId, paymentId: p.id, amountMinor: params.amountMinor },
        'CRITICAL',
      );
      return { ok: true, paymentId: p.id, ledgerTransactionId: txnId };
    });
  }
}
