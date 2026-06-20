import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AdminFinanceDashboardService } from '../payments/admin-finance-dashboard.service';

export type FinanceExportKind = 'transactions' | 'payouts' | 'refunds' | 'settlements' | 'organizer-payouts';
export type FinanceExportFormat = 'csv' | 'xlsx';

@Injectable()
export class FinanceExportService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly dashboard: AdminFinanceDashboardService,
  ) {}

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
    const cell = (v: string) =>
      `<Cell><Data ss:Type="String">${esc(v)}</Data></Cell>`;
    const headerRow = `<Row>${headers.map((h) => cell(h)).join('')}</Row>`;
    const dataRows = rows.map((r) => `<Row>${r.map((c) => cell(c)).join('')}</Row>`).join('');
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

  async export(
    tenantId: string,
    kind: FinanceExportKind,
    format: FinanceExportFormat,
    limit = 500,
  ): Promise<{ body: string; contentType: string; filename: string }> {
    const { headers, rows } = await this.loadRows(tenantId, kind, limit);
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

  private async loadRows(
    tenantId: string,
    kind: FinanceExportKind,
    limit: number,
  ): Promise<{ headers: string[]; rows: string[][] }> {
    switch (kind) {
      case 'transactions':
        return this.loadTransactions(tenantId, limit);
      case 'payouts':
        return this.loadVendorPayouts(tenantId, limit);
      case 'organizer-payouts':
        return this.loadOrganizerPayouts(tenantId, limit);
      case 'refunds':
        return this.loadRefunds(tenantId, limit);
      case 'settlements':
        return this.loadSettlements(tenantId, limit);
      default:
        return { headers: [], rows: [] };
    }
  }

  private async loadTransactions(tenantId: string, limit: number) {
    const { items } = await this.dashboard.transactions({
      tenantId,
      page: 1,
      limit,
    });
    return {
      headers: ['transaction_id', 'type', 'status', 'amount_minor', 'user', 'booking_id', 'created_at'],
      rows: items.map((t) => [
        String(t.transaction_id ?? t.id ?? ''),
        String(t.type ?? ''),
        String(t.status ?? ''),
        String(t.amount_minor ?? ''),
        String(t.user_label ?? t.user ?? ''),
        String(t.booking_id ?? ''),
        t.created_at instanceof Date ? t.created_at.toISOString() : String(t.created_at ?? ''),
      ]),
    };
  }

  private async loadVendorPayouts(tenantId: string, limit: number) {
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      amount_minor: string;
      currency: string;
      vendor_id: string;
      created_at: Date;
    }>(
      `SELECT id, status::text, amount_minor::text, currency, vendor_id::text, created_at
       FROM payouts WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [tenantId, limit],
    );
    return {
      headers: ['id', 'status', 'amount_minor', 'currency', 'vendor_id', 'created_at'],
      rows: rows.map((r) => [
        r.id,
        r.status,
        r.amount_minor,
        r.currency,
        r.vendor_id,
        r.created_at.toISOString(),
      ]),
    };
  }

  private async loadOrganizerPayouts(tenantId: string, limit: number) {
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      amount_minor: string;
      currency: string;
      organizer_id: string;
      ticket_order_id: string | null;
      created_at: Date;
    }>(
      `SELECT id, status::text, amount_minor::text, currency, organizer_id::text,
              ticket_order_id::text, created_at
       FROM organizer_payouts WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [tenantId, limit],
    );
    return {
      headers: ['id', 'status', 'amount_minor', 'currency', 'organizer_id', 'ticket_order_id', 'created_at'],
      rows: rows.map((r) => [
        r.id,
        r.status,
        r.amount_minor,
        r.currency,
        r.organizer_id,
        r.ticket_order_id ?? '',
        r.created_at.toISOString(),
      ]),
    };
  }

  private async loadRefunds(tenantId: string, limit: number) {
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      amount_minor: string;
      currency: string;
      reference_id: string;
      created_at: Date;
    }>(
      `SELECT * FROM (
         SELECT id::text, status::text, amount_minor::text, currency,
                ticket_order_id::text AS reference_id, created_at
         FROM ticket_refund_cases WHERE tenant_id = $1
         UNION ALL
         SELECT ('booking_' || lt.id::text), 'posted', ABS(ll.amount_minor)::text, la.currency,
                COALESCE(lt.booking_id::text, ''), lt.created_at
         FROM ledger_transactions lt
         INNER JOIN ledger_lines ll ON ll.transaction_id = lt.id AND ll.direction = 'debit'
         INNER JOIN ledger_accounts la ON la.id = ll.account_id
         WHERE lt.tenant_id = $1 AND lt.reason = 'payment_refund'
       ) combined
       ORDER BY created_at DESC
       LIMIT $2`,
      [tenantId, limit],
    );
    return {
      headers: ['id', 'status', 'amount_minor', 'currency', 'reference_id', 'created_at'],
      rows: rows.map((r) => [
        r.id,
        r.status,
        r.amount_minor,
        r.currency,
        r.reference_id,
        r.created_at.toISOString(),
      ]),
    };
  }

  private async loadSettlements(tenantId: string, limit: number) {
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      settlement_reference: string;
      payout_id: string;
      created_at: Date;
    }>(
      `SELECT id, status::text, settlement_reference, payout_id::text, created_at
       FROM treasury_settlements WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [tenantId, limit],
    );
    return {
      headers: ['id', 'status', 'settlement_reference', 'payout_id', 'created_at'],
      rows: rows.map((r) => [
        r.id,
        r.status,
        r.settlement_reference,
        r.payout_id,
        r.created_at.toISOString(),
      ]),
    };
  }
}
