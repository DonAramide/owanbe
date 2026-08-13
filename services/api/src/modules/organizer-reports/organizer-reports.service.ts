import { Injectable, NotFoundException, Inject, forwardRef } from '@nestjs/common';
import {
  FinanceExportService,
  type FinanceExportFormat,
} from '../commerce/finance-export.service';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { OrganizerAnalyticsService } from '../events/organizer-analytics.service';
import { EventOperationsService } from '../events/event-operations.service';
import { EventInvitationsService } from '../events/event-invitations.service';
import { VendorCrmService } from '../vendor-operations/vendor-crm.service';
import { OrganizerMarketingService } from '../organizer-marketing/organizer-marketing.service';

export type ReportPackId =
  | 'event-summary'
  | 'attendance'
  | 'finance-summary'
  | 'finance-orders'
  | 'finance-transactions'
  | 'finance-refunds'
  | 'ticket-sales'
  | 'guests'
  | 'vendors'
  | 'marketing'
  | 'portfolio';

export type ReportCatalogEntry = {
  id: ReportPackId;
  title: string;
  source: string;
  status: 'available' | 'unavailable';
  reason?: string;
  formats: Array<'csv' | 'xlsx'>;
};

export type ReportExportFilters = {
  from?: string;
  to?: string;
  ticketType?: string;
  vendorId?: string;
  vendorStage?: string;
  guestStatus?: string;
  days?: number;
};

/**
 * Phase 21 — read-only Reporting Engine.
 * Composes canonical Ops / Finance / Analytics / Vendor CRM services.
 * Never invents metrics; marketing packs compose OrganizerMarketingService (Phase 26).
 */
@Injectable()
export class OrganizerReportsService {
  constructor(
    private readonly financeExports: FinanceExportService,
    private readonly analytics: OrganizerAnalyticsService,
    private readonly operations: EventOperationsService,
    private readonly invitations: EventInvitationsService,
    private readonly vendorCrm: VendorCrmService,
    @Inject(forwardRef(() => OrganizerMarketingService))
    private readonly marketing: OrganizerMarketingService,
  ) {}

  catalogForEvent(): ReportCatalogEntry[] {
    return [
      {
        id: 'event-summary',
        title: 'Event Summary',
        source: 'Analytics',
        status: 'available',
        formats: ['csv'],
      },
      {
        id: 'attendance',
        title: 'Attendance Report',
        source: 'Operations',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'finance-summary',
        title: 'Finance Summary',
        source: 'Finance',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'finance-orders',
        title: 'Finance Orders',
        source: 'Finance',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'finance-transactions',
        title: 'Finance Transactions',
        source: 'Finance',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'finance-refunds',
        title: 'Finance Refunds',
        source: 'Finance',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'ticket-sales',
        title: 'Ticket Sales Report',
        source: 'Finance',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'guests',
        title: 'Guest / Invitation Report',
        source: 'Invitations',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'vendors',
        title: 'Vendor CRM Report',
        source: 'Vendor CRM',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'marketing',
        title: 'Marketing Report',
        source: 'Marketing',
        status: 'available',
        formats: ['csv'],
      },
    ];
  }

  catalogPortfolio(): ReportCatalogEntry[] {
    return [
      {
        id: 'portfolio',
        title: 'Portfolio Summary',
        source: 'Analytics',
        status: 'available',
        formats: ['csv', 'xlsx'],
      },
      {
        id: 'marketing',
        title: 'Marketing Report',
        source: 'Marketing',
        status: 'available',
        formats: ['csv'],
      },
    ];
  }

  async exportEventPack(
    actor: CommerceActor,
    eventKey: string,
    pack: string,
    format: FinanceExportFormat,
    filters: ReportExportFilters = {},
  ): Promise<{ body: string; contentType: string; filename: string }> {
    const id = pack as ReportPackId;
    if (id === 'marketing') {
      const out = await this.marketing.marketingReportCsv(actor, eventKey);
      return { body: out.body, contentType: out.contentType, filename: out.filename };
    }

    if (
      id === 'finance-summary' ||
      id === 'finance-orders' ||
      id === 'finance-transactions' ||
      id === 'finance-refunds' ||
      id === 'ticket-sales'
    ) {
      const kind =
        id === 'finance-summary'
          ? 'summary'
          : id === 'finance-orders' || id === 'ticket-sales'
            ? 'orders'
            : id === 'finance-transactions'
              ? 'transactions'
              : 'refunds';
      return this.financeExports.exportForOrganizerEvent(actor, eventKey, kind, format);
    }

    if (id === 'event-summary') {
      const out = await this.analytics.exportEventCsv(actor, eventKey);
      if (format === 'xlsx') {
        return this.packRows('event-summary', format, ['section', 'metric', 'value'], this.csvBodyToRows(out.body));
      }
      return {
        body: out.body,
        contentType: 'text/csv; charset=utf-8',
        filename: out.filename,
      };
    }

    if (id === 'attendance') {
      return this.exportAttendance(actor, eventKey, format, filters);
    }

    if (id === 'guests') {
      return this.exportGuests(actor, eventKey, format, filters);
    }

    if (id === 'vendors') {
      return this.exportVendors(actor, eventKey, format, filters);
    }

    throw new NotFoundException({
      code: 'UNKNOWN_REPORT_PACK',
      message: `Unknown report pack: ${pack}`,
    });
  }

