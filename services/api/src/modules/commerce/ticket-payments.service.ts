import {
  ConflictException,
  Injectable,
  Inject,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { randomUUID } from 'crypto';
import { PG_POOL } from '../../database/database.tokens';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { QuaserRouterService } from '../payments/quaser-router.service';
import { FinanceStateService } from '../payments/finance-state.service';
import { TicketCaptureService } from './ticket-capture.service';

export interface CreateTicketPaymentResult {
  payment: {
    id: string;
    ticketOrderId: string;
    status: string;
    currency: string;
    amountExpectedMinor: string;
    quaserReference: string | null;
  };
  quaser: { clientActionUrl?: string };
  capture?: { ok: boolean; reason?: string };
  entitlements?: Array<{
    id: string;
    ticketCode: string;
    qrPayload: string;
    tierName: string;
  }>;
}

@Injectable()
export class TicketPaymentsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly quaser: QuaserRouterService,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly financeState: FinanceStateService,
    private readonly capture: TicketCaptureService,
  ) {}

  private publicWebhookUrl() {
    const base = this.config.get('PUBLIC_API_BASE_URL', { infer: true }).trim();
    return base ? `${base.replace(/\/$/, '')}/webhooks/quaser` : '';
  }

  private isQuaserStub() {
    return !this.config.get('QUASER_ROUTER_BASE_URL', { infer: true }).trim();
  }

  async createPayment(
    tenantId: string,
    ticketOrderId: string,
    idempotencyHeader?: string,
  ): Promise<CreateTicketPaymentResult> {
    await this.financeState.ensurePaymentsAllowed();

    const idem =
      idempotencyHeader && idempotencyHeader.trim().length >= 8 && idempotencyHeader.length <= 128
        ? idempotencyHeader.trim()
        : `tpay_${ticketOrderId}_${randomUUID()}`;

    const client = await this.pool.connect();
    let paymentId: string;
    let currency: string;
    let totalMinor: string;
    try {
      await client.query('BEGIN');

      const existing = await client.query<{
        id: string;
        ticket_order_id: string;
        status: string;
        currency: string;
        quaser_reference: string | null;
      }>(
        `SELECT id, ticket_order_id, status::text, currency, quaser_reference
         FROM ticket_payments WHERE tenant_id = $1 AND idempotency_key = $2`,
        [tenantId, idem],
      );
      if (existing.rows[0]) {
        await client.query('COMMIT');
        return this.buildResult(existing.rows[0].id, tenantId);
      }

      const ord = await client.query<{
        id: string;
        status: string;
        currency: string;
        total_minor: string;
      }>(
        `SELECT id, status::text, currency, total_minor::text
         FROM ticket_orders WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
        [ticketOrderId, tenantId],
      );
      const order = ord.rows[0];
      if (!order) {
        throw new UnprocessableEntityException({ code: 'ORDER_NOT_FOUND', message: 'Ticket order not found' });
      }
      if (order.status !== 'pending_payment') {
        throw new UnprocessableEntityException({
          code: 'ORDER_NOT_PAYABLE',
          message: `Order must be pending_payment (got ${order.status})`,
        });
      }

      const ins = await client.query<{ id: string }>(
        `INSERT INTO ticket_payments (
           tenant_id, ticket_order_id, provider, status, currency,
           amount_captured_minor, idempotency_key, metadata
         ) VALUES ($1, $2, 'quaser', 'initiated', $3, 0, $4, $5::jsonb)
         RETURNING id`,
        [
          tenantId,
          ticketOrderId,
          order.currency,
          idem,
          JSON.stringify({ expected_total_minor: order.total_minor }),
        ],
      );
      paymentId = ins.rows[0]!.id;
      currency = order.currency;
      totalMinor = order.total_minor;

      const webhookUrl = this.publicWebhookUrl();
      if (!webhookUrl && !this.isQuaserStub()) {
        throw new UnprocessableEntityException({
          code: 'WEBHOOK_BASE_URL_MISSING',
          message: 'Set PUBLIC_API_BASE_URL for Quaser webhooks',
        });
      }

      const init = await this.quaser.initiatePayment({
        tenantId,
        paymentId,
        bookingId: ticketOrderId,
        amountMinor: totalMinor,
        currency,
        idempotencyKey: idem,
        webhookUrl: webhookUrl || 'http://localhost/dev-stub',
      });

      await client.query(
        `UPDATE ticket_payments
         SET quaser_reference = $2,
             provider_intent_ref = COALESCE(provider_intent_ref, $2),
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [
          paymentId,
          init.quaserReference,
          JSON.stringify({ quaser_init: init.raw, initiated_at: new Date().toISOString() }),
        ],
      );

      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }

    return this.buildResult(paymentId, tenantId, true);
  }

  private async buildResult(
    paymentId: string,
    tenantId: string,
    autoCaptureIfStub = false,
  ): Promise<CreateTicketPaymentResult> {
    const row = await this.pool.query<{
      id: string;
      ticket_order_id: string;
      status: string;
      currency: string;
      quaser_reference: string | null;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, ticket_order_id, status::text, currency, quaser_reference, metadata
       FROM ticket_payments WHERE id = $1 AND tenant_id = $2`,
      [paymentId, tenantId],
    );
    const p = row.rows[0];
    if (!p) {
      throw new ConflictException({ code: 'PAYMENT_NOT_FOUND', message: 'Payment missing' });
    }
    const expected = String((p.metadata ?? {}).expected_total_minor ?? '0');

    let captureResult: CreateTicketPaymentResult['capture'];
    let entitlements: CreateTicketPaymentResult['entitlements'];

    if (autoCaptureIfStub && this.isQuaserStub() && p.status !== 'captured') {
      const cap = await this.capture.applyCapture(paymentId, {
        eventType: 'payment.captured',
        amountMinor: expected,
        payload: { stub_auto_capture: true, payment_id: paymentId, ticket_payment: true },
      });
      captureResult = { ok: cap.ok, reason: cap.reason };
      entitlements = await this.loadEntitlements(tenantId, p.ticket_order_id);
    } else if (p.status === 'captured') {
      entitlements = await this.loadEntitlements(tenantId, p.ticket_order_id);
    }

    return {
      payment: {
        id: p.id,
        ticketOrderId: p.ticket_order_id,
        status: p.status,
        currency: p.currency,
        amountExpectedMinor: expected,
        quaserReference: p.quaser_reference,
      },
      quaser: {},
      capture: captureResult,
      entitlements,
    };
  }

  private async loadEntitlements(tenantId: string, orderId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      ticket_code: string;
      metadata: { qr_payload?: string; tier_name?: string };
    }>(
      `SELECT id, ticket_code, metadata FROM ticket_entitlements
       WHERE tenant_id = $1 AND ticket_order_id = $2`,
      [tenantId, orderId],
    );
    return rows.map((r) => ({
      id: r.id,
      ticketCode: r.ticket_code,
      qrPayload: r.metadata?.qr_payload ?? r.ticket_code,
      tierName: r.metadata?.tier_name ?? 'Ticket',
    }));
  }
}
