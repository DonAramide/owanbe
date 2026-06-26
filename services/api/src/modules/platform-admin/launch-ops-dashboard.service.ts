import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { HealthDetailService } from '../../integrations/observability/health-detail.service';
import { MetricsService } from '../../integrations/observability/metrics.service';
import { PlatformDashboardService } from './platform-dashboard.service';

function metricTotal(snapshot: Record<string, number>, prefix: string): number {
  return Object.entries(snapshot)
    .filter(([k]) => k.startsWith(prefix))
    .reduce((sum, [, v]) => sum + v, 0);
}

@Injectable()
export class LaunchOpsDashboardService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly health: HealthDetailService,
    private readonly metrics: MetricsService,
    private readonly platform: PlatformDashboardService,
  ) {}

  async getDashboard(tenantId: string) {
    const [health, platformDash, today] = await Promise.all([
      this.health.getDetailedHealth(),
      this.platform.getDashboard(tenantId),
      this.todayMetrics(tenantId),
    ]);
    const subsystems = await this.subsystemStatus(health);

    const snap = this.metrics.snapshot();
    const apiErrors = metricTotal(snap, 'api_errors_total');
    const invitationsSent = metricTotal(snap, 'invitations_sent_total');
    const invitationsFailed = metricTotal(snap, 'invitations_failed_total');
    const paymentsCaptured = metricTotal(snap, 'payments_captured_total');
    const notificationsSent = metricTotal(snap, 'notifications_sent_total');
    const notificationsFailed = metricTotal(snap, 'notifications_failed_total');
    const rsvpTotal = metricTotal(snap, 'rsvp_total') + metricTotal(snap, 'rsvp_confirmed_total');
    const storageUploads = metricTotal(snap, 'storage_proxy_upload_total');

    return {
      generatedAt: new Date().toISOString(),
      platformHealth: platformDash.platformHealth,
      healthSummary: platformDash.healthSummary,
      subsystems,
      health,
      todayMetrics: {
        ...today,
        rsvpRate:
          today.invitationsSentToday > 0
            ? Math.round((today.rsvpConfirmedToday / today.invitationsSentToday) * 100)
            : 0,
      },
      prometheus: {
        apiErrors,
        invitationsSent,
        invitationsFailed,
        paymentsCaptured,
        notificationsSent,
        notificationsFailed,
        rsvpTotal,
        storageUploads,
      },
      alerts: {
        failedPayments: today.failedPaymentsToday,
        apiErrors,
        openDisputes: platformDash.openIncidents,
        pendingVendorApprovals: today.pendingVendorApprovals,
        reconciliationIssues: platformDash.reconciliationIssues,
      },
      revenue: {
        ticketMinor: today.ticketRevenueMinor,
        rentalMinor: today.rentalRevenueMinor,
        asoEbiMinor: today.asoEbiRevenueMinor,
        totalMinor:
          today.ticketRevenueMinor + today.rentalRevenueMinor + today.asoEbiRevenueMinor,
      },
    };
  }

  private async todayMetrics(tenantId: string) {
    const { rows } = await this.pool.query<{
      events_today: string;
      invitations_sent: string;
      rsvp_confirmed: string;
      ticket_revenue: string;
      rental_revenue: string;
      aso_ebi_revenue: string;
      failed_payments: string;
      pending_vendors: string;
    }>(
      `SELECT
         (SELECT COUNT(*)::text FROM events
          WHERE tenant_id = $1 AND created_at >= date_trunc('day', now())) AS events_today,
         (SELECT COUNT(*)::text FROM event_invitations
          WHERE tenant_id = $1 AND sent_at >= date_trunc('day', now())) AS invitations_sent,
         (SELECT COUNT(*)::text FROM event_guests
          WHERE tenant_id = $1 AND rsvp_status = 'confirmed'
            AND updated_at >= date_trunc('day', now())) AS rsvp_confirmed,
         (SELECT COALESCE(SUM(tol.quantity * tol.unit_price_minor), 0)::text
          FROM ticket_order_lines tol
          INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
          WHERE tord.tenant_id = $1 AND tord.created_at >= date_trunc('day', now())
            AND tord.status IN ('fulfilled', 'confirmed')) AS ticket_revenue,
         (SELECT COALESCE(SUM(amount_captured_minor), 0)::text
          FROM payments
          WHERE tenant_id = $1 AND created_at >= date_trunc('day', now())
            AND metadata->>'rail' = 'rental' AND status::text = 'captured') AS rental_revenue,
         (SELECT COALESCE(SUM(amount_captured_minor), 0)::text
          FROM payments
          WHERE tenant_id = $1 AND created_at >= date_trunc('day', now())
            AND metadata->>'rail' = 'aso_ebi' AND status::text = 'captured') AS aso_ebi_revenue,
         (SELECT COUNT(*)::text FROM ticket_payments
          WHERE tenant_id = $1 AND created_at >= date_trunc('day', now())
            AND status::text IN ('failed', 'cancelled')) AS failed_payments,
         (SELECT COUNT(*)::text FROM vendor_applications
          WHERE tenant_id = $1 AND status::text IN ('under_review', 'applied')) AS pending_vendors`,
      [tenantId],
    );
    const r = rows[0]!;
    return {
      eventsToday: Number(r.events_today),
      invitationsSentToday: Number(r.invitations_sent),
      rsvpConfirmedToday: Number(r.rsvp_confirmed),
      ticketRevenueMinor: Number(r.ticket_revenue),
      rentalRevenueMinor: Number(r.rental_revenue),
      asoEbiRevenueMinor: Number(r.aso_ebi_revenue),
      failedPaymentsToday: Number(r.failed_payments),
      pendingVendorApprovals: Number(r.pending_vendors),
    };
  }

  private async subsystemStatus(
    health: Awaited<ReturnType<HealthDetailService['getDetailedHealth']>>,
  ) {
    const checks = health.checks;
    const tableOk = async (table: string) => {
      try {
        const { rows } = await this.pool.query('SELECT to_regclass($1) AS reg', [`public.${table}`]);
        return rows[0]?.reg != null;
      } catch {
        return false;
      }
    };

    const [seating, program, crm] = await Promise.all([
      tableOk('event_seating_layouts'),
      tableOk('event_program_items'),
      tableOk('vendor_event_requests'),
    ]);

    return {
      database: checks.database?.status ?? 'unknown',
      api: health.status,
      payments: checks.payments?.status ?? 'unknown',
      invitations: (await tableOk('event_invitations')) ? 'ok' : 'missing',
      marketplace: (await tableOk('vendors')) ? 'ok' : 'missing',
      vendorCrm: crm ? 'ok' : 'missing',
      seating: seating ? 'ok' : 'missing',
      programPlanner: program ? 'ok' : 'missing',
      storage: checks.storage?.status ?? 'unknown',
      notifications: checks.notifications?.status ?? 'unknown',
    };
  }
}
