import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';

@Injectable()
export class AdminVendorsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async list(tenantId: string, query?: string, status?: string) {
    const params: unknown[] = [tenantId];
    let where = 'WHERE v.tenant_id = $1';
    if (status && status !== 'all') {
      params.push(status);
      where += ` AND v.status::text = $${params.length}`;
    }
    if (query?.trim()) {
      params.push(`%${query.trim().toLowerCase()}%`);
      where += ` AND (lower(v.business_name) LIKE $${params.length} OR lower(v.slug) LIKE $${params.length})`;
    }
    const { rows } = await this.pool.query<{
      id: string;
      business_name: string;
      slug: string;
      status: string;
      city: string | null;
      participation_count: string;
      revenue_minor: string;
    }>(
      `SELECT v.id, v.business_name, v.slug, v.status::text, v.city,
              (SELECT COUNT(*)::text FROM vendor_event_participations vep WHERE vep.vendor_id = v.id) AS participation_count,
              COALESCE((
                SELECT SUM(p.amount_captured_minor)::text
                FROM payments p
                INNER JOIN bookings b ON b.id = p.booking_id
                WHERE b.vendor_id = v.id AND p.status::text IN ('captured', 'partially_refunded', 'refunded')
              ), '0') AS revenue_minor
       FROM vendors v
       ${where}
       ORDER BY v.created_at DESC
       LIMIT 200`,
      params,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        businessName: r.business_name,
        slug: r.slug,
        status: r.status,
        city: r.city ?? '',
        participationCount: Number(r.participation_count),
        revenueMinor: r.revenue_minor,
      })),
    };
  }

  async getDetail(tenantId: string, vendorId: string) {
    const vendor = await this.getVendor(tenantId, vendorId);
    const [participations, orders, wallet, payouts] = await Promise.all([
      this.pool.query(
        `SELECT vep.id, vep.status::text, e.title, e.external_ref, e.starts_at
         FROM vendor_event_participations vep
         INNER JOIN events e ON e.id = vep.event_id
         WHERE vep.tenant_id = $1 AND vep.vendor_id = $2
         ORDER BY e.starts_at DESC`,
        [tenantId, vendorId],
      ),
      this.pool.query(
        `SELECT b.id, b.status::text, b.total_minor::text, b.created_at, b.location_text
         FROM bookings b
         WHERE b.tenant_id = $1 AND b.vendor_id = $2
         ORDER BY b.created_at DESC LIMIT 50`,
        [tenantId, vendorId],
      ),
      this.vendorWallet(tenantId, vendorId),
      this.pool.query(
        `SELECT id, amount_minor::text, status::text, created_at
         FROM payouts WHERE tenant_id = $1 AND vendor_id = $2 ORDER BY created_at DESC LIMIT 50`,
        [tenantId, vendorId],
      ),
    ]);
    const revenue = await this.vendorRevenue(tenantId, vendorId);
    return {
      profile: {
        id: vendor.id,
        businessName: vendor.business_name,
        slug: vendor.slug,
        status: vendor.status,
        city: vendor.city ?? '',
        description: vendor.description ?? '',
        ownerUserId: vendor.owner_user_id,
      },
      revenue,
      participations: participations.rows.map((p) => ({
        id: p.id,
        status: p.status,
        eventTitle: p.title,
        eventId: p.external_ref ?? '',
        startsAt: p.starts_at.toISOString(),
      })),
      orders: orders.rows.map((o) => ({
        id: o.id,
        status: o.status,
        amountMinor: o.total_minor,
        eventTitle: o.location_text ?? '',
        createdAt: o.created_at.toISOString(),
      })),
      wallet,
      payouts: payouts.rows.map((p) => ({
        id: p.id,
        amountMinor: p.amount_minor,
        status: p.status,
        createdAt: p.created_at.toISOString(),
      })),
    };
  }

  async setStatus(
    tenantId: string,
    actorUserId: string,
    vendorId: string,
    status: 'active' | 'suspended',
    reason?: string,
  ) {
    const vendor = await this.getVendor(tenantId, vendorId);
    await this.pool.query(
      `UPDATE vendors SET status = $3::vendor_status,
         suspended_reason = CASE WHEN $3::text = 'suspended' THEN $4 ELSE NULL END,
         updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [vendorId, tenantId, status, reason ?? 'Admin action'],
    );
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: status === 'suspended' ? 'vendor_suspended' : status === 'active' ? 'vendor_approved' : 'vendor_reactivated',
      resourceType: 'vendor',
      resourceId: vendorId,
      metadata: { previousStatus: vendor.status, businessName: vendor.business_name, reason },
    });
    return { ok: true, status };
  }

  private async vendorRevenue(tenantId: string, vendorId: string) {
    const { rows } = await this.pool.query<{ booking_minor: string }>(
      `SELECT COALESCE(SUM(amount_captured_minor), 0)::text AS booking_minor
       FROM payments p
       INNER JOIN bookings b ON b.id = p.booking_id
       WHERE p.tenant_id = $1 AND b.vendor_id = $2
         AND p.status::text IN ('captured', 'partially_refunded', 'refunded')`,
      [tenantId, vendorId],
    );
    return { bookingRevenueMinor: rows[0]?.booking_minor ?? '0', ticketRevenueMinor: '0' };
  }

  private async vendorWallet(tenantId: string, vendorId: string) {
    const { rows } = await this.pool.query<{ available: string; pending: string }>(
      `SELECT
         COALESCE(SUM(CASE WHEN p.status::text = 'captured' THEN p.amount_captured_minor ELSE 0 END), 0)::text AS available,
         COALESCE(SUM(CASE WHEN po.status::text IN ('pending', 'processing') THEN po.amount_minor ELSE 0 END), 0)::text AS pending
       FROM vendors v
       LEFT JOIN bookings b ON b.vendor_id = v.id
       LEFT JOIN payments p ON p.booking_id = b.id AND p.tenant_id = $1
       LEFT JOIN payouts po ON po.vendor_id = v.id AND po.tenant_id = $1
       WHERE v.id = $2 AND v.tenant_id = $1`,
      [tenantId, vendorId],
    );
    return {
      availableMinor: rows[0]?.available ?? '0',
      pendingMinor: rows[0]?.pending ?? '0',
    };
  }

  private async getVendor(tenantId: string, vendorId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      business_name: string;
      slug: string;
      status: string;
      city: string | null;
      description: string | null;
      owner_user_id: string;
    }>(
      `SELECT id, business_name, slug, status::text, city, description, owner_user_id
       FROM vendors WHERE tenant_id = $1 AND id = $2`,
      [tenantId, vendorId],
    );
    if (!rows[0]) throw new NotFoundException({ code: 'VENDOR_NOT_FOUND', message: 'Vendor not found' });
    return rows[0];
  }
}
