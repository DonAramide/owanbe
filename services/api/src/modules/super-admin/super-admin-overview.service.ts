import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

export type PlatformHealth = 'healthy' | 'warning' | 'critical';

@Injectable()
export class SuperAdminOverviewService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getOverview() {
    const { rows } = await this.pool.query<{
      total_events: string;
      total_organizers: string;
      total_vendors: string;
      total_attendees: string;
      platform_revenue_minor: string;
      platform_fees_minor: string;
      active_incidents: string;
      recon_issues: string;
      critical_incidents: string;
    }>(
      `WITH ticket_rev AS (
         SELECT COALESCE(SUM(tol.quantity * tol.unit_price_minor), 0)::bigint AS minor
         FROM ticket_order_lines tol
         INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
         WHERE tord.status IN ('fulfilled', 'confirmed')
       ),
       booking_rev AS (
         SELECT COALESCE(SUM(amount_captured_minor), 0)::bigint AS minor
         FROM payments
         WHERE status::text IN ('captured', 'partially_refunded', 'refunded')
       ),
       ticket_fees AS (
         SELECT COALESCE(SUM(
           (tol.quantity * tol.unit_price_minor * COALESCE(tfs.ticket_platform_fee_bps, 500)) / 10000
         ), 0)::bigint AS minor
         FROM ticket_order_lines tol
         INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
         INNER JOIN tenant_finance_settings tfs ON tfs.tenant_id = tord.tenant_id
         WHERE tord.status IN ('fulfilled', 'confirmed')
       ),
       booking_fees AS (
         SELECT COALESCE(SUM(
           (p.amount_captured_minor * COALESCE(tfs.vendor_platform_fee_bps, 500)) / 10000
         ), 0)::bigint AS minor
         FROM payments p
         INNER JOIN tenant_finance_settings tfs ON tfs.tenant_id = p.tenant_id
         WHERE p.status::text IN ('captured', 'partially_refunded', 'refunded')
       )
       SELECT
         (SELECT COUNT(*)::text FROM events) AS total_events,
         (SELECT COUNT(*)::text FROM organizers WHERE status::text = 'active') AS total_organizers,
         (SELECT COUNT(*)::text FROM vendors WHERE status::text = 'active') AS total_vendors,
         (SELECT COUNT(*)::text FROM ticket_entitlements WHERE status IN ('issued', 'checked_in')) AS total_attendees,
         ((SELECT minor FROM ticket_rev) + (SELECT minor FROM booking_rev))::text AS platform_revenue_minor,
         ((SELECT minor FROM ticket_fees) + (SELECT minor FROM booking_fees))::text AS platform_fees_minor,
         (SELECT COUNT(*)::text FROM event_incidents WHERE status::text = 'open') AS active_incidents,
         (SELECT COUNT(*)::text FROM reconciliation_reports WHERE resolution_status::text = 'open') AS recon_issues,
         (SELECT COUNT(*)::text FROM event_incidents WHERE status::text = 'open' AND priority::text = 'critical') AS critical_incidents`,
    );
    const s = rows[0]!;
    const activeIncidents = Number(s.active_incidents);
    const reconIssues = Number(s.recon_issues);
    const criticalIncidents = Number(s.critical_incidents);
    const health = this.computeHealth(criticalIncidents, activeIncidents, reconIssues);
    return {
      totalEvents: Number(s.total_events),
      totalOrganizers: Number(s.total_organizers),
      totalVendors: Number(s.total_vendors),
      totalAttendees: Number(s.total_attendees),
      platformRevenueMinor: s.platform_revenue_minor,
      platformFeesMinor: s.platform_fees_minor,
      activeIncidents,
      reconciliationIssues: reconIssues,
      platformHealth: health,
      healthSummary: this.healthSummary(health, criticalIncidents, activeIncidents, reconIssues),
    };
  }

  private computeHealth(critical: number, incidents: number, recon: number): PlatformHealth {
    if (critical > 0 || recon > 10) return 'critical';
    if (incidents > 0 || recon > 0) return 'warning';
    return 'healthy';
  }

  private healthSummary(health: PlatformHealth, critical: number, incidents: number, recon: number): string {
    if (health === 'critical') {
      return `${critical} critical incident(s), ${recon} reconciliation issue(s) platform-wide`;
    }
    if (health === 'warning') {
      return `${incidents} active incident(s), ${recon} reconciliation issue(s)`;
    }
    return 'Platform-wide systems nominal';
  }
}
