import {
  ConflictException,
  Injectable,
  Inject,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { withActor } from '../../database/with-actor';
import { BookingAccessService } from '../../ownership/booking-access.service';
import { QuaserRouterService } from './quaser-router.service';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { randomUUID } from 'crypto';
import { FinanceStateService } from './finance-state.service';

export interface CreatePaymentResult {
  payment: {
    id: string;
    bookingId: string;
    status: string;
    currency: string;
    amountExpectedMinor: string;
    idempotencyKey: string;
    quaserReference: string | null;
  };
  quaser: {
    clientActionUrl?: string;
  };
}

@Injectable()
export class PaymentsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly bookings: BookingAccessService,
    private readonly quaser: QuaserRouterService,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly financeState: FinanceStateService,
  ) {}

  private publicWebhookUrl() {
    const base = this.config.get('PUBLIC_API_BASE_URL', { infer: true }).trim();
    if (!base) {
      return '';
    }
    return `${base.replace(/\/$/, '')}/webhooks/quaser`;
  }

  async createPaymentForBooking(
    tenantId: string,
    bookingId: string,
    clientUserId: string,
    idempotencyHeader: string | undefined,
  ): Promise<CreatePaymentResult> {
    await this.financeState.ensurePaymentsAllowed();
    await this.bookings.assertClientOwnsBooking(tenantId, bookingId, clientUserId);

    const idem =
      idempotencyHeader && idempotencyHeader.trim().length >= 8 && idempotencyHeader.length <= 128
        ? idempotencyHeader.trim()
        : `owb_pay_${bookingId}_${randomUUID()}`;

    return withActor(this.pool, clientUserId, async (c) => {
      const existing = await c.query<{
        id: string;
        booking_id: string;
        status: string;
        currency: string;
        quaser_reference: string | null;
        metadata: unknown;
      }>(
        `SELECT id, booking_id, status::text, currency, quaser_reference, metadata
         FROM payments
         WHERE tenant_id = $1 AND idempotency_key = $2`,
        [tenantId, idem],
      );
      if (existing.rows[0]) {
        const p = existing.rows[0];
        const meta = (p.metadata ?? {}) as { expected_total_minor?: string };
        return {
          payment: {
            id: p.id,
            bookingId: p.booking_id,
            status: p.status,
            currency: p.currency,
            amountExpectedMinor: meta.expected_total_minor ?? '0',
            idempotencyKey: idem,
            quaserReference: p.quaser_reference,
          },
          quaser: {},
        };
      }

      const review = await c.query<{ id: string }>(
        `SELECT id FROM payments
         WHERE tenant_id = $1 AND booking_id = $2 AND under_review = TRUE
         ORDER BY created_at DESC
         LIMIT 1`,
        [tenantId, bookingId],
      );
      if (review.rows[0]) {
        throw new UnprocessableEntityException({
          code: 'PAYMENT_UNDER_REVIEW',
          message: 'Payment operations blocked for this booking pending review',
        });
      }

      const bk = await c.query<{
        id: string;
        status: string;
        currency: string;
        total_minor: string;
        platform_fee_minor: string;
        version: number;
      }>(
        `SELECT id, status::text, currency, total_minor::text, platform_fee_minor::text, version
         FROM bookings WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
        [bookingId, tenantId],
      );
      const b = bk.rows[0];
      if (!b) {
        throw new UnprocessableEntityException({ code: 'NOT_FOUND', message: 'Booking not found' });
      }
      if (b.status !== 'pending_payment') {
        throw new UnprocessableEntityException({
          code: 'BOOKING_NOT_PAYABLE',
          message: `Booking must be pending_payment to pay (got ${b.status})`,
        });
      }

      const meta = {
        booking_total_minor: b.total_minor,
        booking_platform_fee_minor: b.platform_fee_minor,
        booking_version: b.version,
      };

      const ins = await c.query<{
        id: string;
        booking_id: string;
        status: string;
        currency: string;
      }>(
        `INSERT INTO payments (
           tenant_id, booking_id, provider, status, currency,
           amount_captured_minor, idempotency_key, metadata
         ) VALUES ($1, $2, 'quaser', 'initiated', $3, 0, $4, $5::jsonb)
         RETURNING id, booking_id, status::text, currency`,
        [tenantId, bookingId, b.currency, idem, JSON.stringify({ ...meta, expected_total_minor: b.total_minor })],
      );
      const row = ins.rows[0];
      if (!row) {
        throw new ConflictException({ code: 'PAYMENT_CREATE_FAILED', message: 'Insert failed' });
      }

      const webhookUrl = this.publicWebhookUrl();
      if (!webhookUrl) {
        throw new UnprocessableEntityException({
          code: 'WEBHOOK_BASE_URL_MISSING',
          message: 'Set PUBLIC_API_BASE_URL so Quaser can deliver webhooks',
        });
      }

      const init = await this.quaser.initiatePayment({
        tenantId,
        paymentId: row.id,
        bookingId,
        amountMinor: b.total_minor,
        currency: b.currency,
        idempotencyKey: idem,
        webhookUrl,
      });

      await c.query(
        `UPDATE payments
         SET quaser_reference = $2,
             provider_intent_ref = COALESCE(provider_intent_ref, $2),
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [
          row.id,
          init.quaserReference,
          JSON.stringify({ quaser_init: init.raw, initiated_at: new Date().toISOString() }),
        ],
      );

      return {
        payment: {
          id: row.id,
          bookingId: row.booking_id,
          status: row.status,
          currency: row.currency,
          amountExpectedMinor: b.total_minor,
          idempotencyKey: idem,
          quaserReference: init.quaserReference,
        },
        quaser: { clientActionUrl: init.clientActionUrl },
      };
    });
  }
}
