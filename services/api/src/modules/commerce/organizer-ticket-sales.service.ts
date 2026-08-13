import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from './commerce-auth.service';
import { sqlOrganizerOwnerOrMember } from '../events/organizer-access.sql';

/**
 * Organizer-facing order & buyer visibility over existing commerce tables (Phase 14).
 */
@Injectable()
export class OrganizerTicketSalesService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  private async resolveEventScope(
    tenantId: string,
    userId: string,
    eventKey: string,
  ): Promise<{ eventId: string; eventTitle: string; organizerId: string }> {
    const { rows } = await this.pool.query<{
      event_id: string;
      title: string;
      organizer_id: string;
    }>(
      `SELECT e.id AS event_id, e.title, e.organizer_id
       FROM events e
       INNER JOIN organizers o ON o.id = e.organizer_id AND o.tenant_id = e.tenant_id
       WHERE e.tenant_id = $1
         AND ${sqlOrganizerOwnerOrMember('$2')}
         AND (e.id::text = $3 OR e.external_ref = $3 OR e.slug = $3)
       LIMIT 1`,
      [tenantId, userId, eventKey],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found or access denied' });
    }
    return { eventId: row.event_id, eventTitle: row.title, organizerId: row.organizer_id };
  }

  async listOrders(actor: CommerceActor, eventKey: string, limit = 100) {
    const scope = await this.resolveEventScope(actor.tenantId, actor.userId, eventKey);
    const n = Math.min(Math.max(limit, 1), 200);

    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      currency: string;
      subtotal_minor: string;
      platform_fee_minor: string;
      total_minor: string;
      amount_refunded_minor: string;
      created_at: Date;
      completed_at: Date | null;
      buyer_user_id: string;
      buyer_email: string | null;
      buyer_name: string | null;
      payment_status: string | null;
      quaser_reference: string | null;
      qty: string;
      tier_names: string | null;
      refund_status: string | null;
    }>(
      `SELECT o.id, o.status::text, o.currency,
              o.subtotal_minor::text, o.platform_fee_minor::text, o.total_minor::text,
              o.amount_refunded_minor::text, o.created_at, o.completed_at,
              o.buyer_user_id,
              u.email AS buyer_email,
              COALESCE(u.display_name, split_part(COALESCE(u.email, ''), '@', 1)) AS buyer_name,
              (
                SELECT tp.status::text FROM ticket_payments tp
                WHERE tp.ticket_order_id = o.id AND tp.tenant_id = o.tenant_id
                ORDER BY tp.created_at DESC LIMIT 1
              ) AS payment_status,
              (
                SELECT tp.quaser_reference FROM ticket_payments tp
                WHERE tp.ticket_order_id = o.id AND tp.tenant_id = o.tenant_id
                ORDER BY tp.created_at DESC LIMIT 1
              ) AS quaser_reference,
              (
                SELECT COALESCE(SUM(l.quantity), 0)::text FROM ticket_order_lines l
                WHERE l.ticket_order_id = o.id
              ) AS qty,
              (
                SELECT string_agg(DISTINCT l.tier_name, ', ') FROM ticket_order_lines l
                WHERE l.ticket_order_id = o.id
              ) AS tier_names,
              (
                SELECT trc.status::text FROM ticket_refund_cases trc
                WHERE trc.ticket_order_id = o.id AND trc.tenant_id = o.tenant_id
                ORDER BY trc.created_at DESC LIMIT 1
              ) AS refund_status
       FROM ticket_orders o
       LEFT JOIN users u ON u.id = o.buyer_user_id
       WHERE o.tenant_id = $1 AND o.event_id = $2
       ORDER BY o.created_at DESC
       LIMIT $3`,
      [actor.tenantId, scope.eventId, n],
    );

    const summary = await this.salesSummary(actor.tenantId, scope.eventId);

    return {
      eventId: scope.eventId,
      eventTitle: scope.eventTitle,
      summary,
      items: rows.map((r) => ({
        id: r.id,
        status: r.status,
        currency: r.currency,
        subtotalMinor: r.subtotal_minor,
        platformFeeMinor: r.platform_fee_minor,
        totalMinor: r.total_minor,
        amountRefundedMinor: r.amount_refunded_minor,
        createdAt: r.created_at.toISOString(),
        completedAt: r.completed_at?.toISOString() ?? null,
        buyerUserId: r.buyer_user_id,
        buyerEmail: r.buyer_email ?? '',
        buyerName: (r.buyer_name && r.buyer_name.trim()) || r.buyer_email || 'Buyer',
        paymentStatus: r.payment_status ?? (r.status === 'fulfilled' && r.total_minor === '0' ? 'free' : null),
        transactionReference: r.quaser_reference,
        quantity: parseInt(r.qty ?? '0', 10),
        ticketTypes: r.tier_names ?? '',
        refundStatus: r.refund_status,
      })),
    };
  }

  async getOrder(actor: CommerceActor, eventKey: string, orderId: string) {
    const scope = await this.resolveEventScope(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      currency: string;
      subtotal_minor: string;
      platform_fee_minor: string;
      total_minor: string;
      amount_refunded_minor: string;
      created_at: Date;
      completed_at: Date | null;
      buyer_user_id: string;
      buyer_email: string | null;
      buyer_name: string | null;
      idempotency_key: string;
    }>(
      `SELECT o.id, o.status::text, o.currency,
              o.subtotal_minor::text, o.platform_fee_minor::text, o.total_minor::text,
              o.amount_refunded_minor::text, o.created_at, o.completed_at,
              o.buyer_user_id, o.idempotency_key,
              u.email AS buyer_email,
              COALESCE(u.display_name, split_part(COALESCE(u.email, ''), '@', 1)) AS buyer_name
       FROM ticket_orders o
       LEFT JOIN users u ON u.id = o.buyer_user_id
       WHERE o.tenant_id = $1 AND o.event_id = $2 AND o.id = $3
       LIMIT 1`,
      [actor.tenantId, scope.eventId, orderId],
    );
    const o = rows[0];
    if (!o) {
      throw new NotFoundException({ code: 'ORDER_NOT_FOUND', message: 'Order not found' });
    }

    const lines = await this.pool.query<{
      id: string;
      tier_id: string;
      tier_name: string;
      tier_type: string;
      quantity: number;
      unit_price_minor: string;
      line_subtotal_minor: string;
    }>(
      `SELECT id, tier_id, tier_name, tier_type, quantity,
              unit_price_minor::text, line_subtotal_minor::text
       FROM ticket_order_lines WHERE ticket_order_id = $1 AND tenant_id = $2`,
      [orderId, actor.tenantId],
    );

    const payments = await this.pool.query<{
      id: string;
      status: string;
      amount_captured_minor: string;
      quaser_reference: string | null;
      created_at: Date;
    }>(
      `SELECT id, status::text, amount_captured_minor::text, quaser_reference, created_at
       FROM ticket_payments WHERE ticket_order_id = $1 AND tenant_id = $2
       ORDER BY created_at DESC`,
      [orderId, actor.tenantId],
    );

    const refunds = await this.pool.query<{
      id: string;
      status: string;
      amount_minor: string;
      created_at: Date;
    }>(
      `SELECT id, status::text, amount_minor::text, created_at
       FROM ticket_refund_cases WHERE ticket_order_id = $1 AND tenant_id = $2
       ORDER BY created_at DESC`,
      [orderId, actor.tenantId],
    );

    const entitlements = await this.pool.query<{
      id: string;
      ticket_code: string;
      status: string;
      tier_name: string | null;
    }>(
      `SELECT te.id, te.ticket_code, te.status::text,
              COALESCE(te.metadata->>'tier_name', tol.tier_name) AS tier_name
       FROM ticket_entitlements te
       LEFT JOIN ticket_order_lines tol ON tol.id = te.ticket_order_line_id
       WHERE te.ticket_order_id = $1 AND te.tenant_id = $2`,
      [orderId, actor.tenantId],
    );

    const latestPay = payments.rows[0];

    return {
      eventId: scope.eventId,
      eventTitle: scope.eventTitle,
      order: {
        id: o.id,
        status: o.status,
        currency: o.currency,
        subtotalMinor: o.subtotal_minor,
        platformFeeMinor: o.platform_fee_minor,
        totalMinor: o.total_minor,
        amountRefundedMinor: o.amount_refunded_minor,
        createdAt: o.created_at.toISOString(),
        completedAt: o.completed_at?.toISOString() ?? null,
        idempotencyKey: o.idempotency_key,
        buyer: {
          userId: o.buyer_user_id,
          email: o.buyer_email ?? '',
          name: (o.buyer_name && o.buyer_name.trim()) || o.buyer_email || 'Buyer',
        },
        paymentStatus:
          latestPay?.status ?? (o.status === 'fulfilled' && o.total_minor === '0' ? 'free' : null),
        transactionReference: latestPay?.quaser_reference ?? null,
        refundStatus: refunds.rows[0]?.status ?? null,
        lines: lines.rows.map((l) => ({
          id: l.id,
          tierId: l.tier_id,
          tierName: l.tier_name,
          tierType: l.tier_type,
          quantity: l.quantity,
          unitPriceMinor: l.unit_price_minor,
          lineSubtotalMinor: l.line_subtotal_minor,
        })),
        payments: payments.rows.map((p) => ({
          id: p.id,
          status: p.status,
          amountCapturedMinor: p.amount_captured_minor,
          transactionReference: p.quaser_reference,
          createdAt: p.created_at.toISOString(),
        })),
        refunds: refunds.rows.map((r) => ({
          id: r.id,
          status: r.status,
          amountMinor: r.amount_minor,
          createdAt: r.created_at.toISOString(),
        })),
        entitlements: entitlements.rows.map((e) => ({
          id: e.id,
          ticketCode: e.ticket_code,
          status: e.status,
          tierName: e.tier_name,
        })),
      },
    };
  }

  async listBuyers(actor: CommerceActor, eventKey: string, limit = 200) {
    const scope = await this.resolveEventScope(actor.tenantId, actor.userId, eventKey);
    const n = Math.min(Math.max(limit, 1), 500);

    const { rows } = await this.pool.query<{
      id: string;
      ticket_code: string;
      status: string;
      tier_name: string | null;
      created_at: Date;
      order_id: string | null;
      order_status: string | null;
      email: string | null;
      display_name: string | null;
      total_minor: string | null;
    }>(
      `SELECT te.id, te.ticket_code, te.status::text,
              COALESCE(te.metadata->>'tier_name', tol.tier_name) AS tier_name,
              te.issued_at AS created_at, te.ticket_order_id AS order_id, o.status::text AS order_status,
              u.email,
              COALESCE(u.display_name, split_part(COALESCE(u.email, ''), '@', 1)) AS display_name,
              o.total_minor::text AS total_minor
       FROM ticket_entitlements te
       LEFT JOIN ticket_order_lines tol ON tol.id = te.ticket_order_line_id
       LEFT JOIN ticket_orders o ON o.id = te.ticket_order_id
       LEFT JOIN users u ON u.id = te.holder_user_id
       WHERE te.tenant_id = $1 AND te.event_id = $2
       ORDER BY te.issued_at DESC
       LIMIT $3`,
      [actor.tenantId, scope.eventId, n],
    );

    return {
      eventId: scope.eventId,
      eventTitle: scope.eventTitle,
      summary: await this.salesSummary(actor.tenantId, scope.eventId),
      items: rows.map((b) => ({
        id: b.id,
        name: (b.display_name && b.display_name.trim()) || b.email || 'Attendee',
        email: b.email ?? '',
        tierName: b.tier_name ?? 'Ticket',
        ticketId: b.ticket_code,
        status: b.status,
        checkedIn: b.status === 'checked_in',
        purchasedAt: b.created_at.toISOString(),
        orderId: b.order_id,
        orderStatus: b.order_status,
        amountMinor: b.total_minor ?? '0',
      })),
    };
  }

  async salesDashboard(actor: CommerceActor, eventKey: string) {
    const scope = await this.resolveEventScope(actor.tenantId, actor.userId, eventKey);
    const summary = await this.salesSummary(actor.tenantId, scope.eventId);
    return { eventId: scope.eventId, eventTitle: scope.eventTitle, ...summary };
  }

  private async salesSummary(tenantId: string, eventId: string) {
    const { rows: orderRows } = await this.pool.query<{
      orders_count: string;
      revenue_minor: string;
    }>(
      `SELECT COUNT(*)::text AS orders_count,
              COALESCE(SUM(subtotal_minor), 0)::text AS revenue_minor
       FROM ticket_orders
       WHERE tenant_id = $1 AND event_id = $2
         AND status::text IN ('confirmed', 'fulfilled')`,
      [tenantId, eventId],
    );

    const { rows: buyerRows } = await this.pool.query<{ buyers: string; tickets: string }>(
      `SELECT COUNT(DISTINCT holder_user_id)::text AS buyers,
              COUNT(*)::text AS tickets
       FROM ticket_entitlements
       WHERE tenant_id = $1 AND event_id = $2
         AND status::text IN ('issued', 'checked_in')`,
      [tenantId, eventId],
    );

    const { rows: inv } = await this.pool.query<{
      remaining: string;
      capacity: string;
    }>(
      `SELECT COALESCE(SUM(remaining), 0)::text AS remaining,
              COALESCE(SUM(capacity), 0)::text AS capacity
       FROM event_ticket_tiers
       WHERE tenant_id = $1 AND event_id = $2
         AND COALESCE((metadata->>'archived')::boolean, false) = false`,
      [tenantId, eventId],
    );

    return {
      ordersCount: parseInt(orderRows[0]?.orders_count ?? '0', 10),
      buyersCount: parseInt(buyerRows[0]?.buyers ?? '0', 10),
      ticketsSold: parseInt(buyerRows[0]?.tickets ?? '0', 10),
      revenueMinor: orderRows[0]?.revenue_minor ?? '0',
      remainingInventory: parseInt(inv[0]?.remaining ?? '0', 10),
      totalCapacity: parseInt(inv[0]?.capacity ?? '0', 10),
    };
  }
}
