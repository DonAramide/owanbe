import { Injectable, Inject, Logger } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { QuaserRouterService } from './quaser-router.service';
import { randomUUID } from 'crypto';
import { AlertsService } from './alerts.service';
import { FinanceStateService } from './finance-state.service';

export interface EligiblePayoutRow {
  booking_id: string;
  tenant_id: string;
  vendor_id: string;
  payment_id: string;
  currency: string;
  subtotal_minor: string;
}

@Injectable()
export class PayoutService {
  private readonly logger = new Logger(PayoutService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly quaser: QuaserRouterService,
    private readonly alerts: AlertsService,
    private readonly financeState: FinanceStateService,
  ) {}

  private publicWebhookUrl() {
    const base = this.config.get('PUBLIC_API_BASE_URL', { infer: true }).trim();
    if (!base) return '';
    return `${base.replace(/\/$/, '')}/webhooks/quaser`;
  }

  private cooldownHoursSqlParam() {
    return this.config.get('PAYOUT_COOLDOWN_FALLBACK_HOURS', { infer: true });
  }

  async listPaymentsForTenant(tenantId: string, limit = 100) {
    const { rows } = await this.pool.query(
      `SELECT id, booking_id, status::text, currency, amount_captured_minor::text, idempotency_key,
              quaser_reference, created_at
       FROM payments WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [tenantId, limit],
    );
    return { items: rows };
  }

  async listPayoutsForTenant(tenantId: string, limit = 100) {
    const { rows } = await this.pool.query(
      `SELECT id, booking_id, vendor_id, payment_id, status::text, currency, amount_minor::text,
              quaser_reference, failure_code, created_at
       FROM payouts WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [tenantId, limit],
    );
    return { items: rows };
  }

  async findEligiblePayouts(tenantId: string, limit: number): Promise<EligiblePayoutRow[]> {
    const fb = this.cooldownHoursSqlParam();
    const { rows } = await this.pool.query<EligiblePayoutRow>(
      `SELECT b.id AS booking_id, b.tenant_id, b.vendor_id, p.id AS payment_id, b.currency,
              b.subtotal_minor::text AS subtotal_minor
       FROM bookings b
       INNER JOIN payments p ON p.booking_id = b.id AND p.tenant_id = b.tenant_id AND p.status::text = 'captured'
         AND p.under_review = FALSE
       LEFT JOIN tenant_finance_settings tfs ON tfs.tenant_id = b.tenant_id
       WHERE b.tenant_id = $3
         AND b.status::text = 'completed'
         AND COALESCE((b.metadata->>'payout_hold')::boolean, FALSE) = FALSE
         AND NOT EXISTS (
           SELECT 1 FROM disputes d
           WHERE d.booking_id = b.id
             AND d.status::text IN ('open', 'under_review', 'awaiting_evidence')
         )
         AND NOT EXISTS (
           SELECT 1 FROM payouts po
           WHERE po.booking_id = b.id
            AND po.status::text IN ('pending', 'processing', 'completed')
            AND po.under_review = FALSE
         )
         AND (
           (b.escrow_release_not_before IS NOT NULL AND b.escrow_release_not_before <= now())
           OR (
             b.escrow_release_not_before IS NULL
             AND COALESCE(b.completed_at, b.updated_at) + make_interval(
               hours => COALESCE(tfs.escrow_release_delay_hours, $2)
             ) <= now()
           )
         )
       ORDER BY b.updated_at ASC
       LIMIT $1`,
      [limit, fb, tenantId],
    );
    return rows;
  }

