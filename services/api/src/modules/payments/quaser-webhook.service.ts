import {
  BadRequestException,
  Injectable,
  Inject,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { verifyQuaserWebhookSignature } from './quaser-signature.util';
import { LedgerService } from './ledger.service';
import { QuaserRouterService } from './quaser-router.service';
import { ReconciliationService } from './reconciliation.service';
import { AlertsService } from './alerts.service';
import {
  FinancialTreasuryOrchestrationService,
  treasurySettlementReference,
} from '../qfe/financial-treasury-orchestration.service';
import { TicketCaptureService } from '../commerce/ticket-capture.service';
import { OrganizerPayoutService } from '../commerce/organizer-payout.service';

export interface QuaserWebhookAck {
  ok: boolean;
  duplicate?: boolean;
  reason?: string;
}

function suspiciousFromPayload(payload: Record<string, unknown>): boolean {
  if (payload.suspicious === true || payload.flagged === true) return true;
  if (payload.verify_required === true) return true;
  const risk = payload.risk_score;
  if (typeof risk === 'number' && risk >= 70) return true;
  const level = String(payload.risk_level ?? '').toLowerCase();
  if (['high', 'elevated', 'blocked', 'severe'].includes(level)) return true;
  const activity = String(payload.suspicious_activity ?? '').toLowerCase();
  if (activity && activity !== 'false' && activity !== 'none') return true;
  return false;
}

function newDeviceFromPayload(payload: Record<string, unknown>): boolean {
  if (payload.new_device === true) return true;
  if (payload.device_trusted === false) return true;
  const hint = String(payload.device_hint ?? '').toLowerCase();
  if (hint === 'new' || hint === 'unknown') return true;
  const trust = String(payload.device_trust_tier ?? '').toLowerCase();
  if (trust === 'new' || trust === 'untrusted') return true;
  return false;
}

function isTreasuryDualWriteMismatch(error: unknown): boolean {
  return error instanceof Error && error.message === 'QFE_TREASURY_DUAL_WRITE_MISMATCH';
}

/**
 * Quaser webhooks: never trust payload tenant_id — always derive tenant from payment/payout rows.
 * Capture path uses row locks + mandatory S2S rules; booking confirm only from pending_payment.
 */
@Injectable()
export class QuaserWebhookService {
  private readonly logger = new Logger(QuaserWebhookService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly ledger: LedgerService,
    private readonly quaser: QuaserRouterService,
    private readonly reconciliation: ReconciliationService,
    private readonly alerts: AlertsService,
    private readonly treasury: FinancialTreasuryOrchestrationService,
    private readonly ticketCapture: TicketCaptureService,
    private readonly organizerPayout: OrganizerPayoutService,
  ) {}

  async handleSignedWebhook(rawBody: Buffer, signatureHeader: string | undefined): Promise<QuaserWebhookAck> {
    const secret = this.config.get('QUASER_WEBHOOK_SECRET', { infer: true });
    if (!secret) {
      await this.alerts.trigger('webhook_verification_failure', { reason: 'secret_missing' }, 'CRITICAL');
      throw new UnauthorizedException({
        code: 'WEBHOOK_NOT_CONFIGURED',
        message: 'Quaser webhook secret is not configured',
      });
    }
    if (!verifyQuaserWebhookSignature(secret, rawBody, signatureHeader)) {
      await this.alerts.trigger('webhook_verification_failure', { reason: 'invalid_signature' }, 'CRITICAL');
      throw new UnauthorizedException({ code: 'INVALID_SIGNATURE', message: 'Invalid webhook signature' });
    }

    let payload: Record<string, unknown>;
    try {
      payload = JSON.parse(rawBody.toString('utf8')) as Record<string, unknown>;
    } catch {
      throw new BadRequestException({ code: 'INVALID_JSON', message: 'Webhook body must be JSON' });
    }

    const eventType = String(payload.event_type ?? payload.type ?? '');

    if (eventType.startsWith('payout.')) {
      return this.handlePayoutEvent(payload, eventType, String(payload.event_id ?? ''));
    }

    if (
      eventType === 'payment.captured' ||
      eventType === 'charge.captured' ||
      eventType === 'payment.succeeded'
    ) {
      return this.handlePaymentCaptured(payload, eventType, String(payload.event_id ?? ''));
    }

    if (eventType === 'payment.failed' || eventType === 'charge.failed') {
      return this.handlePaymentFailed(payload);
    }

    this.logger.warn({ eventType }, 'Ignored Quaser webhook event_type');
    return { ok: true, reason: 'ignored_event_type' };
  }

  private logPayloadTenantMismatch(
    kind: 'payment' | 'payout',
    id: string,
    tenantFromRow: string,
    payload: Record<string, unknown>,
  ) {
    const pt = payload.tenant_id != null ? String(payload.tenant_id) : '';
    if (pt && UUID_RE.test(pt) && pt !== tenantFromRow) {
      this.logger.warn(
        { kind, id, payloadTenant: pt, storedTenant: tenantFromRow },
        'Webhook tenant_id ignored (does not match stored row)',
      );
    }
  }

  private async handlePaymentCaptured(
    payload: Record<string, unknown>,
    eventType: string,
    eventId: string,
  ): Promise<QuaserWebhookAck> {
    const paymentId = String(payload.payment_id ?? '');
    if (!paymentId || !UUID_RE.test(paymentId)) {
      throw new BadRequestException({ code: 'INVALID_PAYMENT', message: 'payment_id missing or invalid' });
    }

    const amountFromRouter =
      payload.amount_minor != null
        ? String(payload.amount_minor)
        : payload.amount != null
          ? String(payload.amount)
          : null;

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const payRows = await client.query<{
        id: string;
        tenant_id: string;
        booking_id: string;
        currency: string;
        status: string;
        under_review: boolean;
        quaser_reference: string | null;
        metadata: Record<string, unknown>;
      }>(
        `SELECT id, tenant_id, booking_id, currency, status::text, under_review, quaser_reference, metadata
         FROM payments WHERE id = $1 FOR UPDATE`,
        [paymentId],
      );
      const pay = payRows.rows[0];
      if (!pay) {
        await client.query('ROLLBACK');
        client.release();
        return this.handleTicketPaymentCaptured(payload, eventType, eventId, paymentId, amountFromRouter);
      }

      const tenantId = pay.tenant_id;
      this.logPayloadTenantMismatch('payment', paymentId, tenantId, payload);

      if (pay.status === 'captured') {
        await this.confirmBookingAfterCapture(client, pay.booking_id, tenantId, paymentId);
        await client.query('COMMIT');
        return { ok: true, duplicate: true, reason: 'already_captured' };
      }
      if (pay.under_review) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'payment_under_review' };
      }

      const bk = await client.query<{
        total_minor: string;
        platform_fee_minor: string;
        status: string;
        client_user_id: string;
      }>(
        `SELECT total_minor::text, platform_fee_minor::text, status::text, client_user_id::text
         FROM bookings WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
        [pay.booking_id, tenantId],
      );
      const booking = bk.rows[0];
      if (!booking) {
        await client.query('ROLLBACK');
        throw new BadRequestException({ code: 'BOOKING_NOT_FOUND', message: 'Booking missing' });
      }

      const expectedTotal = booking.total_minor;
      const expectedFee = booking.platform_fee_minor;
      if (amountFromRouter != null && amountFromRouter !== expectedTotal) {
        await client.query('ROLLBACK');
        await this.alerts.trigger(
          'payment_mismatch',
          { paymentId, expectedTotal, amountFromRouter, tenantId },
          'CRITICAL',
        );
        this.logger.error(
          { paymentId, expectedTotal, amountFromRouter },
          'Rejecting webhook: amount mismatch vs booking snapshot',
        );
        return { ok: false, reason: 'amount_mismatch' };
      }

      const gross = BigInt(expectedTotal);
      const fee = BigInt(expectedFee);
      if (fee > gross) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'invalid_fee' };
      }

      const priorCaptures = await client.query<{ c: string }>(
        `SELECT COUNT(*)::text AS c
         FROM payments p
         INNER JOIN bookings b ON b.id = p.booking_id
         WHERE b.tenant_id = $1 AND b.client_user_id = $2::uuid
           AND p.status::text = 'captured'
           AND p.id <> $3::uuid`,
        [tenantId, booking.client_user_id, paymentId],
      );
      const priorCount = Number(priorCaptures.rows[0]?.c ?? '0');
      const firstTimePayerInTenant = priorCount === 0;

      const thresholdCfg = BigInt(this.config.get('PAYMENT_S2S_VERIFY_THRESHOLD_MINOR', { infer: true }));
      const routerOn =
        !!this.config.get('QUASER_ROUTER_BASE_URL', { infer: true }).trim() &&
        !!this.config.get('QUASER_ROUTER_API_KEY', { infer: true }).trim();

      const forceVerify =
        routerOn &&
        (thresholdCfg === 0n ||
          gross >= thresholdCfg ||
          firstTimePayerInTenant ||
          suspiciousFromPayload(payload) ||
          newDeviceFromPayload(payload));

      if (forceVerify && pay.quaser_reference) {
        const verify = await this.quaser.verifyPayment({
          tenantId,
          paymentId,
          quaserReference: pay.quaser_reference,
        });
        if (!verify.ok) {
          await client.query('ROLLBACK');
          this.logger.error({ paymentId, verify }, 'S2S verify failed');
          return { ok: false, reason: 's2s_verify_failed' };
        }
        if (verify.amountMinor != null && verify.amountMinor !== expectedTotal) {
          await client.query('ROLLBACK');
          return { ok: false, reason: 's2s_amount_mismatch' };
        }
      }

      const accounts = await this.ledger.ensurePoolLedgerAccounts(client, tenantId, pay.currency);

      const payloadJson = JSON.stringify(payload);
      const { rows: capRows } = await client.query<{ owanbe_apply_quaser_payment_capture: unknown }>(
        `SELECT owanbe_apply_quaser_payment_capture(
           $1::uuid, $2::uuid, 'quaser'::payment_provider,
           $3, $4, $5::jsonb,
           $6::uuid, $7::uuid, $8::uuid,
           $9::bigint, $10::bigint
         ) AS owanbe_apply_quaser_payment_capture`,
        [
          paymentId,
          tenantId,
          eventId || null,
          eventType,
          payloadJson,
          accounts.pspClearingId,
          accounts.escrowPoolId,
          accounts.platformFeesId,
          gross.toString(),
          fee.toString(),
        ],
      );

      const result = capRows[0]?.owanbe_apply_quaser_payment_capture as Record<string, unknown> | undefined;
      if (result?.error) {
        await client.query('ROLLBACK');
        this.logger.error({ result }, 'apply_quaser_payment_capture error');
        return { ok: false, reason: String(result.error) };
      }

      await this.confirmBookingAfterCapture(client, pay.booking_id, tenantId, paymentId);

      await client.query('COMMIT');
      return { ok: true, reason: result?.reason != null ? String(result.reason) : 'applied' };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  private async handleTicketPaymentCaptured(
    payload: Record<string, unknown>,
    eventType: string,
    eventId: string,
    paymentId: string,
    amountFromRouter: string | null,
  ): Promise<QuaserWebhookAck> {
    const ticketPay = await this.pool.query<{ id: string; status: string }>(
      `SELECT id, status::text FROM ticket_payments WHERE id = $1`,
      [paymentId],
    );
    if (!ticketPay.rows[0]) {
      throw new BadRequestException({ code: 'PAYMENT_NOT_FOUND', message: 'Payment not found' });
    }

    const result = await this.ticketCapture.applyCapture(paymentId, {
      eventId: eventId || undefined,
      eventType,
      payload,
      amountMinor: amountFromRouter ?? undefined,
    });
    return {
      ok: result.ok,
      duplicate: result.duplicate,
      reason: result.reason,
    };
  }

  /**
   * Only transition from pending_payment → confirmed; otherwise record reconciliation + metadata.
   */
  private async confirmBookingAfterCapture(
    client: PoolClient,
    bookingId: string,
    tenantId: string,
    paymentId: string,
  ): Promise<void> {
    const upd = await client.query<{ id: string }>(
      `UPDATE bookings
       SET status = 'confirmed', updated_at = now()
       WHERE id = $1 AND tenant_id = $2 AND status = 'pending_payment'
       RETURNING id`,
      [bookingId, tenantId],
    );
    if (upd.rowCount && upd.rows[0]) {
      return;
    }

    const cur = await client.query<{ status: string }>(
      `SELECT status::text FROM bookings WHERE id = $1 AND tenant_id = $2`,
      [bookingId, tenantId],
    );
    const status = cur.rows[0]?.status;
    if (status === 'confirmed') {
      return;
    }

    await this.reconciliation.recordInlineIssue(client, {
      tenantId,
      paymentId,
      bookingId,
      severity: 'critical',
      details: {
        reason: 'booking_not_pending_payment_on_capture',
        observed_booking_status: status ?? null,
        payment_id: paymentId,
      },
    });

    await client.query(
      `UPDATE payments
       SET metadata = metadata || $2::jsonb
       WHERE id = $1`,
      [
        paymentId,
        JSON.stringify({
          booking_confirm_inconsistency: {
            at: new Date().toISOString(),
            observed_booking_status: status ?? null,
          },
        }),
      ],
    );
    this.logger.error(
      { paymentId, bookingId, observed_booking_status: status },
      'Booking confirmation skipped: booking was not pending_payment',
    );
  }

  private async handlePaymentFailed(payload: Record<string, unknown>): Promise<QuaserWebhookAck> {
    const paymentId = String(payload.payment_id ?? '');
    if (!paymentId || !UUID_RE.test(paymentId)) {
      throw new BadRequestException({ code: 'INVALID_PAYMENT', message: 'payment_id missing or invalid' });
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const pr = await client.query<{ tenant_id: string }>(
        `SELECT tenant_id FROM payments WHERE id = $1 FOR UPDATE`,
        [paymentId],
      );
      const row = pr.rows[0];
      if (!row) {
        await client.query('ROLLBACK');
        throw new BadRequestException({ code: 'PAYMENT_NOT_FOUND', message: 'Payment not found' });
      }
      const tenantId = row.tenant_id;
      this.logPayloadTenantMismatch('payment', paymentId, tenantId, payload);

      await client.query(
        `UPDATE payments
         SET status = 'failed',
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE id = $1 AND tenant_id = $2
           AND status::text IN ('initiated','requires_action','authorized')`,
        [
          paymentId,
          tenantId,
          JSON.stringify({ failure: payload.failure ?? payload, failed_at: new Date().toISOString() }),
        ],
      );
      await client.query('COMMIT');
      return { ok: true, reason: 'marked_failed' };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  private async handlePayoutEvent(
    payload: Record<string, unknown>,
    eventType: string,
    eventId: string,
  ): Promise<QuaserWebhookAck> {
    if (eventType !== 'payout.completed' && eventType !== 'payout.succeeded') {
      return { ok: true, reason: 'ignored_payout_event' };
    }
    const payoutId = String(payload.payout_id ?? '');
    if (!payoutId || !UUID_RE.test(payoutId)) {
      throw new BadRequestException({ code: 'INVALID_PAYOUT', message: 'payout_id missing or invalid' });
    }

    const vendorExists = await this.pool.query<{ id: string }>(
      `SELECT id FROM payouts WHERE id = $1`,
      [payoutId],
    );
    if (!vendorExists.rows[0]) {
      const orgExists = await this.pool.query<{ id: string }>(
        `SELECT id FROM organizer_payouts WHERE id = $1`,
        [payoutId],
      );
      if (orgExists.rows[0]) {
        const result = await this.organizerPayout.completePayout(payoutId, {
          webhook_event_id: eventId,
        });
        return { ok: result.ok, reason: result.reason ?? 'organizer_payout_completed' };
      }
      throw new BadRequestException({ code: 'NOT_FOUND', message: 'Payout not found' });
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const pr = await client.query<{
        id: string;
        tenant_id: string;
        status: string;
        under_review: boolean;
        booking_id: string;
        payment_id: string;
        vendor_id: string;
        currency: string;
        amount_minor: string;
        quaser_reference: string | null;
      }>(
        `SELECT id, tenant_id, status::text, under_review, booking_id, payment_id, vendor_id, currency, amount_minor::text, quaser_reference
         FROM payouts WHERE id = $1 FOR UPDATE`,
        [payoutId],
      );
      const p = pr.rows[0];
      if (!p) {
        await client.query('ROLLBACK');
        throw new BadRequestException({ code: 'NOT_FOUND', message: 'Payout not found' });
      }

      const tenantId = p.tenant_id;
      this.logPayloadTenantMismatch('payout', payoutId, tenantId, payload);

      if (p.status === 'completed') {
        await client.query('COMMIT');
        return { ok: true, duplicate: true };
      }
      if (p.status !== 'processing' && p.status !== 'pending') {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'payout_bad_state' };
      }
      if (p.under_review) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'payout_under_review' };
      }

      const payCheck = await client.query<{ status: string }>(
        `SELECT status::text FROM payments WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
        [p.payment_id, tenantId],
      );
      if (payCheck.rows[0]?.status !== 'captured') {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'payment_not_captured' };
      }

      let journal: Awaited<ReturnType<FinancialTreasuryOrchestrationService['postSettlementJournal']>>;
      try {
        journal = await this.treasury.postSettlementJournal({
          client,
          tenantId,
          payoutId: p.id,
          bookingId: p.booking_id,
          paymentId: p.payment_id,
          vendorId: p.vendor_id,
          currency: p.currency,
          amountMinor: BigInt(p.amount_minor),
          settlementReference: treasurySettlementReference(p.id),
          webhookEventId: eventId || null,
        });
      } catch (e) {
        if (isTreasuryDualWriteMismatch(e)) {
          await client.query('COMMIT');
          return { ok: false, reason: 'qfe_treasury_dual_write_mismatch' };
        }
        throw e;
      }

      if (journal.skipped && journal.reason === 'already_posted' && !journal.ledgerTransactionId) {
        await client.query('ROLLBACK');
        return { ok: true, duplicate: true, reason: 'treasury_already_posted' };
      }

      const ledgerTxnId = journal.ledgerTransactionId;
      if (!ledgerTxnId) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'treasury_journal_missing' };
      }

      await client.query(
        `UPDATE payouts
         SET status = 'completed',
             ledger_transaction_id = COALESCE(ledger_transaction_id, $2),
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [
          p.id,
          ledgerTxnId,
          JSON.stringify({
            webhook_event_id: eventId || null,
            completed_at: new Date().toISOString(),
            treasury_settlement_reference: journal.settlementReference,
            financial_transaction_id: journal.financialTransactionId ?? null,
            qfe_dual_write: journal.dualWriteEnabled,
          }),
        ],
      );

      await client.query('COMMIT');
      return { ok: true, reason: 'payout_completed' };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
