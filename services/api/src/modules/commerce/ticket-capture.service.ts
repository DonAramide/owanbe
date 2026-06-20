import { Injectable, Inject, UnprocessableEntityException } from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { randomBytes } from 'crypto';
import { PG_POOL } from '../../database/database.tokens';
import { LedgerService } from '../payments/ledger.service';
import { FinanceStateService } from '../payments/finance-state.service';

export interface TicketCaptureResult {
  ok: boolean;
  duplicate?: boolean;
  reason?: string;
  entitlementIds?: string[];
}

@Injectable()
export class TicketCaptureService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly ledger: LedgerService,
    private readonly financeState: FinanceStateService,
  ) {}

  async applyCapture(
    ticketPaymentId: string,
    opts: {
      eventId?: string;
      eventType?: string;
      payload?: Record<string, unknown>;
      amountMinor?: string;
    } = {},
  ): Promise<TicketCaptureResult> {
    await this.financeState.ensurePaymentsAllowed();

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const payRows = await client.query<{
        id: string;
        tenant_id: string;
        ticket_order_id: string;
        currency: string;
        status: string;
        under_review: boolean;
      }>(
        `SELECT id, tenant_id, ticket_order_id, currency, status::text, under_review
         FROM ticket_payments WHERE id = $1 FOR UPDATE`,
        [ticketPaymentId],
      );
      const pay = payRows.rows[0];
      if (!pay) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'ticket_payment_not_found' };
      }

      if (pay.status === 'captured') {
        const ids = await this.ensureEntitlements(client, pay.tenant_id, pay.ticket_order_id);
        await client.query('COMMIT');
        return { ok: true, duplicate: true, reason: 'already_captured', entitlementIds: ids };
      }
      if (pay.under_review) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'payment_under_review' };
      }

      const ord = await client.query<{
        subtotal_minor: string;
        platform_fee_minor: string;
        total_minor: string;
        organizer_id: string;
        event_id: string;
        buyer_user_id: string;
        status: string;
      }>(
        `SELECT subtotal_minor::text, platform_fee_minor::text, total_minor::text,
                organizer_id, event_id, buyer_user_id, status::text
         FROM ticket_orders WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
        [pay.ticket_order_id, pay.tenant_id],
      );
      const order = ord.rows[0];
      if (!order) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'order_not_found' };
      }

      const expectedTotal = order.total_minor;
      if (opts.amountMinor != null && opts.amountMinor !== expectedTotal) {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'amount_mismatch' };
      }

      const gross = BigInt(expectedTotal);
      const fee = BigInt(order.platform_fee_minor);
      const organizerShare = BigInt(order.subtotal_minor);

      const accounts = await this.ledger.ensurePoolLedgerAccounts(client, pay.tenant_id, pay.currency);
      const organizerPayableId = await this.ledger.ensureOrganizerPayableAccount(
        client,
        pay.tenant_id,
        order.organizer_id,
        pay.currency,
      );

      const payloadJson = JSON.stringify(opts.payload ?? { dev: true });
      const { rows: capRows } = await client.query<{ owanbe_apply_ticket_payment_capture: unknown }>(
        `SELECT owanbe_apply_ticket_payment_capture(
           $1::uuid, $2::uuid, 'quaser'::payment_provider,
           $3, $4, $5::jsonb,
           $6::uuid, $7::uuid, $8::uuid, $9::uuid,
           $10::bigint, $11::bigint, $12::bigint
         ) AS owanbe_apply_ticket_payment_capture`,
        [
          ticketPaymentId,
          pay.tenant_id,
          opts.eventId ?? null,
          opts.eventType ?? 'payment.captured',
          payloadJson,
          accounts.pspClearingId,
          accounts.escrowPoolId,
          accounts.platformFeesId,
          organizerPayableId,
          gross.toString(),
          fee.toString(),
          organizerShare.toString(),
        ],
      );

      const result = capRows[0]?.owanbe_apply_ticket_payment_capture as Record<string, unknown> | undefined;
      if (result?.error) {
        await client.query('ROLLBACK');
        return { ok: false, reason: String(result.error) };
      }

      await client.query(
        `UPDATE ticket_orders SET status = 'fulfilled', completed_at = now(),
           escrow_release_not_before = now() + (
             SELECT make_interval(hours => COALESCE(tfs.escrow_release_delay_hours, 48))
             FROM tenant_finance_settings tfs WHERE tfs.tenant_id = $3
           ),
           updated_at = now()
         WHERE id = $1 AND tenant_id = $2`,
        [pay.ticket_order_id, pay.tenant_id, pay.tenant_id],
      );

      const entitlementIds = await this.issueEntitlements(
        client,
        pay.tenant_id,
        pay.ticket_order_id,
        order.event_id,
        order.buyer_user_id,
      );

      await client.query('COMMIT');
      return { ok: true, reason: 'applied', entitlementIds };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  private async ensureEntitlements(
    client: PoolClient,
    tenantId: string,
    orderId: string,
  ): Promise<string[]> {
    const { rows } = await client.query<{ id: string }>(
      `SELECT id FROM ticket_entitlements WHERE tenant_id = $1 AND ticket_order_id = $2`,
      [tenantId, orderId],
    );
    if (rows.length > 0) {
      return rows.map((r) => r.id);
    }
    const ord = await client.query<{ event_id: string; buyer_user_id: string }>(
      `SELECT event_id, buyer_user_id FROM ticket_orders WHERE id = $1 AND tenant_id = $2`,
      [orderId, tenantId],
    );
    const o = ord.rows[0];
    if (!o) return [];
    return this.issueEntitlements(client, tenantId, orderId, o.event_id, o.buyer_user_id);
  }

  private async issueEntitlements(
    client: PoolClient,
    tenantId: string,
    orderId: string,
    eventId: string,
    holderUserId: string,
  ): Promise<string[]> {
    const existing = await client.query<{ id: string }>(
      `SELECT id FROM ticket_entitlements WHERE tenant_id = $1 AND ticket_order_id = $2`,
      [tenantId, orderId],
    );
    if (existing.rows.length > 0) {
      return existing.rows.map((r) => r.id);
    }

    const lines = await client.query<{
      id: string;
      tier_id: string;
      tier_name: string;
      quantity: number;
    }>(
      `SELECT id, tier_id, tier_name, quantity FROM ticket_order_lines
       WHERE ticket_order_id = $1 AND tenant_id = $2`,
      [orderId, tenantId],
    );

    const ids: string[] = [];
    for (const line of lines.rows) {
      for (let i = 0; i < line.quantity; i++) {
        const ticketCode = this.generateTicketCode();
        const qrPayload = `OWANBE:${eventId}:${line.tier_id}:${ticketCode}`;
        const ins = await client.query<{ id: string }>(
          `INSERT INTO ticket_entitlements (
             tenant_id, ticket_order_id, ticket_order_line_id, event_id, holder_user_id,
             ticket_code, status, metadata
           ) VALUES ($1, $2, $3, $4, $5, $6, 'issued', $7::jsonb)
           RETURNING id`,
          [
            tenantId,
            orderId,
            line.id,
            eventId,
            holderUserId,
            ticketCode,
            JSON.stringify({ qr_payload: qrPayload, tier_name: line.tier_name }),
          ],
        );
        if (ins.rows[0]) {
          ids.push(ins.rows[0].id);
        }
      }
    }
    return ids;
  }

  private generateTicketCode(): string {
    return `TKT-${randomBytes(6).toString('hex').toUpperCase()}`;
  }
}
