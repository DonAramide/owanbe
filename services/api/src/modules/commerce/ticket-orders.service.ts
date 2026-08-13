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
import { randomBytes, randomUUID } from 'crypto';
import {
  assertQuantityRules,
  assertTierPurchasable,
  parseTierMeta,
} from './ticket-tier-rules';
import {
  assertEventPurchaseEligible,
  requiresInvitationForPurchase,
} from './event-visibility-rules';

/** Pending payment orders older than this are cancelled and inventory restored. */
const ABANDONED_ORDER_TTL_MS = 30 * 60 * 1000;

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
    createdAt?: string;
    eventTitle?: string;
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

  /**
   * Cancel abandoned pending_payment orders and restore inventory.
   * Safe to call frequently (createOrder / list).
   */
  async releaseAbandonedOrders(
    tenantId?: string,
    ttlMs: number = ABANDONED_ORDER_TTL_MS,
  ): Promise<{ released: number }> {
    const cutoff = new Date(Date.now() - ttlMs);
    const client = await this.pool.connect();
    let released = 0;
    try {
      await client.query('BEGIN');
      const params: unknown[] = [cutoff.toISOString()];
      let tenantClause = '';
      if (tenantId) {
        params.push(tenantId);
        tenantClause = ` AND tenant_id = $${params.length}`;
      }
      const { rows: orders } = await client.query<{
        id: string;
        tenant_id: string;
      }>(
        `SELECT id, tenant_id FROM ticket_orders
         WHERE status = 'pending_payment'
           AND created_at < $1::timestamptz
           ${tenantClause}
         FOR UPDATE SKIP LOCKED
         LIMIT 100`,
        params,
      );

      for (const order of orders) {
        const lines = await client.query<{
          tier_id: string;
          quantity: number;
        }>(
          `SELECT tier_id, quantity FROM ticket_order_lines
           WHERE ticket_order_id = $1 AND tenant_id = $2`,
          [order.id, order.tenant_id],
        );

        for (const line of lines.rows) {
          // Only restore when tier is not unlimited (unlimited never decremented).
          await client.query(
            `UPDATE event_ticket_tiers t
             SET remaining = LEAST(t.capacity, t.remaining + $3),
                 updated_at = now()
             WHERE t.tenant_id = $1
               AND t.external_tier_id = $2
               AND COALESCE((t.metadata->>'unlimitedCapacity')::boolean, false) = false`,
            [order.tenant_id, line.tier_id, line.quantity],
          );
        }

        await client.query(
          `UPDATE ticket_orders
           SET status = 'cancelled',
               metadata = metadata || $3::jsonb,
               updated_at = now()
           WHERE id = $1 AND tenant_id = $2 AND status = 'pending_payment'`,
          [
            order.id,
            order.tenant_id,
            JSON.stringify({
              cancelledReason: 'abandoned_checkout',
              cancelledAt: new Date().toISOString(),
            }),
          ],
        );
        released += 1;
      }

      await client.query('COMMIT');
      return { released };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  async createOrder(
    eventKey: string,
    dto: CreateTicketOrderDto,
    actor: CommerceActor,
    idempotencyKey?: string,
  ): Promise<TicketOrderResult> {
    if (dto.attendeeId && dto.attendeeId !== actor.userId) {
      throw new BadRequestException({
        code: 'ATTENDEE_MISMATCH',
        message: 'attendeeId must match authenticated user',
      });
    }

    // Best-effort inventory recovery before allocating new holds.
    try {
      await this.releaseAbandonedOrders(actor.tenantId);
    } catch {
      // Non-fatal — order path continues.
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const event = await this.findEvent(client, actor.tenantId, eventKey);
      if (!event) {
        throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found' });
      }

      const eventGate = assertEventPurchaseEligible({
        status: event.status,
        metadata: event.metadata,
      });
      if (eventGate) {
        throw new UnprocessableEntityException(eventGate);
      }

      if (requiresInvitationForPurchase(event.metadata)) {
        const invited = await this.buyerHasInvitation(
          client,
          actor.tenantId,
          event.id,
          actor.email,
          actor.userId,
        );
        if (!invited) {
          throw new UnprocessableEntityException({
            code: 'INVITATION_REQUIRED',
            message: 'An invitation is required to purchase tickets for this event',
          });
        }
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
        unlimited: boolean;
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
          metadata: Record<string, unknown>;
        }>(
          `SELECT id, external_tier_id, name, tier_type, price_minor::text, remaining, sales_paused,
                  currency, metadata
           FROM event_ticket_tiers
           WHERE tenant_id = $1 AND event_id = $2 AND external_tier_id = $3
           FOR UPDATE`,
          [actor.tenantId, event.id, item.tierId],
        );
        const t = tier.rows[0];
        if (!t) {
          throw new NotFoundException({ code: 'TIER_NOT_FOUND', message: `Tier ${item.tierId} not found` });
        }

        const meta = parseTierMeta(t.metadata);
        const eligibility = assertTierPurchasable({
          name: t.name,
          salesPaused: t.sales_paused,
          metadata: t.metadata,
          forPublicListing: true,
        });
        if (eligibility) {
          throw new UnprocessableEntityException(eligibility);
        }

        const qtyFail = assertQuantityRules({
          name: t.name,
          quantity: item.quantity,
          remaining: t.remaining,
          unlimited: meta.unlimitedCapacity === true,
          minQuantity: meta.minQuantity ?? 1,
          maxQuantity: meta.maxQuantity ?? null,
        });
        if (qtyFail) {
          throw new UnprocessableEntityException(qtyFail);
        }

        if (meta.maxPerUser != null && meta.maxPerUser > 0) {
          const prior = await client.query<{ qty: string }>(
            `SELECT COALESCE(SUM(l.quantity), 0)::text AS qty
             FROM ticket_order_lines l
             INNER JOIN ticket_orders o ON o.id = l.ticket_order_id
             WHERE o.tenant_id = $1
               AND o.event_id = $2
               AND o.buyer_user_id = $3
               AND l.tier_id = $4
               AND o.status IN ('pending_payment', 'confirmed', 'fulfilled')`,
            [actor.tenantId, event.id, actor.userId, t.external_tier_id],
          );
          const already = Number(prior.rows[0]?.qty ?? 0);
          if (already + item.quantity > meta.maxPerUser) {
            throw new UnprocessableEntityException({
              code: 'PER_USER_LIMIT',
              message: `${t.name} allows at most ${meta.maxPerUser} per attendee (you have ${already})`,
            });
          }
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
          unlimited: meta.unlimitedCapacity === true,
        });

        if (!meta.unlimitedCapacity) {
          await client.query(
            `UPDATE event_ticket_tiers SET remaining = remaining - $3, updated_at = now()
             WHERE id = $1 AND tenant_id = $2 AND remaining >= $3`,
            [t.id, actor.tenantId, item.quantity],
          );
        }
      }

      // Complimentary / free: platform fee is 0 when subtotal is 0
      const fee =
        subtotal === 0n
          ? 0n
          : BigInt(computePlatformFeeMinor(Number(subtotal), policy.ticketPlatformFeeBps));
      const total = subtotal + fee;

      const ins = await client.query<{ id: string }>(
        `INSERT INTO ticket_orders (
           tenant_id, organizer_id, event_id, buyer_user_id, status, currency,
           subtotal_minor, platform_fee_minor, total_minor, idempotency_key, metadata
         ) VALUES ($1, $2, $3, $4, 'pending_payment', $5, $6, $7, $8, $9, $10::jsonb)
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
          JSON.stringify({
            inventoryHeldAt: new Date().toISOString(),
            freeOrder: total === 0n,
          }),
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

      // Phase 14: free / complimentary — fulfill immediately (no payment rail).
      if (total === 0n) {
        await client.query(
          `UPDATE ticket_orders
           SET status = 'fulfilled',
               completed_at = now(),
               metadata = metadata || $3::jsonb,
               updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [
            orderId,
            actor.tenantId,
            JSON.stringify({
              freeFulfilledAt: new Date().toISOString(),
              freeOrder: true,
            }),
          ],
        );
        await this.issueEntitlementsForOrder(
          client,
          actor.tenantId,
          orderId,
          event.id,
          actor.userId,
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
      created_at: Date;
      event_title: string | null;
    }>(
      `SELECT o.id, o.event_id, o.organizer_id, o.status::text, o.currency,
              o.subtotal_minor::text, o.platform_fee_minor::text, o.total_minor::text,
              o.created_at, e.title AS event_title
       FROM ticket_orders o
       LEFT JOIN events e ON e.id = o.event_id
       WHERE o.id = $1 AND o.tenant_id = $2`,
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
        createdAt: o.created_at.toISOString(),
        eventTitle: o.event_title ?? undefined,
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

  async getOrderForBuyer(tenantId: string, userId: string, orderId: string): Promise<TicketOrderResult> {
    const owned = await this.pool.query<{ id: string }>(
      `SELECT id FROM ticket_orders
       WHERE id = $1 AND tenant_id = $2 AND buyer_user_id = $3`,
      [orderId, tenantId, userId],
    );
    if (!owned.rows[0]) {
      throw new NotFoundException({ code: 'ORDER_NOT_FOUND', message: 'Ticket order not found' });
    }
    return this.getOrderById(tenantId, orderId);
  }

  async listOrdersForBuyer(tenantId: string, userId: string) {
    try {
      await this.releaseAbandonedOrders(tenantId);
    } catch {
      /* ignore */
    }
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      status: string;
      currency: string;
      total_minor: string;
      created_at: Date;
      event_title: string | null;
    }>(
      `SELECT o.id, o.event_id, o.status::text, o.currency, o.total_minor::text, o.created_at,
              e.title AS event_title
       FROM ticket_orders o
       LEFT JOIN events e ON e.id = o.event_id
       WHERE o.tenant_id = $1 AND o.buyer_user_id = $2
       ORDER BY o.created_at DESC
       LIMIT 100`,
      [tenantId, userId],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        eventId: r.event_id,
        eventTitle: r.event_title ?? 'Event',
        status: r.status,
        currency: r.currency,
        totalMinor: r.total_minor,
        createdAt: r.created_at.toISOString(),
      })),
    };
  }

  private async buyerHasInvitation(
    client: PoolClient,
    tenantId: string,
    eventId: string,
    email: string | undefined,
    userId: string,
  ): Promise<boolean> {
    let normalized = (email ?? '').trim().toLowerCase();
    if (!normalized) {
      const u = await client.query<{ email: string | null }>(
        `SELECT email FROM users WHERE id = $1 AND tenant_id = $2 LIMIT 1`,
        [userId, tenantId],
      );
      normalized = (u.rows[0]?.email ?? '').trim().toLowerCase();
    }
    if (!normalized) return false;

    const { rows } = await client.query<{ id: string }>(
      `SELECT g.id
       FROM event_guests g
       WHERE g.tenant_id = $1
         AND g.event_id = $2
         AND lower(trim(g.email)) = $3
       LIMIT 1`,
      [tenantId, eventId, normalized],
    );
    return rows.length > 0;
  }

  private async issueEntitlementsForOrder(
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
        const ticketCode = `TKT-${randomBytes(6).toString('hex').toUpperCase()}`;
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
            JSON.stringify({ qr_payload: qrPayload, tier_name: line.tier_name, freeOrder: true }),
          ],
        );
        if (ins.rows[0]) ids.push(ins.rows[0].id);
      }
    }
    return ids;
  }

  private async findEvent(client: PoolClient, tenantId: string, eventKey: string) {
    const { rows } = await client.query<{
      id: string;
      organizer_id: string;
      status: string;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, organizer_id, status::text, metadata
       FROM events
       WHERE tenant_id = $1 AND (id::text = $2 OR external_ref = $2 OR slug = $2)
       LIMIT 1`,
      [tenantId, eventKey],
    );
    return rows[0] ?? null;
  }
}