  async exportPortfolio(
    actor: CommerceActor,
    format: FinanceExportFormat,
  ): Promise<{ body: string; contentType: string; filename: string }> {
    const portfolio = await this.analytics.getPortfolio(actor);
    const headers = [
      'event_id',
      'title',
      'status',
      'tickets_sold',
      'revenue_minor',
      'checked_in',
      'attendance_pct',
      'starts_at',
    ];
    const rows = (portfolio.items ?? []).map((item: Record<string, unknown>) => [
      String(item.eventId ?? ''),
      String(item.title ?? ''),
      String(item.status ?? ''),
      String(item.ticketsSold ?? 0),
      String(item.revenueMinor ?? '0'),
      String(item.checkedIn ?? 0),
      String(item.attendancePct ?? 0),
      String(item.startsAt ?? ''),
    ]);
    const totals = portfolio.totals ?? {};
    rows.push([
      'TOTALS',
      '',
      '',
      String(totals.ticketsSold ?? 0),
      String(totals.revenueMinor ?? '0'),
      String(totals.checkedIn ?? 0),
      '',
      '',
    ]);
    return this.packRows('portfolio', format, headers, rows);
  }

  async exportMarketingPortfolio(actor: CommerceActor) {
    return this.marketing.marketingReportCsv(actor);
  }

  private async exportAttendance(
    actor: CommerceActor,
    eventKey: string,
    format: FinanceExportFormat,
    filters: ReportExportFilters,
  ) {
    const data = await this.operations.listCheckIns(actor, eventKey);
    const headers = [
      'status',
      'ticket_code',
      'name',
      'tier_name',
      'checked_in_at',
      'issued_at',
      'source',
      'door_status',
      'entitlement_status',
    ];
    const ticketType = (filters.ticketType ?? '').trim().toLowerCase();
    const fromMs = filters.from ? Date.parse(filters.from) : NaN;
    const toMs = filters.to ? Date.parse(filters.to) : NaN;

    const rows: string[][] = [];
    for (const row of data.checkedIn ?? []) {
      if (ticketType && String(row.tierName ?? '').toLowerCase() !== ticketType) continue;
      const at = row.checkedInAt ? Date.parse(row.checkedInAt) : NaN;
      if (!Number.isNaN(fromMs) && !Number.isNaN(at) && at < fromMs) continue;
      if (!Number.isNaN(toMs) && !Number.isNaN(at) && at > toMs) continue;
      rows.push([
        'checked_in',
        String(row.ticketId ?? ''),
        String(row.name ?? ''),
        String(row.tierName ?? ''),
        String(row.checkedInAt ?? ''),
        '',
        String(row.source ?? ''),
        String(row.doorStatus ?? ''),
        String(row.entitlementStatus ?? ''),
      ]);
    }
    for (const row of data.pending ?? []) {
      if (ticketType && String(row.tierName ?? '').toLowerCase() !== ticketType) continue;
      const at = row.issuedAt ? Date.parse(row.issuedAt) : NaN;
      if (!Number.isNaN(fromMs) && !Number.isNaN(at) && at < fromMs) continue;
      if (!Number.isNaN(toMs) && !Number.isNaN(at) && at > toMs) continue;
      rows.push([
        'pending_no_show',
        String(row.ticketId ?? ''),
        String(row.name ?? ''),
        String(row.tierName ?? ''),
        '',
        String(row.issuedAt ?? ''),
        String(row.source ?? ''),
        String(row.doorStatus ?? ''),
        String(row.entitlementStatus ?? ''),
      ]);
    }
    return this.packRows('attendance', format, headers, rows);
  }

