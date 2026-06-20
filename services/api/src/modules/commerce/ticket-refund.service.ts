import {
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { computeFeeReversalMinor } from './commerce.types';
import { TenantFinancePolicyService } from './tenant-finance-policy.service';
import type { CommerceActor } from './commerce-auth.service';
import { LedgerService } from '../payments/ledger.service';

export type TicketRefundAction = 'approve' | 'reject' | 'escalate';

@Injectable()
export class TicketRefundService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly financePolicy: TenantFinancePolicyService,
    private readonly ledger: LedgerService,
  ) {}

  async listQueue(tenantId: string, status?: string) {
    const statuses = status
      ? [status]
      : ['requested', 'under_review', 'approved', 'processing'];
    const { rows } = await this.pool.query(
      `SELECT trc.id, trc.ticket_order_id, trc.status::text, trc.amount_minor::text,
              trc.platform_fee_reversal_minor::text, trc.currency, trc.reason,
              trc.created_at, tord.event_id, e.title AS event_title,
              u.email AS requester_email
       FROM ticket_refund_cases trc
       INNER JOIN ticket_orders tord ON tord.id = trc.ticket_order_id
       INNER JOIN events e ON e.id = tord.event_id
       INNER JOIN users u ON u.id = trc.requested_by_user_id
       WHERE trc.tenant_id = $1 AND trc.status::text = ANY($2::text[])
       ORDER BY trc.created_at DESC
       LIMIT 200`,
      [tenantId, statuses],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        ticketOrderId: r.ticket_order_id,
        status: r.status,
        amountMinor: r.amount_minor,
        platformFeeReversalMinor: r.platform_fee_reversal_minor,
        currency: r.currency,
        reason: r.reason,
        eventId: r.event_id,
        eventTitle: r.event_title,
        requesterEmail: r.requester_email,
        createdAt: r.created_at,
      })),
    };
  }

  async getCase(tenantId: string, caseId: string) {
    const { rows } = await this.pool.query(
      `SELECT trc.*, tord.subtotal_minor::text AS order_subtotal,
              tord.platform_fee_minor::text AS order_fee, e.title AS event_title
       FROM ticket_refund_cases trc
       INNER JOIN ticket_orders tord ON tord.id = trc.ticket_order_id
       INNER JOIN events e ON e.id = tord.event_id
       WHERE trc.id = $1 AND trc.tenant_id = $2`,
      [caseId, tenantId],
    );
    const row = rows[0];
    if (!row) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Refund case not found' });
    return {
      id: row.id,
      ticketOrderId: row.ticket_order_id,
      status: row.status,
      amountMinor: String(row.amount_minor),
      platformFeeReversalMinor: String(row.platform_fee_reversal_minor),
      currency: row.currency,
      reason: row.reason,
      eventTitle: row.event_title,
      orderSubtotalMinor: row.order_subtotal,
      orderFeeMinor: row.order_fee,
      createdAt: row.created_at,
    };
  }

  async createCase(
    actor: CommerceActor,
    ticketOrderId: string,
    amountMinor: string,
    reason: string,
  ) {
    const ord = await this.pool.query<{
      id: string;
      subtotal_minor: string;
      platform_fee_minor: string;
      total_minor: string;
      organizer_id: string;
      status: string;
    }>(
      `SELECT id, subtotal_minor::text, platform_fee_minor::text, total_minor::text,
              organizer_id, status::text
       FROM ticket_orders WHERE id = $1 AND tenant_id = $2 AND buyer_user_id = $3`,
      [ticketOrderId, actor.tenantId, actor.userId],
    );
    const order = ord.rows[0];
    if (!order) {
      throw new NotFoundException({ code: 'ORDER_NOT_FOUND', message: 'Ticket order not found' });
    }
    if (!['fulfilled', 'confirmed'].includes(order.status)) {
      throw new UnprocessableEntityException({
        code: 'ORDER_NOT_REFUNDABLE',
        message: 'Order is not eligible for refund',
      });
    }

    const amount = BigInt(amountMinor);
    const subtotal = BigInt(order.subtotal_minor);
    if (amount <= 0n || amount > subtotal) {
      throw new UnprocessableEntityException({ code: 'INVALID_AMOUNT', message: 'Invalid refund amount' });
    }

    const feeReversal = computeFeeReversalMinor(
      Number(amount),
      Number(order.subtotal_minor),
      Number(order.platform_fee_minor),
    );

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO ticket_refund_cases (
         tenant_id, ticket_order_id, requested_by_user_id, status,
         amount_minor, platform_fee_reversal_minor, currency, reason
       ) SELECT $1, $2, $3, 'requested', $4::bigint, $5::bigint, tord.currency, $6
         FROM ticket_orders tord WHERE tord.id = $2
       RETURNING id`,
      [actor.tenantId, ticketOrderId, actor.userId, amount.toString(), feeReversal.toString(), reason],
    );
    return { id: rows[0]!.id, status: 'requested', platformFeeReversalMinor: feeReversal.toString() };
  }

  async adminAction(tenantId: string, caseId: string, action: TicketRefundAction, note?: string) {
    const row = await this.getCase(tenantId, caseId);
    const nextStatus = this.nextStatus(row.status, action);
    if (!nextStatus) {
      throw new UnprocessableEntityException({
        code: 'INVALID_TRANSITION',
        message: `Cannot ${action} from status ${row.status}`,
      });
    }

    await this.pool.query(
      `UPDATE ticket_refund_cases
       SET status = $3::ticket_refund_status,
           metadata = metadata || $4::jsonb,
           updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [
        caseId,
        tenantId,
        nextStatus,
        JSON.stringify({ last_action: action, note: note ?? null, at: new Date().toISOString() }),
      ],
    );

    if (nextStatus === 'completed') {
      const ledgerTxnId = await this.postRefundLedger(tenantId, caseId);
      await this.pool.query(
        `UPDATE ticket_entitlements SET status = 'refunded', updated_at = now()
         WHERE ticket_order_id = $1 AND tenant_id = $2 AND status = 'issued'`,
        [row.ticketOrderId, tenantId],
      );
      if (ledgerTxnId) {
        await this.pool.query(
          `UPDATE ticket_refund_cases
           SET metadata = metadata || $3::jsonb, updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [caseId, tenantId, JSON.stringify({ ledger_transaction_id: ledgerTxnId })],
        );
      }
    }

    return { id: caseId, status: nextStatus, action };
  }

  private async postRefundLedger(tenantId: string, caseId: string): Promise<string | null> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{
        id: string;
        ticket_order_id: string;
        amount_minor: string;
        platform_fee_reversal_minor: string;
        currency: string;
        organizer_id: string;
      }>(
        `SELECT trc.id, trc.ticket_order_id, trc.amount_minor::text,
                trc.platform_fee_reversal_minor::text, trc.currency, tord.organizer_id
         FROM ticket_refund_cases trc
         INNER JOIN ticket_orders tord ON tord.id = trc.ticket_order_id
         WHERE trc.id = $1 AND trc.tenant_id = $2
         FOR UPDATE`,
        [caseId, tenantId],
      );
      const c = rows[0];
      if (!c) {
        await client.query('ROLLBACK');
        return null;
      }

      const accounts = await this.ledger.ensurePoolLedgerAccounts(client, tenantId, c.currency);
      const organizerPayableId = await this.ledger.ensureOrganizerPayableAccount(
        client,
        tenantId,
        c.organizer_id,
        c.currency,
      );
      const txnId = await this.ledger.applyTicketRefundLedger(client, {
        tenantId,
        ticketOrderId: c.ticket_order_id,
        refundCaseId: c.id,
        organizerId: c.organizer_id,
        refundMinor: BigInt(c.amount_minor),
        feeReversalMinor: BigInt(c.platform_fee_reversal_minor),
        currency: c.currency,
        organizerPayableAccountId: organizerPayableId,
        escrowAccountId: accounts.escrowPoolId,
        platformFeesAccountId: accounts.platformFeesId,
        pspClearingAccountId: accounts.pspClearingId,
      });
      await client.query('COMMIT');
      return txnId;
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  private nextStatus(current: string, action: TicketRefundAction): string | null {
    if (action === 'escalate') {
      if (current === 'requested') return 'under_review';
      if (current === 'under_review') return 'under_review';
      return null;
    }
    if (action === 'approve') {
      if (['requested', 'under_review'].includes(current)) return 'approved';
      if (current === 'approved') return 'completed';
      return null;
    }
    if (action === 'reject') {
      if (['requested', 'under_review', 'approved'].includes(current)) return 'rejected';
      return null;
    }
    return null;
  }
}
