import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';

@Injectable()
export class SuperAdminTenantsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async list(query?: string, status?: string) {
    const params: unknown[] = [];
    let where = 'WHERE 1=1';
    if (status && status !== 'all') {
      params.push(status);
      where += ` AND t.status = $${params.length}`;
    }
    if (query?.trim()) {
      params.push(`%${query.trim().toLowerCase()}%`);
      where += ` AND (lower(t.name) LIKE $${params.length} OR lower(t.slug) LIKE $${params.length})`;
    }
    const { rows } = await this.pool.query<{
      id: string;
      slug: string;
      name: string;
      status: string;
      event_count: string;
      organizer_count: string;
      revenue_minor: string;
    }>(
      `SELECT t.id, t.slug, t.name, t.status,
              (SELECT COUNT(*)::text FROM events e WHERE e.tenant_id = t.id) AS event_count,
              (SELECT COUNT(*)::text FROM organizers o WHERE o.tenant_id = t.id) AS organizer_count,
              COALESCE((
                SELECT (
                  COALESCE((SELECT SUM(tol.quantity * tol.unit_price_minor) FROM ticket_order_lines tol
                    INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
                    WHERE tord.tenant_id = t.id AND tord.status IN ('fulfilled', 'confirmed')), 0)
                  + COALESCE((SELECT SUM(amount_captured_minor) FROM payments p
                    WHERE p.tenant_id = t.id AND p.status::text IN ('captured', 'partially_refunded', 'refunded')), 0)
                )::text
              ), '0') AS revenue_minor
       FROM tenants t
       ${where}
       ORDER BY t.created_at DESC
       LIMIT 200`,
      params,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        slug: r.slug,
        name: r.name,
        status: r.status,
        eventCount: Number(r.event_count),
        organizerCount: Number(r.organizer_count),
        revenueMinor: r.revenue_minor,
      })),
    };
  }

  async create(actorUserId: string, body: { slug: string; name: string }) {
    const slug = body.slug.trim().toLowerCase();
    const name = body.name.trim();
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO tenants (slug, name, status)
       VALUES ($1, $2, 'active')
       RETURNING id`,
      [slug, name],
    );
    const tenantId = rows[0]!.id;
    await this.pool.query(
      `INSERT INTO tenant_finance_settings (tenant_id) VALUES ($1) ON CONFLICT DO NOTHING`,
      [tenantId],
    );
    const flags = ['ticket_commerce', 'vendor_commerce', 'live_operations', 'finance', 'reconciliation'];
    for (const flag of flags) {
      await this.pool.query(
        `INSERT INTO tenant_feature_flags (tenant_id, flag_key, enabled, updated_by)
         VALUES ($1, $2, true, $3::uuid) ON CONFLICT DO NOTHING`,
        [tenantId, flag, actorUserId],
      );
    }
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'tenant_created',
      resourceType: 'tenant',
      resourceId: tenantId,
      metadata: { slug, name },
    });
    return { id: tenantId, slug, name, status: 'active' };
  }

  async setStatus(actorUserId: string, tenantId: string, status: 'active' | 'suspended') {
    const tenant = await this.getTenant(tenantId);
    await this.pool.query(`UPDATE tenants SET status = $2, updated_at = now() WHERE id = $1`, [
      tenantId,
      status,
    ]);
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: status === 'suspended' ? 'tenant_suspended' : 'tenant_reactivated',
      resourceType: 'tenant',
      resourceId: tenantId,
      metadata: { previousStatus: tenant.status, slug: tenant.slug },
    });
    return { ok: true, status };
  }

  async getDetail(tenantId: string) {
    const tenant = await this.getTenant(tenantId);
    const [events, organizers, finance, usage, compliance] = await Promise.all([
      this.pool.query(
        `SELECT id, external_ref, title, status::text, starts_at
         FROM events WHERE tenant_id = $1 ORDER BY starts_at DESC LIMIT 50`,
        [tenantId],
      ),
      this.pool.query(
        `SELECT id, display_name, slug, status::text FROM organizers WHERE tenant_id = $1 LIMIT 50`,
        [tenantId],
      ),
      this.tenantFinance(tenantId),
      this.tenantUsage(tenantId),
      this.tenantCompliance(tenantId),
    ]);
    const health = this.tenantHealth(usage.rows[0], compliance.rows[0]);
    return {
      profile: {
        id: tenant.id,
        slug: tenant.slug,
        name: tenant.name,
        status: tenant.status,
        createdAt: tenant.created_at.toISOString(),
      },
      health,
      events: events.rows.map((e) => ({
        id: e.external_ref ?? e.id,
        title: e.title,
        status: e.status,
        startsAt: e.starts_at.toISOString(),
      })),
      organizers: organizers.rows.map((o) => ({
        id: o.id,
        displayName: o.display_name,
        slug: o.slug,
        status: o.status,
      })),
      finance,
      usage: usage.rows[0],
      compliance: compliance.rows[0],
    };
  }

  private async getTenant(tenantId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      slug: string;
      name: string;
      status: string;
      created_at: Date;
    }>(`SELECT id, slug, name, status, created_at FROM tenants WHERE id = $1`, [tenantId]);
    if (!rows[0]) throw new NotFoundException({ code: 'TENANT_NOT_FOUND', message: 'Tenant not found' });
    return rows[0];
  }

  private async tenantFinance(tenantId: string) {
    const { rows } = await this.pool.query<{
      ticket_minor: string;
      booking_minor: string;
      fees_minor: string;
    }>(
      `SELECT
         COALESCE((SELECT SUM(tol.quantity * tol.unit_price_minor)::text
           FROM ticket_order_lines tol INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
           WHERE tord.tenant_id = $1 AND tord.status IN ('fulfilled', 'confirmed')), '0') AS ticket_minor,
         COALESCE((SELECT SUM(amount_captured_minor)::text FROM payments
           WHERE tenant_id = $1 AND status::text IN ('captured', 'partially_refunded', 'refunded')), '0') AS booking_minor,
         COALESCE((
           COALESCE((SELECT SUM((tol.quantity * tol.unit_price_minor * COALESCE(tfs.ticket_platform_fee_bps, 500)) / 10000)
             FROM ticket_order_lines tol INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
             INNER JOIN tenant_finance_settings tfs ON tfs.tenant_id = tord.tenant_id
             WHERE tord.tenant_id = $1 AND tord.status IN ('fulfilled', 'confirmed')), 0)
           + COALESCE((SELECT SUM((p.amount_captured_minor * COALESCE(tfs.vendor_platform_fee_bps, 500)) / 10000)
             FROM payments p INNER JOIN tenant_finance_settings tfs ON tfs.tenant_id = p.tenant_id
             WHERE p.tenant_id = $1 AND p.status::text IN ('captured', 'partially_refunded', 'refunded')), 0)
         )::text, '0') AS fees_minor`,
      [tenantId],
    );
    const r = rows[0]!;
    return {
      ticketRevenueMinor: r.ticket_minor,
      bookingRevenueMinor: r.booking_minor,
      platformFeesMinor: r.fees_minor,
      totalRevenueMinor: String(BigInt(r.ticket_minor) + BigInt(r.booking_minor)),
    };
  }

  private async tenantUsage(tenantId: string) {
    return this.pool.query<{
      events: string;
      organizers: string;
      vendors: string;
      attendees: string;
      open_incidents: string;
    }>(
      `SELECT
         (SELECT COUNT(*)::text FROM events WHERE tenant_id = $1) AS events,
         (SELECT COUNT(*)::text FROM organizers WHERE tenant_id = $1) AS organizers,
         (SELECT COUNT(*)::text FROM vendors WHERE tenant_id = $1) AS vendors,
         (SELECT COUNT(*)::text FROM ticket_entitlements WHERE tenant_id = $1) AS attendees,
         (SELECT COUNT(*)::text FROM event_incidents WHERE tenant_id = $1 AND status::text = 'open') AS open_incidents`,
      [tenantId],
    );
  }

  private async tenantCompliance(tenantId: string) {
    return this.pool.query<{
      open_recon: string;
      audit_events_30d: string;
      suspended_organizers: string;
    }>(
      `SELECT
         (SELECT COUNT(*)::text FROM reconciliation_reports WHERE tenant_id = $1 AND resolution_status::text = 'open') AS open_recon,
         (SELECT COUNT(*)::text FROM audit_log WHERE tenant_id = $1 AND created_at >= now() - interval '30 days') AS audit_events_30d,
         (SELECT COUNT(*)::text FROM organizers WHERE tenant_id = $1 AND status::text = 'suspended') AS suspended_organizers`,
      [tenantId],
    );
  }

  private tenantHealth(
    usage?: { open_incidents: string },
    compliance?: { open_recon: string },
  ): { level: string; summary: string } {
    const incidents = Number(usage?.open_incidents ?? 0);
    const recon = Number(compliance?.open_recon ?? 0);
    if (recon > 5) return { level: 'critical', summary: `${recon} open reconciliation issues` };
    if (incidents > 0 || recon > 0) return { level: 'warning', summary: `${incidents} incidents, ${recon} recon issues` };
    return { level: 'healthy', summary: 'Tenant health nominal' };
  }
}