  private async exportGuests(
    actor: CommerceActor,
    eventKey: string,
    format: FinanceExportFormat,
    filters: ReportExportFilters,
  ) {
    const hub = await this.invitations.listHub(actor, eventKey);
    const headers = [
      'guest_id',
      'name',
      'email',
      'rsvp_status',
      'ticket_issued',
      'entitlement_ref',
      'invited_at',
      'responded_at',
    ];
    const statusFilter = (filters.guestStatus ?? '').trim().toLowerCase();
    const fromMs = filters.from ? Date.parse(filters.from) : NaN;
    const toMs = filters.to ? Date.parse(filters.to) : NaN;
    const rows: string[][] = [];
    for (const g of hub.guests ?? []) {
      const rsvp = String(g.rsvpStatus ?? '').toLowerCase();
      if (statusFilter && rsvp !== statusFilter) continue;
      const at = g.invitedAt ? Date.parse(g.invitedAt) : NaN;
      if (!Number.isNaN(fromMs) && !Number.isNaN(at) && at < fromMs) continue;
      if (!Number.isNaN(toMs) && !Number.isNaN(at) && at > toMs) continue;
      rows.push([
        String(g.id ?? ''),
        String(g.name ?? ''),
        String(g.email ?? ''),
        String(g.rsvpStatus ?? ''),
        g.ticketIssued ? 'true' : 'false',
        String(g.entitlementRef ?? ''),
        String(g.invitedAt ?? ''),
        String(g.respondedAt ?? ''),
      ]);
    }
    return this.packRows('guests', format, headers, rows);
  }

  private async exportVendors(
    actor: CommerceActor,
    eventKey: string,
    format: FinanceExportFormat,
    filters: ReportExportFilters,
  ) {
    const data = await this.vendorCrm.listForEvent(actor, eventKey);
    const headers = [
      'request_id',
      'vendor_id',
      'vendor_name',
      'stage',
      'contract_status',
      'assignment_status',
      'service_label',
      'latest_offer_minor',
      'scheduled_at',
      'arrived_at',
      'completed_at',
      'updated_at',
    ];
    const vendorId = (filters.vendorId ?? '').trim();
    const stage = (filters.vendorStage ?? '').trim().toLowerCase();
    const rows: string[][] = [];
    for (const item of data.items ?? []) {
      if (vendorId && item.vendorId !== vendorId) continue;
      if (stage && String(item.stage ?? '').toLowerCase() !== stage) continue;
      rows.push([
        String(item.id ?? ''),
        String(item.vendorId ?? ''),
        String(item.vendorName ?? ''),
        String(item.stage ?? ''),
        String(item.contractStatus ?? ''),
        String(item.assignmentStatus ?? ''),
        String(item.serviceLabel ?? ''),
        String(item.latestOfferMinor ?? ''),
        String(item.scheduledAt ?? ''),
        String(item.arrivedAt ?? ''),
        String(item.completedAt ?? ''),
        String(item.updatedAt ?? ''),
      ]);
    }
    return this.packRows('vendors', format, headers, rows);
  }

  private csvBodyToRows(body: string): string[][] {
    const lines = body.split(/\r?\n/).filter((l) => l.length > 0);
    // skip header
    return lines.slice(1).map((line) => {
      // simple CSV split — analytics export has no embedded commas in values except tier names JSON-quoted
      return line.split(',');
    });
  }

  private csvEscape(value: string | number | null | undefined): string {
    const s = value == null ? '' : String(value);
    if (s.includes(',') || s.includes('"') || s.includes('\n')) {
      return `"${s.replace(/"/g, '""')}"`;
    }
    return s;
  }

  private toCsv(headers: string[], rows: string[][]): string {
    const lines = [headers.join(',')];
    for (const row of rows) {
      lines.push(row.map((c) => this.csvEscape(c)).join(','));
    }
    return lines.join('\n');
  }

  private toSpreadsheetXml(headers: string[], rows: string[][]): string {
    const esc = (s: string) =>
      s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    const cell = (v: string) => `<Cell><Data ss:Type="String">${esc(v)}</Data></Cell>`;
    const headerRow = `<Row>${headers.map((h) => cell(h)).join('')}</Row>`;
    const dataRows = rows.map((r) => `<Row>${r.map((c) => cell(String(c))).join('')}</Row>`).join('');
    return `<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
 <Worksheet ss:Name="Export">
  <Table>
   ${headerRow}
   ${dataRows}
  </Table>
 </Worksheet>
</Workbook>`;
  }

  private packRows(
    kind: string,
    format: FinanceExportFormat,
    headers: string[],
    rows: string[][],
  ): { body: string; contentType: string; filename: string } {
    const stamp = new Date().toISOString().slice(0, 10);
    if (format === 'xlsx') {
      return {
        body: this.toSpreadsheetXml(headers, rows),
        contentType: 'application/vnd.ms-excel',
        filename: `owanbe-${kind}-${stamp}.xls`,
      };
    }
    return {
      body: this.toCsv(headers, rows),
      contentType: 'text/csv; charset=utf-8',
      filename: `owanbe-${kind}-${stamp}.csv`,
    };
  }
}
