import {
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';
import { BookingAccessService } from '../../ownership/booking-access.service';
import { VendorAccessService } from '../../ownership/vendor-access.service';
import { FinancialAdjustmentsService } from './financial-adjustments.service';
import { PayoutService } from './payout.service';

@Injectable()
export class DisputesService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
    private readonly bookingAccess: BookingAccessService,
    private readonly vendorAccess: VendorAccessService,
    private readonly adjustments: FinancialAdjustmentsService,
    private readonly payouts: PayoutService,
  ) {}

  private async disputeForTenant(tenantId: string, disputeId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      booking_id: string;
      payment_id: string;
      client_user_id: string;
      vendor_id: string;
      status: string;
      outcome: string;
      amount_claimed_minor: string | null;
      resolution_amount_minor: string | null;
    }>(
      `SELECT id, booking_id, payment_id, client_user_id, vendor_id, status::text, outcome::text,
              amount_claimed_minor::text, resolution_amount_minor::text
       FROM disputes
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, disputeId],
    );
    return rows[0] ?? null;
  }

  private async assertParticipant(params: {
    tenantId: string;
    disputeId: string;
    actorUserId: string;
    actorRoles: string[];
  }) {
    const d = await this.disputeForTenant(params.tenantId, params.disputeId);
    if (!d) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Dispute not found' });
    const isAdmin = params.actorRoles.some((r) => r.startsWith('admin_'));
    if (isAdmin) return d;
    if (d.client_user_id === params.actorUserId) return d;
    try {
      await this.vendorAccess.assertVendorOwnerOrStaff(
        params.tenantId,
        d.vendor_id,
        params.actorUserId,
        { allowSuspendedRead: true },
      );
      return d;
    } catch {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Dispute access denied' });
    }
  }

  async ensureParticipantAccess(params: {
    tenantId: string;
    disputeId: string;
    actorUserId: string;
    actorRoles: string[];
  }) {
    await this.assertParticipant(params);
  }

  async createDispute(params: {
    tenantId: string;
    actorUserId: string;
    bookingId: string;
    reason: string;
    description: string;
    amountClaimedMinor?: string;
    idempotencyKey?: string;
  }) {
    await this.bookingAccess.assertClientOwnsBooking(params.tenantId, params.bookingId, params.actorUserId);
    const { rows: bookingRows } = await this.pool.query<{
      id: string;
      client_user_id: string;
      vendor_id: string;
      currency: string;
      total_minor: string;
    }>(
      `SELECT id, client_user_id, vendor_id, currency, total_minor::text
       FROM bookings
       WHERE tenant_id = $1 AND id = $2`,
      [params.tenantId, params.bookingId],
    );
    const booking = bookingRows[0];
    if (!booking) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Booking not found' });

    const { rows: paymentRows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM payments
       WHERE tenant_id = $1 AND booking_id = $2
       ORDER BY created_at DESC
       LIMIT 1`,
      [params.tenantId, params.bookingId],
    );
    const paymentId = paymentRows[0]?.id;
    if (!paymentId) {
      throw new UnprocessableEntityException({
        code: 'PAYMENT_REQUIRED',
        message: 'Booking has no payment to dispute',
      });
    }

    const idem = params.idempotencyKey?.trim() || null;
    if (idem) {
      const existing = await this.pool.query<{ id: string }>(
        `SELECT id FROM disputes WHERE tenant_id = $1 AND idempotency_key = $2`,
        [params.tenantId, idem],
      );
      if (existing.rows[0]?.id) {
        return this.getDisputeDetails(params.tenantId, existing.rows[0].id);
      }
    }

    const { rows } = await this.pool.query(
      `INSERT INTO disputes (
         tenant_id, booking_id, payment_id, opened_by_user_id, client_user_id, vendor_id,
         status, outcome, reason, title, description, amount_claimed_minor, currency, idempotency_key
       ) VALUES (
         $1, $2, $3, $4, $5, $6,
         'open', 'pending', $7, $7, $8, $9::bigint, $10, $11
       )
       RETURNING id`,
      [
        params.tenantId,
        params.bookingId,
        paymentId,
        params.actorUserId,
        booking.client_user_id,
        booking.vendor_id,
        params.reason.trim(),
        params.description.trim(),
        params.amountClaimedMinor ?? booking.total_minor,
        booking.currency,
        idem,
      ],
    );
    const disputeId = rows[0]?.id as string;

    await this.audit.logAction({
      tenantId: params.tenantId,
      actorUserId: params.actorUserId,
      action: 'DISPUTE_CREATE',
      resourceType: 'dispute',
      resourceId: disputeId,
      metadata: { bookingId: params.bookingId, paymentId, reason: params.reason },
    });
    return this.getDisputeDetails(params.tenantId, disputeId);
  }

  async listAdminDisputes(tenantId: string, page = 1, limit = 50) {
    const offset = (page - 1) * limit;
    const [{ rows: countRows }, { rows: items }] = await Promise.all([
      this.pool.query<{ total: string }>(
        `SELECT COUNT(*)::text AS total FROM disputes WHERE tenant_id = $1`,
        [tenantId],
      ),
      this.pool.query(
        `SELECT d.id, d.booking_id, d.payment_id, d.client_user_id, d.vendor_id,
                d.reason, d.status::text, d.outcome::text, d.amount_claimed_minor::text, d.currency,
                d.created_at, d.updated_at
         FROM disputes d
         WHERE d.tenant_id = $1
         ORDER BY d.created_at DESC
         OFFSET $2 LIMIT $3`,
        [tenantId, offset, limit],
      ),
    ]);
    const total = Number(countRows[0]?.total ?? 0);
    return { items, total, totalPages: Math.max(1, Math.ceil(total / limit)), page, limit };
  }

  async listMyDisputes(tenantId: string, actorUserId: string, actorRoles: string[], limit = 50) {
    if (actorRoles.some((r) => r.startsWith('admin_'))) {
      return this.listAdminDisputes(tenantId, 1, limit);
    }
    if (actorRoles.includes('client')) {
      const { rows } = await this.pool.query(
        `SELECT id, booking_id, payment_id, reason, status::text, outcome::text,
                amount_claimed_minor::text, currency, created_at, updated_at
         FROM disputes
         WHERE tenant_id = $1 AND client_user_id = $2
         ORDER BY created_at DESC
         LIMIT $3`,
        [tenantId, actorUserId, limit],
      );
      return { items: rows, total: rows.length, totalPages: 1, page: 1, limit };
    }
    const { rows } = await this.pool.query(
      `SELECT d.id, d.booking_id, d.payment_id, d.reason, d.status::text, d.outcome::text,
              d.amount_claimed_minor::text, d.currency, d.created_at, d.updated_at
       FROM disputes d
       WHERE d.tenant_id = $1
         AND EXISTS (
           SELECT 1 FROM vendors v
           WHERE v.id = d.vendor_id
             AND (v.owner_user_id = $2 OR EXISTS (
               SELECT 1 FROM vendor_users vu WHERE vu.vendor_id = v.id AND vu.user_id = $2
             ))
         )
       ORDER BY d.created_at DESC
       LIMIT $3`,
      [tenantId, actorUserId, limit],
    );
    return { items: rows, total: rows.length, totalPages: 1, page: 1, limit };
  }

  async getDisputeDetails(tenantId: string, disputeId: string) {
    const { rows: disputeRows } = await this.pool.query(
      `SELECT d.*
       FROM disputes d
       WHERE d.tenant_id = $1 AND d.id = $2`,
      [tenantId, disputeId],
    );
    const dispute = disputeRows[0];
    if (!dispute) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Dispute not found' });
    const [{ rows: messages }, { rows: evidence }] = await Promise.all([
      this.pool.query(
        `SELECT id, sender_type, sender_user_id, message, attachments, created_at
         FROM dispute_messages
         WHERE tenant_id = $1 AND dispute_id = $2
         ORDER BY created_at ASC`,
        [tenantId, disputeId],
      ),
      this.pool.query(
        `SELECT id, type, url, uploaded_by, metadata, created_at
         FROM dispute_evidence
         WHERE tenant_id = $1 AND dispute_id = $2
         ORDER BY created_at DESC`,
        [tenantId, disputeId],
      ),
    ]);
    return { ...dispute, messages, evidence };
  }

  async addMessage(params: {
    tenantId: string;
    disputeId: string;
    actorUserId: string;
    actorRoles: string[];
    message: string;
    attachments?: unknown;
    idempotencyKey?: string;
  }) {
    const d = await this.assertParticipant(params);
    const senderType = params.actorRoles.some((r) => r.startsWith('admin_'))
      ? 'admin'
      : d.client_user_id === params.actorUserId
        ? 'client'
        : 'vendor';
    const idem = params.idempotencyKey?.trim() || null;
    if (idem) {
      const existing = await this.pool.query<{ id: string }>(
        `SELECT id FROM dispute_messages
         WHERE tenant_id = $1 AND dispute_id = $2 AND idempotency_key = $3`,
        [params.tenantId, params.disputeId, idem],
      );
      if (existing.rows[0]?.id) return { status: 'ok', updatedEntity: existing.rows[0] };
    }
    const { rows } = await this.pool.query(
      `INSERT INTO dispute_messages (
         tenant_id, dispute_id, sender_type, sender_user_id, message, attachments, idempotency_key
       ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)
       RETURNING id`,
      [
        params.tenantId,
        params.disputeId,
        senderType,
        params.actorUserId,
        params.message.trim(),
        JSON.stringify(params.attachments ?? []),
        idem,
      ],
    );
    await this.pool.query(
      `UPDATE disputes
       SET status = CASE WHEN status::text='open' THEN 'under_review'::dispute_status ELSE status END,
           updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [params.tenantId, params.disputeId],
    );
    await this.audit.logAction({
      tenantId: params.tenantId,
      actorUserId: params.actorUserId,
      action: 'DISPUTE_ADD_MESSAGE',
      resourceType: 'dispute',
      resourceId: params.disputeId,
      metadata: { messageId: rows[0]?.id, senderType },
    });
    return { status: 'ok', updatedEntity: await this.getDisputeDetails(params.tenantId, params.disputeId) };
  }

  async uploadEvidence(params: {
    tenantId: string;
    disputeId: string;
    actorUserId: string;
    actorRoles: string[];
    type: 'image' | 'video' | 'document';
    url: string;
    metadata?: Record<string, unknown>;
    idempotencyKey?: string;
  }) {
    await this.assertParticipant(params);
    const idem = params.idempotencyKey?.trim() || null;
    if (idem) {
      const existing = await this.pool.query<{ id: string }>(
        `SELECT id FROM dispute_evidence
         WHERE tenant_id = $1 AND dispute_id = $2 AND idempotency_key = $3`,
        [params.tenantId, params.disputeId, idem],
      );
      if (existing.rows[0]?.id) return { status: 'ok', updatedEntity: existing.rows[0] };
    }
    await this.pool.query(
      `INSERT INTO dispute_evidence (
         tenant_id, dispute_id, type, url, uploaded_by, metadata, idempotency_key
       ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)`,
      [
        params.tenantId,
        params.disputeId,
        params.type,
        params.url.trim(),
        params.actorUserId,
        JSON.stringify(params.metadata ?? {}),
        idem,
      ],
    );
    await this.pool.query(
      `UPDATE disputes SET status = 'awaiting_evidence', updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [params.tenantId, params.disputeId],
    );
    await this.audit.logAction({
      tenantId: params.tenantId,
      actorUserId: params.actorUserId,
      action: 'DISPUTE_UPLOAD_EVIDENCE',
      resourceType: 'dispute',
      resourceId: params.disputeId,
      metadata: { type: params.type, url: params.url },
    });
    return { status: 'ok', updatedEntity: await this.getDisputeDetails(params.tenantId, params.disputeId) };
  }

  async resolveDispute(params: {
    tenantId: string;
    disputeId: string;
    actorUserId: string;
    resolution: 'client_win' | 'vendor_win' | 'partial';
    refundAmountMinor?: string;
    note?: string;
    releaseVendorPayout?: boolean;
  }) {
    const d = await this.disputeForTenant(params.tenantId, params.disputeId);
    if (!d) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Dispute not found' });
    if (d.status === 'resolved' || d.status === 'closed') {
      return { status: 'ok', updatedEntity: await this.getDisputeDetails(params.tenantId, params.disputeId) };
    }
    let refundResult: unknown = null;
    if (params.resolution === 'client_win') {
      refundResult = await this.adjustments.refundPayment({
        tenantId: params.tenantId,
        paymentId: d.payment_id,
        actorUserId: params.actorUserId,
        amountMinor: params.refundAmountMinor,
        reason: params.note ?? 'dispute_client_win',
        idempotencyKey: `dispute-resolve:${params.disputeId}:client_win`,
      });
    }
    if (params.resolution === 'partial') {
      if (!params.refundAmountMinor) {
        throw new UnprocessableEntityException({
          code: 'REFUND_AMOUNT_REQUIRED',
          message: 'refundAmountMinor is required for partial resolution',
        });
      }
      refundResult = await this.adjustments.refundPayment({
        tenantId: params.tenantId,
        paymentId: d.payment_id,
        actorUserId: params.actorUserId,
        amountMinor: params.refundAmountMinor,
        reason: params.note ?? 'dispute_partial',
        idempotencyKey: `dispute-resolve:${params.disputeId}:partial:${params.refundAmountMinor}`,
      });
    }

    let payoutResult: unknown = null;
    if (params.resolution === 'vendor_win' || params.releaseVendorPayout) {
      const eligible = await this.payouts.findEligiblePayouts(params.tenantId, 100);
      const row = eligible.find((e) => e.booking_id === d.booking_id);
      if (row) payoutResult = await this.payouts.enqueuePayoutForBooking(row, { adminOverride: true });
    }

    const outcome =
      params.resolution === 'client_win'
        ? 'favor_client'
        : params.resolution === 'vendor_win'
          ? 'favor_vendor'
          : 'split';
    await this.pool.query(
      `UPDATE disputes
       SET status = 'resolved',
           outcome = $3::dispute_outcome,
           resolution_notes = $4,
           resolution_amount_minor = $5::bigint,
           resolved_at = now(),
           updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [
        params.tenantId,
        params.disputeId,
        outcome,
        params.note ?? null,
        params.refundAmountMinor ?? d.amount_claimed_minor ?? null,
      ],
    );
    await this.audit.logAction({
      tenantId: params.tenantId,
      actorUserId: params.actorUserId,
      action: 'DISPUTE_RESOLVE',
      resourceType: 'dispute',
      resourceId: params.disputeId,
      metadata: { resolution: params.resolution, refundResult, payoutResult },
    });
    return { status: 'ok', updatedEntity: await this.getDisputeDetails(params.tenantId, params.disputeId) };
  }
}
