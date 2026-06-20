import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { TenantFinancePolicyService } from './tenant-finance-policy.service';
import { computePlatformFeeMinor } from './commerce.types';
import type { CreateTicketOrderDto } from './dto/create-ticket-order.dto';
import type { CommerceActor } from './commerce-auth.service';
import { randomUUID } from 'crypto';

export interface TicketOrderResult {
  order: {
    id: string;
    eventId: string;
    organizerId: string;
    status: string;
    currency: string;
    subtotalMinor: string;
    platformFeeMinor: string;
    totalMinor: string;
    lines: Array<{
      id: string;
      tierId: string;
      tierName: string;
      quantity: number;
      unitPriceMinor: string;
      lineSubtotalMinor: string;
    }>;
  };
}

@Injectable()
export class TicketOrdersService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly financePolicy: TenantFinancePolicyService,
  ) {}

  async createOrder(
    eventKey: string,
    dto: CreateTicketOrderDto,
    actor: CommerceActor,
    idempotencyKey?: string,
  ): Promise<TicketOrderResult> {
    if (dto.attendeeId && dto.attendeeId !== actor.userId) {
      throw new BadRequestException({ code: 'ATTENDEE_MISMATCH', message: 'attendeeId must match authenticated user' });
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const event = await this.findEvent(client, actor.tenantId, eventKey);
      if (!event) {
        throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found' });
      }
      if (!['published', 'live'].includes(event.status)) {
        throw new UnprocessableEntityException({ code: 'EVENT_NOT_SALEABLE', message: 'Event not open for ticket sales' });
      }

      const idem =
        idempotencyKey && idempotencyKey.length >= 8 && idempotencyKey.length <= 128
          ? idempotencyKey.trim()
          : `tord_${randomUUID()}`;

      const existing = await client.query<{ id: string }>(
        `SELECT id FROM ticket_orders WHERE tenant_id = $1 AND idempotency_key = $2`,
        [actor.tenantId, idem],
      );
      if (existing.rows[0]) {
        await client.query('COMMIT');
        return this.getOrderById(actor.tenantId, existing.rows[0].id);
      }

      const policy = await this.financePolicy.getPolicy(actor.tenantId);
      let subtotal = 0n;
      const lineRows: Array<{
        tierId: string;
        tierName: string;
        tierType: string;
        unitPrice: bigint;
        qty: number;
        lineSubtotal: bigint;
        dbTierId: string;
      }> = [];

      for (const item of dto.items) {
        const tier = await client.query<{
          id: string;
          external_tier_id: string;
          name: string;
          tier_type: string;
          price_minor: string;
          remaining: number;
          sales_paused: boolean;
          currency: string;
        }>(
          `SELECT id, external_tier_id, name, tier_type, price_minor::text, remaining, sales_paused, currency
           FROM event_ticket_tiers
           WHERE tenant_id = $1 AND event_id = $2 AND external_tier_id = $3
           FOR UPDATE`,
          [actor.tenantId, event.id, item.tierId],
        );
        const t = tier.rows[0];
        if (!t) {
          throw new NotFoundException({ code: 'TIER_NOT_FOUND', message: `Tier ${item.tierId} not found` });
        }
        if (t.sales_paused) {
          throw new UnprocessableEntityException({ code: 'TIER_PAUSED', message: `${t.name} is not on sale` });
        }
        if (t.remaining < item.quantity) {
          throw new UnprocessableEntityException({
            code: 'INSUFFICIENT_INVENTORY',
            message: `Only ${t.remaining} remaining for ${t.name}`,
          });
        }
        if (t.currency !== dto.currency.toUpperCase()) {
          throw new BadRequestException({ code: 'CURRENCY_MISMATCH', message: 'Tier currency mismatch' });
        }

        const unit = BigInt(t.price_minor);
        const lineSub = unit * BigInt(item.quantity);
        subtotal += lineSub;
        lineRows.push({
          tierId: t.external_tier_id,
          tierName: t.name,
          tierType: t.tier_type,
          unitPrice: unit,
          qty: item.quantity,
          lineSubtotal: lineSub,
          dbTierId: t.id,
        });

        await client.query(
          `UPDATE event_ticket_tiers SET remaining = remaining - $3, updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [t.id, actor.tenantId, item.quantity],
        );
      }

      const fee = BigInt(computePlatformFeeMinor(Number(subtotal), policy.ticketPlatformFeeBps));
      const total = subtotal + fee;

      const ins = await client.query<{ id: string }>(
        `INSERT INTO ticket_orders (
           tenant_id, organizer_id, event_id, buyer_user_id, status, currency,
           subtotal_minor, platform_fee_minor, total_minor, idempotency_key
         ) VALUES ($1, $2, $3, $4, 'pending_payment', $5, $6, $7, $8, $9)
         RETURNING id`,
        [
          actor.tenantId,
          event.organizer_id,
          event.id,
          actor.userId,
          dto.currency.toUpperCase(),
          subtotal.toString(),
          fee.toString(),
          total.toString(),
          idem,
        ],
      );
      const orderId = ins.rows[0]?.id;
      if (!orderId) {
        throw new UnprocessableEntityException({ code: 'ORDER_CREATE_FAILED', message: 'Insert failed' });
      }

      for (const line of lineRows) {
        await client.query(
          `INSERT INTO ticket_order_lines (
             tenant_id, ticket_order_id, tier_id, tier_name, tier_type,
             unit_price_minor, quantity, line_subtotal_minor, currency
           ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            actor.tenantId,
            orderId,
            line.tierId,
            line.tierName,
            line.tierType,
            line.unitPrice.toString(),
            line.qty,
            line.lineSubtotal.toString(),
            dto.currency.toUpperCase(),
          ],
        );
      }

      await client.query('COMMIT');
      return this.getOrderById(actor.tenantId, orderId);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  async getOrderById(tenantId: string, orderId: string): Promise<TicketOrderResult> {
    const order = await this.pool.query<{
      id: string;
      event_id: string;
      organizer_id: string;
      status: string;
      currency: string;
      subtotal_minor: string;
      platform_fee_minor: string;
      total_minor: string;
    }>(
      `SELECT id, event_id, organizer_id, status::text, currency,
              subtotal_minor::text, platform_fee_minor::text, total_minor::text
       FROM ticket_orders WHERE id = $1 AND tenant_id = $2`,
      [orderId, tenantId],
    );
    const o = order.rows[0];
    if (!o) {
      throw new NotFoundException({ code: 'ORDER_NOT_FOUND', message: 'Ticket order not found' });
    }
    const lines = await this.pool.query<{
      id: string;
      tier_id: string;
      tier_name: string;
      quantity: number;
      unit_price_minor: string;
      line_subtotal_minor: string;
    }>(
      `SELECT id, tier_id, tier_name, quantity, unit_price_minor::text, line_subtotal_minor::text
       FROM ticket_order_lines WHERE ticket_order_id = $1 AND tenant_id = $2`,
      [orderId, tenantId],
    );
    return {
      order: {
        id: o.id,
        eventId: o.event_id,
        organizerId: o.organizer_id,
        status: o.status,
        currency: o.currency,
        subtotalMinor: o.subtotal_minor,
        platformFeeMinor: o.platform_fee_minor,
        totalMinor: o.total_minor,
        lines: lines.rows.map((l) => ({
          id: l.id,
          tierId: l.tier_id,
          tierName: l.tier_name,
          quantity: l.quantity,
          unitPriceMinor: l.unit_price_minor,
          lineSubtotalMinor: l.line_subtotal_minor,
        })),
      },
    };
  }

  private async findEvent(client: PoolClient, tenantId: string, eventKey: string) {
    const { rows } = await client.query<{
      id: string;
      organizer_id: string;
      status: string;
    }>(
      `SELECT id, organizer_id, status::text
       FROM events
       WHERE tenant_id = $1 AND (id::text = $2 OR external_ref = $2 OR slug = $2)
       LIMIT 1`,
      [tenantId, eventKey],
    );
    return rows[0] ?? null;
  }
}
