import { createHash } from 'crypto';
import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  UnauthorizedException,
  forwardRef,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { TicketCaptureService } from '../commerce/ticket-capture.service';
import { OrganizerPayoutService } from '../commerce/organizer-payout.service';
import { verifyQuaserWebhookSignature } from '../payments/quaser-signature.util';
import { QuasarAuditService } from './quasar-audit.service';
import { QuasarVaultService } from './quasar-vault.service';
import { payoutStateFromConfirmedQuasarStatus, ticketStateAfterFunding } from './quasar-state';
import {
  actionForQuasarEvent,
  isUuid,
  minorUnitsFromQuasarAmount,
  payerIdFromFundedData,
  redactQuasarSecrets,
  ticketPaymentIdFromFundedData,
  transferReferenceFromData,
} from './quasar.policy';

export interface QuasarWebhookAck {
  ok: boolean;
  duplicate?: boolean;
  reason?: string;
}

@Injectable()
export class QuasarWebhookService {
  private readonly logger = new Logger(QuasarWebhookService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly vault: QuasarVaultService,
    @Inject(forwardRef(() => TicketCaptureService))
    private readonly ticketCapture: TicketCaptureService,
    @Inject(forwardRef(() => OrganizerPayoutService))
    private readonly organizerPayout: OrganizerPayoutService,
    private readonly audit: QuasarAuditService,
  ) {}

  async handleSignedWebhook(
    quasarTenantId: string,
    rawBody: Buffer,
    signatureHeader: string | undefined,
  ): Promise<QuasarWebhookAck> {
    if (!isUuid(quasarTenantId)) {
      throw new BadRequestException({ code: 'INVALID_TENANT', message: 'Quasar tenant id is invalid' });
    }
    const located = await this.vault.signingSecretFor(quasarTenantId);
    if (!located) {
      throw new UnauthorizedException({
        code: 'WEBHOOK_NOT_CONFIGURED',
        message: 'Quasar webhook signing secret is not configured',
      });
    }
    if (!verifyQuaserWebhookSignature(located.secret, rawBody, signatureHeader)) {
      await this.audit.record({
        owanbeTenantId: located.merchant.owanbeTenantId,
        action: 'webhook.rejected',
        outcome: 'invalid_signature',
        reference: quasarTenantId,
      });
      throw new UnauthorizedException({ code: 'INVALID_SIGNATURE', message: 'Invalid webhook signature' });
    }

    let payload: Record<string, unknown>;
    try {
      payload = JSON.parse(rawBody.toString('utf8')) as Record<string, unknown>;
    } catch {
      throw new BadRequestException({ code: 'INVALID_JSON', message: 'Webhook body must be JSON' });
    }

    const event = String(payload.event ?? '');
    const data =
      payload.data && typeof payload.data === 'object' && !Array.isArray(payload.data)
        ? (payload.data as Record<string, unknown>)
        : {};
    const eventKey = createHash('sha256').update(rawBody).digest('hex');
    const inserted = await this.pool.query<{ id: string }>(
      `INSERT INTO quasar_webhook_deliveries (merchant_account_id, event_name, event_key, payload)
       VALUES ($1, $2, $3, $4::jsonb)
       ON CONFLICT (merchant_account_id, event_key) DO NOTHING
       RETURNING id`,
      [located.merchant.id, event, eventKey, JSON.stringify(redactQuasarSecrets(payload))],
    );
    if (!inserted.rows[0]) {
      await this.audit.record({
        owanbeTenantId: located.merchant.owanbeTenantId,
        action: 'webhook.duplicate',
        outcome: 'ignored',
        reference: event || quasarTenantId,
      });
      return { ok: true, duplicate: true, reason: 'duplicate_delivery' };
    }

    try {
      const ack = await this.applyEvent(located.merchant.id, event, data);
      await this.pool.query(`UPDATE quasar_webhook_deliveries SET result = $2 WHERE id = $1`, [
        inserted.rows[0].id,
        ack.reason ?? 'ok',
      ]);
      return ack;
    } catch (error) {
      await this.pool.query(`DELETE FROM quasar_webhook_deliveries WHERE id = $1`, [inserted.rows[0].id]);
      throw error;
    }
  }

  private async applyEvent(
    merchantAccountId: string,
    event: string,
    data: Record<string, unknown>,
  ): Promise<QuasarWebhookAck> {
    const action = actionForQuasarEvent(event);
    if (action === 'capture_ticket') return this.captureTicket(data);
    if (action === 'complete_payout') return this.completePayout(merchantAccountId, data);
    if (action === 'fail_payout') return this.failPayout(merchantAccountId, data);
    this.logger.warn({ event }, 'Ignored Quasar webhook event');
    return { ok: true, reason: 'ignored_event' };
  }

