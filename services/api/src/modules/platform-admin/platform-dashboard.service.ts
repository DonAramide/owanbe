import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

export type PlatformHealth = 'healthy' | 'warning' | 'critical';

@Injectable()
export class PlatformDashboardService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getDashboard(tenantId: string) {
    const { rows } = await this.pool.query<{
      active_events: string;
      live_events: string;
      organizers: string;
      vendors: string;
      attendees: string;
      revenue_minor: string;
      open_incidents: string;
      recon_issues: string;
      critical_incidents: string;
    }>(
      `WITH ev AS (
         SELECT status::text FROM events WHERE tenant_id = $1
       ),
       ticket_rev AS (
         SELECT COALESCE(SUM(tol.quantity * tol.unit_price_minor), 0)::text AS minor
         FROM ticket_order_lines tol
         INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
         WHERE tord.tenant_id = $1 AND tord.status IN ('fulfilled', 'confirmed')
       ),
       booking_rev AS (
         SELECT COALESCE(SUM(amount_captured_minor), 0)::text AS minor
         FROM payments
         WHERE tenant_id = $1 AND status::text IN ('captured', 'partially_refunded', 'refunded')
       )
       SELECT
         (SELECT COUNT(*)::text FROM ev WHERE status IN ('published', 'live')) AS active_events,
         (SELECT COUNT(*)::text FROM ev WHERE status = 'live') AS live_events,
         (SELECT COUNT(*)::text FROM organizers WHERE tenant_id = $1 AND status::text = 'active') AS organizers,
         (SELECT COUNT(*)::text FROM vendors WHERE tenant_id = $1 AND status::text = 'active') AS vendors,
         (SELECT COUNT(*)::text FROM ticket_entitlements WHERE tenant_id = $1 AND status IN ('issued', 'checked_in')) AS attendees,
         (
           (SELECT minor::bigint FROM ticket_rev) + (SELECT minor::bigint FROM booking_rev)
         )::text AS revenue_minor,
         (SELECT COUNT(*)::text FROM event_incidents WHERE tenant_id = $1 AND status::text = 'open') AS open_incidents,
         (SELECT COUNT(*)::text FROM reconciliation_reports WHERE tenant_id = $1 AND resolution_status::text = 'open') AS recon_issues,
         (SELECT COUNT(*)::text FROM event_incidents WHERE tenant_id = $1 AND status::text = 'open' AND priority::text = 'critical') AS critical_incidents`,
      [tenantId],
    );
    const s = rows[0]!;
    const openIncidents = Number(s.open_incidents);
    const reconIssues = Number(s.recon_issues);
    const criticalIncidents = Number(s.critical_incidents);
    const health = this.computeHealth(criticalIncidents, openIncidents, reconIssues);
    return {
      activeEvents: Number(s.active_events),
      liveEvents: Number(s.live_events),
      organizers: Number(s.organizers),
      vendors: Number(s.vendors),
      attendees: Number(s.attendees),
      revenueMinor: s.revenue_minor,
      openIncidents,
      reconciliationIssues: reconIssues,
      platformHealth: health,
      healthSummary: this.healthSummary(health, criticalIncidents, openIncidents, reconIssues),
    };
  }

  private computeHealth(critical: number, openIncidents: number, recon: number): PlatformHealth {
    if (critical > 0 || recon > 5) return 'critical';
    if (openIncidents > 0 || recon > 0) return 'warning';
    return 'healthy';
  }

  private healthSummary(health: PlatformHealth, critical: number, open: number, recon: number): string {
    if (health === 'critical') {
      return `${critical} critical incident(s), ${recon} reconciliation issue(s)`;
    }
    if (health === 'warning') {
      return `${open} open incident(s), ${recon} reconciliation issue(s)`;
    }
    return 'All systems nominal';
  }
}
