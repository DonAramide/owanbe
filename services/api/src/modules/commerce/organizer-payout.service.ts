import {
  Injectable,
  Inject,
  Logger,
  ForbiddenException,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { randomUUID } from 'crypto';
import { PG_POOL } from '../../database/database.tokens';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { QuaserRouterService } from '../payments/quaser-router.service';
import { LedgerService } from '../payments/ledger.service';
import { FinanceStateService } from '../payments/finance-state.service';
import { AlertsService } from '../payments/alerts.service';
import type { CommerceActor } from './commerce-auth.service';
import { OrganizerFinanceService } from './organizer-finance.service';
import { IntegrationsModeService } from '../../integrations/integrations-mode.service';

export interface EligibleOrganizerPayoutRow {
  ticket_order_id: string;
  tenant_id: string;
  organizer_id: string;
  currency: string;
  subtotal_minor: string;
}

@Injectable()
export class OrganizerPayoutService {
  private readonly logger = new Logger(OrganizerPayoutService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly quaser: QuaserRouterService,
    private readonly ledger: LedgerService,
    private readonly financeState: FinanceStateService,
    private readonly alerts: AlertsService,
    private readonly organizerFinance: OrganizerFinanceService,
    private readonly integrations: IntegrationsModeService,
  ) {}

  private publicWebhookUrl() {
    const base = this.config.get('PUBLIC_API_BASE_URL', { infer: true }).trim();
    return base ? `${base.replace(/\/$/, '')}/webhooks/quaser` : '';
  }

  private isQuaserStub() {
    return this.integrations.allowPaymentStubs();
  }

  private cooldownHours() {
    return this.config.get('PAYOUT_COOLDOWN_FALLBACK_HOURS', { infer: true });
  }

  async findEligibleOrders(
    tenantId: string,
    organizerId: string,
    limit: number,
  ): Promise<EligibleOrganizerPayoutRow[]> {
    const { rows } = await this.pool.query<EligibleOrganizerPayoutRow>(
      `SELECT tord.id AS ticket_order_id, tord.tenant_id, tord.organizer_id, tord.currency,
              tord.subtotal_minor::text AS subtotal_minor
       FROM ticket_orders tord
       LEFT JOIN tenant_finance_settings tfs ON tfs.tenant_id = tord.tenant_id
       WHERE tord.tenant_id = $1
         AND tord.organizer_id = $2
         AND tord.status IN ('fulfilled', 'confirmed')
         AND NOT EXISTS (
           SELECT 1 FROM ticket_refund_cases trc
           WHERE trc.ticket_order_id = tord.id
             AND trc.status::text IN ('requested', 'under_review', 'approved', 'processing')
         )
         AND NOT EXISTS (
           SELECT 1 FROM organizer_payouts op
           WHERE op.ticket_order_id = tord.id
             AND op.status::text IN ('pending', 'processing', 'completed')
         )
         AND (
           (tord.escrow_release_not_before IS NOT NULL AND tord.escrow_release_not_before <= now())
           OR (
             tord.escrow_release_not_before IS NULL
             AND COALESCE(tord.completed_at, tord.updated_at) + make_interval(
               hours => COALESCE(tfs.escrow_release_delay_hours, $3)
             ) <= now()
           )
         )
       ORDER BY tord.updated_at ASC
       LIMIT $4`,
      [tenantId, organizerId, this.cooldownHours(), limit],
    );
    return rows;
  }

  async requestPayout(
    actor: CommerceActor,
    organizerId: string,
    amountMinor: string,
  ): Promise<{ ok: boolean; requestedMinor: string; payouts: Array<{ payoutId: string; ticketOrderId: string; amountMinor: string }> }> {
    await this.organizerFinance.assertOrganizerAccess(actor, organizerId);
    await this.financeState.ensurePayoutsAllowed();

    const requested = BigInt(amountMinor);
    if (requested <= 0n) {
      throw new UnprocessableEntityException({
        code: 'INVALID_AMOUNT',
        message: 'Payout amount must be greater than zero',
      });
    }

    const summary = await this.organizerFinance.getOrganizerBalance(actor.tenantId, organizerId);
    const available = BigInt(summary.availableForPayoutMinor);
    if (available < requested) {
      throw new UnprocessableEntityException({
        code: 'INSUFFICIENT_AVAILABLE_BALANCE',
        message: 'Requested amount exceeds available balance',
      });
    }

    const eligible = await this.findEligibleOrders(actor.tenantId, organizerId, 50);
    if (!eligible.length) {
      throw new NotFoundException({
        code: 'NOT_FOUND',
        message: 'No eligible ticket orders for payout',
      });
    }

    let remaining = requested;
    const created: Array<{ payoutId: string; ticketOrderId: string; amountMinor: string }> = [];

    for (const row of eligible) {
      const rowAmount = BigInt(row.subtotal_minor);
      if (rowAmount > remaining) continue;
      const out = await this.enqueuePayout(row);
      if ('payoutId' in out) {
        created.push({
          payoutId: out.payoutId,
          ticketOrderId: row.ticket_order_id,
          amountMinor: row.subtotal_minor,
        });
        remaining -= rowAmount;
      }
      if (remaining === 0n) break;
    }

    if (remaining !== 0n) {
      throw new UnprocessableEntityException({
        code: 'AMOUNT_NOT_ALLOCATABLE',
        message: 'Requested amount cannot be composed from eligible ticket orders',
      });
    }

    return { ok: true, requestedMinor: requested.toString(), payouts: created };
  }

  async enqueuePayout(
    row: EligibleOrganizerPayoutRow,
  ): Promise<{ payoutId: string } | { skipped: true }> {
    await this.financeState.ensurePayoutsAllowed();
    const webhookUrl = this.publicWebhookUrl();
    if (!webhookUrl && !this.isQuaserStub()) {
      this.logger.warn('PUBLIC_API_BASE_URL missing; skip organizer payout');
      return { skipped: true };
    }

    const idempotencyKey = `org_payout:${row.ticket_order_id}:${randomUUID()}`;
    let payoutId: string;

    try {
      const ins = await this.pool.query<{ id: string }>(
        `INSERT INTO organizer_payouts (
           tenant_id, organizer_id, ticket_order_id, currency, amount_minor, idempotency_key, status, metadata
         ) VALUES ($1, $2, $3, $4, $5::bigint, $6, 'pending', $7::jsonb)
         RETURNING id`,
        [
          row.tenant_id,
          row.organizer_id,
          row.ticket_order_id,
          row.currency.toUpperCase(),
          row.subtotal_minor,
          idempotencyKey,
          JSON.stringify({ source: 'organizer_request' }),
        ],
      );
      const id = ins.rows[0]?.id;
      if (!id) return { skipped: true };
      payoutId = id;
    } catch (e: unknown) {
      const err = e as { code?: string };
      if (err.code === '23505') return { skipped: true };
      throw e;
    }

    try {
      const init = await this.quaser.initiateOrganizerPayoutTransfer({
        tenantId: row.tenant_id,
        payoutId,
        amountMinor: row.subtotal_minor,
        currency: row.currency,
        organizerId: row.organizer_id,
        idempotencyKey,
        webhookUrl: webhookUrl || 'http://localhost/dev-stub',
      });

      await this.pool.query(
        `UPDATE organizer_payouts
         SET status = 'processing',
             quaser_reference = $2,
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [payoutId, init.quaserReference, JSON.stringify({ quaser: init.raw })],
      );

      if (this.isQuaserStub()) {
        await this.completePayout(payoutId, { stub_auto_complete: true });
      }

      return { payoutId };
    } catch (e) {
      await this.pool.query(
        `UPDATE organizer_payouts
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

  async completePayout(
    payoutId: string,
    metadata: Record<string, unknown> = {},
  ): Promise<{ ok: boolean; reason?: string }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const pr = await client.query<{
        id: string;
        tenant_id: string;
        organizer_id: string;
        ticket_order_id: string;
        status: string;
        under_review: boolean;
        currency: string;
        amount_minor: string;
      }>(
        `SELECT id, tenant_id, organizer_id, ticket_order_id, status::text, under_review,
                currency, amount_minor::text
         FROM organizer_payouts WHERE id = $1 FOR UPDATE`,
        [payoutId],
      );
      const p = pr.rows[0];
      if (!p) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'not_found' };
      }
      if (p.status === 'completed') {
        await client.query('COMMIT');
        return { ok: true, reason: 'already_completed' };
      }
      if (!['pending', 'processing'].includes(p.status) || p.under_review) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'bad_state' };
      }

      const organizerPayableId = await this.ledger.ensureOrganizerPayableAccount(
        client,
        p.tenant_id,
        p.organizer_id,
        p.currency,
      );
      const clearingId = await this.ledger.ensureOrganizerPayoutClearingAccount(
        client,
        p.tenant_id,
        p.currency,
      );

      const ledgerTxnId = await this.ledger.applyOrganizerPayoutReleaseLedger(client, {
        tenantId: p.tenant_id,
        ticketOrderId: p.ticket_order_id,
        payoutId: p.id,
        amountMinor: BigInt(p.amount_minor),
        currency: p.currency,
        organizerPayableAccountId: organizerPayableId,
        organizerPayoutClearingAccountId: clearingId,
      });

      await client.query(
        `UPDATE organizer_payouts
         SET status = 'completed',
             ledger_transaction_id = $2,
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE id = $1`,
        [
          p.id,
          ledgerTxnId,
          JSON.stringify({ ...metadata, completed_at: new Date().toISOString() }),
        ],
      );

      await client.query('COMMIT');
      return { ok: true, reason: 'completed' };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }
}