  private async captureTicket(data: Record<string, unknown>): Promise<QuasarWebhookAck> {
    const fundedMinor = minorUnitsFromQuasarAmount(data);
    if (!fundedMinor) return { ok: true, reason: 'amount_missing' };

    const hinted = ticketPaymentIdFromFundedData(data);
    const accountNumber = typeof data.accountNumber === 'string' ? data.accountNumber : null;
    const paymentId = await this.resolveTicketPayment(
      hinted,
      payerIdFromFundedData(data),
      fundedMinor,
      accountNumber,
    );
    if (!paymentId) return { ok: true, reason: 'ticket_not_matched' };
    if (ticketStateAfterFunding(true) !== 'paid') return { ok: true, reason: 'not_payable' };

    const captured = await this.ticketCapture.applyCapture(paymentId, {
      eventType: 'virtual_account.funded',
      amountMinor: fundedMinor,
      payload: { source: 'quasar', event: 'virtual_account.funded' },
    });
    return { ok: captured.ok, reason: captured.reason ?? 'captured' };
  }

  private async resolveTicketPayment(
    hintedId: string | null,
    payerId: string | null,
    fundedMinor: string,
    accountNumber: string | null,
  ): Promise<string | null> {
    if (!payerId && !hintedId && !accountNumber) return null;
    const matched = await this.pool.query<{ id: string }>(
      `SELECT tp.id
       FROM ticket_payments tp
       JOIN ticket_orders tord ON tord.id = tp.ticket_order_id
       WHERE tp.status::text = 'initiated'
         AND COALESCE(tp.metadata->>'expected_total_minor', '') = $1
         AND (
           ($2::uuid IS NOT NULL AND tp.id = $2::uuid)
           OR (
             $4::text IS NOT NULL
             AND tp.id = (
               SELECT qva.ticket_payment_id
               FROM quasar_virtual_accounts qva
               WHERE qva.account_number = $4
                 AND qva.ticket_payment_id IS NOT NULL
               ORDER BY qva.created_at DESC
               LIMIT 1
             )
           )
           OR (
             $2::uuid IS NULL
             AND $4::text IS NULL
             AND $3::uuid IS NOT NULL
             AND tord.buyer_user_id = $3::uuid
           )
         )
       ORDER BY tp.created_at DESC
       LIMIT 1`,
      [fundedMinor, hintedId, payerId, accountNumber],
    );
    return matched.rows[0]?.id ?? null;
  }

  private async completePayout(merchantAccountId: string, data: Record<string, unknown>): Promise<QuasarWebhookAck> {
    if (payoutStateFromConfirmedQuasarStatus('SUCCESS') !== 'paid') {
      return { ok: true, reason: 'not_confirmed' };
    }
    const payoutId = await this.payoutIdForReference(merchantAccountId, data, 'SUCCESS');
    if (!payoutId) return { ok: true, reason: 'transfer_not_matched' };
    const result = await this.organizerPayout.completePayout(payoutId, {
      source: 'quasar',
      event: 'transfer.success',
    });
    return { ok: result.ok, reason: result.reason ?? 'payout_completed' };
  }

  private async failPayout(merchantAccountId: string, data: Record<string, unknown>): Promise<QuasarWebhookAck> {
    const remoteStatus = (typeof data.status === 'string' ? data.status : 'FAILED').toUpperCase();
    const storedStatus = remoteStatus === 'REJECTED' ? 'REJECTED' : 'FAILED';
    const payoutId = await this.payoutIdForReference(merchantAccountId, data, storedStatus);
    if (!payoutId) return { ok: true, reason: 'transfer_not_matched' };
    const next = payoutStateFromConfirmedQuasarStatus(remoteStatus === 'REJECTED' ? 'REJECTED' : 'FAILED');
    if (next === 'paid') return { ok: false, reason: 'refused_paid_on_failure' };
    const result = await this.organizerPayout.markTransferFailed(
      payoutId,
      { source: 'quasar', event: 'transfer.failed', quasarStatus: remoteStatus },
      next === 'rejected' ? 'QUASAR_TRANSFER_REJECTED' : 'QUASAR_TRANSFER_FAILED',
    );
    return { ok: result.ok, reason: result.reason ?? 'payout_failed' };
  }

  private async payoutIdForReference(
    merchantAccountId: string,
    data: Record<string, unknown>,
    status: string,
  ): Promise<string | null> {
    const reference = transferReferenceFromData(data);
    if (!reference) return null;
    const { rows } = await this.pool.query<{ organizer_payout_id: string | null }>(
      `UPDATE quasar_transfers
       SET quasar_status = $3, updated_at = now()
       WHERE merchant_account_id = $1 AND reference = $2
       RETURNING organizer_payout_id`,
      [merchantAccountId, reference, status],
    );
    return rows[0]?.organizer_payout_id ?? null;
  }
}