  /**
   * Creates payout row (pending), calls Quaser transfer, moves to processing.
   */
  async enqueuePayoutForBooking(
    row: EligiblePayoutRow,
    opts?: { adminOverride?: boolean },
  ): Promise<{ payoutId: string } | { skipped: true }> {
    await this.financeState.ensurePayoutsAllowed({ adminOverride: opts?.adminOverride });
    const webhookUrl = this.publicWebhookUrl();
    if (!webhookUrl) {
      this.logger.warn('PUBLIC_API_BASE_URL missing; skip payout enqueue');
      return { skipped: true };
    }

    const idempotencyKey = `payout:${row.booking_id}:${row.payment_id}:${randomUUID()}`;
    let payoutId: string;
    try {
      const ins = await this.pool.query<{ id: string }>(
        `INSERT INTO payouts (
           tenant_id, booking_id, vendor_id, payment_id, currency, amount_minor, idempotency_key, status, metadata
         ) VALUES ($1, $2, $3, $4, $5, $6::bigint, $7, 'pending', $8::jsonb)
         RETURNING id`,
        [
          row.tenant_id,
          row.booking_id,
          row.vendor_id,
          row.payment_id,
          row.currency.toUpperCase(),
          row.subtotal_minor,
          idempotencyKey,
          JSON.stringify({ source: 'automated_enqueue' }),
        ],
      );
      const id = ins.rows[0]?.id;
      if (!id) {
        return { skipped: true };
      }
      payoutId = id;
    } catch (e: unknown) {
      const err = e as { code?: string; message?: string };
      if (err.code === '23505') {
        return { skipped: true };
      }
      if (typeof err.message === 'string' && err.message.includes('PAYOUT_BLOCKED_OPEN_DISPUTE')) {
        this.logger.warn({ bookingId: row.booking_id }, 'Payout insert blocked by open dispute (DB trigger)');
        return { skipped: true };
      }
      throw e;
    }

    try {
      const init = await this.quaser.initiatePayoutTransfer({
        tenantId: row.tenant_id,
        payoutId,
        amountMinor: row.subtotal_minor,
        currency: row.currency,
        vendorId: row.vendor_id,
        idempotencyKey,
        webhookUrl,
      });
      await this.pool.query(
        `UPDATE payouts
         SET status = 'processing',
             quaser_reference = $2,
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [payoutId, init.quaserReference, JSON.stringify({ quaser: init.raw })],
      );
      return { payoutId };
    } catch (e) {
      await this.pool.query(
        `UPDATE payouts
         SET status = 'failed',
             under_review = TRUE,
             failure_code = 'QUASER_INIT',
             failure_message = $2,
             updated_at = now()
         WHERE id = $1`,
        [payoutId, String((e as Error).message).slice(0, 500)],
      );
      await this.alerts.trigger(
        'payout_failure',
        { payoutId, error: String((e as Error).message).slice(0, 500) },
        'CRITICAL',
      );
      throw e;
    }
  }

  async processPayoutBatch(
    tenantId: string,
    limit = 20,
    opts?: { adminOverride?: boolean },
  ): Promise<{ processed: number; results: Array<{ bookingId: string }> }> {
    await this.financeState.ensurePayoutsAllowed({ adminOverride: opts?.adminOverride });
    const eligible = await this.findEligiblePayouts(tenantId, limit);
    const results: Array<{ bookingId: string }> = [];
    for (const row of eligible) {
      try {
        const r = await this.enqueuePayoutForBooking(row, opts);
        if ('payoutId' in r) {
          results.push({ bookingId: row.booking_id });
        }
      } catch (e) {
        this.logger.error({ err: e, bookingId: row.booking_id }, 'payout enqueue failed');
      }
    }
    return { processed: results.length, results };
  }

  async retryFailedPayout(
    tenantId: string,
    payoutId: string,
    opts?: { adminOverride?: boolean },
  ): Promise<{ ok: boolean }> {
    await this.financeState.ensurePayoutsAllowed({ adminOverride: opts?.adminOverride });
    const webhookUrl = this.publicWebhookUrl();
    if (!webhookUrl) {
      return { ok: false };
    }
    const { rows } = await this.pool.query<{
      id: string;
      vendor_id: string;
      payment_id: string;
      currency: string;
      amount_minor: string;
    }>(
      `SELECT id, vendor_id, payment_id, currency, amount_minor::text
       FROM payouts
       WHERE id = $1 AND tenant_id = $2 AND status::text = 'failed' AND under_review = FALSE`,
      [payoutId, tenantId],
    );
    const p = rows[0];
    if (!p) {
      return { ok: false };
    }
    const newHeaderKey = `retry-${payoutId}-${Date.now()}`;
    try {
      const init = await this.quaser.initiatePayoutTransfer({
        tenantId,
        payoutId: p.id,
        amountMinor: p.amount_minor,
        currency: p.currency,
        vendorId: p.vendor_id,
        idempotencyKey: newHeaderKey,
        webhookUrl,
      });
      await this.pool.query(
        `UPDATE payouts
         SET status = 'processing',
             quaser_reference = $2,
             failure_code = NULL,
             failure_message = NULL,
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [p.id, init.quaserReference, JSON.stringify({ retry: true, quaser: init.raw })],
      );
      return { ok: true };
    } catch (e: unknown) {
      const err = e as { message?: string };
      if (typeof err.message === 'string' && err.message.includes('PAYOUT_BLOCKED_OPEN_DISPUTE')) {
        this.logger.warn({ payoutId }, 'Payout retry blocked by open dispute');
        return { ok: false };
      }
      throw e;
    }
  }
}
