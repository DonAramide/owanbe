import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { NotificationService } from '../../integrations/notifications/notification.service';

export interface TicketEntitlementView {
  id: string;
  ticketCode: string;
  qrPayload: string;
  tierName: string;
  eventId: string;
  eventTitle: string;
  eventCity: string;
  eventVenue: string;
  venueAddress: string;
  startsAt: string;
  endsAt: string;
  status: string;
  issuedAt: string;
  checkedInAt: string | null;
  accessLevel: string | null;
  seatLabel: string | null;
  gateInfo: string | null;
  entryInstructions: string | null;
  arrivalInstructions: string | null;
  supportContactEmail: string | null;
  supportContactPhone: string | null;
  groupLabel: string | null;
  ticketOrderId: string | null;
  siblingCount: number;
}

@Injectable()
export class TicketEntitlementsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly notifications: NotificationService,
  ) {}

  async listForUser(tenantId: string, userId: string): Promise<TicketEntitlementView[]> {
    const { rows } = await this.pool.query<{
      id: string;
      ticket_code: string;
      metadata: Record<string, unknown> | null;
      event_id: string;
      status: string;
      issued_at: Date;
      checked_in_at: Date | null;
      ticket_order_id: string | null;
      title: string;
      city: string;
      venue: string;
      venue_address: string | null;
      starts_at: Date;
      ends_at: Date | null;
      event_metadata: Record<string, unknown> | null;
      tier_access_level: string | null;
      sibling_count: string;
    }>(
      `SELECT te.id, te.ticket_code, te.metadata, te.event_id, te.status::text, te.issued_at,
              te.checked_in_at, te.ticket_order_id,
              e.title,
              e.metadata->>'city' AS city,
              e.metadata->>'venue' AS venue,
              e.metadata->>'venueAddress' AS venue_address,
              e.starts_at,
              e.ends_at,
              e.metadata AS event_metadata,
              (
                SELECT COALESCE(ett.metadata->>'accessLevel', NULL)
                FROM event_ticket_tiers ett
                WHERE ett.tenant_id = te.tenant_id
                  AND ett.event_id = te.event_id
                  AND lower(ett.name) = lower(COALESCE(te.metadata->>'tier_name', ''))
                LIMIT 1
              ) AS tier_access_level,
              (
                SELECT COUNT(*)::text
                FROM ticket_entitlements sib
                WHERE sib.tenant_id = te.tenant_id
                  AND sib.holder_user_id = te.holder_user_id
                  AND sib.event_id = te.event_id
              ) AS sibling_count
       FROM ticket_entitlements te
       INNER JOIN events e ON e.id = te.event_id
       WHERE te.tenant_id = $1 AND te.holder_user_id = $2
       ORDER BY te.issued_at DESC`,
      [tenantId, userId],
    );

    return rows.map((r) => this.mapRow(r));
  }

  async getForUser(
    tenantId: string,
    userId: string,
    entitlementId: string,
  ): Promise<TicketEntitlementView> {
    const items = await this.listForUser(tenantId, userId);
    const found = items.find((i) => i.id === entitlementId);
    if (!found) {
      throw new NotFoundException({ code: 'ENTITLEMENT_NOT_FOUND', message: 'Pass not found' });
    }
    return found;
  }

  async resendTicket(tenantId: string, userId: string, entitlementId: string) {
    const { rows } = await this.pool.query<{
      ticket_code: string;
      tier_name: string;
      title: string;
      email: string;
    }>(
      `SELECT te.ticket_code,
              COALESCE(te.metadata->>'tier_name', 'Ticket') AS tier_name,
              e.title, u.email
       FROM ticket_entitlements te
       INNER JOIN events e ON e.id = te.event_id
       INNER JOIN users u ON u.id = te.holder_user_id
       WHERE te.id = $1 AND te.tenant_id = $2 AND te.holder_user_id = $3 AND te.status = 'issued'`,
      [entitlementId, tenantId, userId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'ENTITLEMENT_NOT_FOUND', message: 'Ticket not found' });
    }
    const result = await this.notifications.sendTicketConfirmation({
      tenantId,
      email: row.email,
      eventTitle: row.title,
      ticketCode: row.ticket_code,
      tierName: row.tier_name,
    });
    return { ok: result.ok, entitlementId };
  }

  private mapRow(r: {
    id: string;
    ticket_code: string;
    metadata: Record<string, unknown> | null;
    event_id: string;
    status: string;
    issued_at: Date;
    checked_in_at: Date | null;
    ticket_order_id: string | null;
    title: string;
    city: string;
    venue: string;
    venue_address: string | null;
    starts_at: Date;
    ends_at: Date | null;
    event_metadata: Record<string, unknown> | null;
    tier_access_level: string | null;
    sibling_count: string;
  }): TicketEntitlementView {
    const meta = r.metadata ?? {};
    const eventMeta = r.event_metadata ?? {};
    const endsAt = r.ends_at ?? new Date(r.starts_at.getTime() + 6 * 60 * 60 * 1000);

    const accessLevel =
      this.str(meta.access_level) ??
      this.str(meta.accessLevel) ??
      this.str(r.tier_access_level);

    const seatLabel =
      this.str(meta.seat_label) ??
      this.str(meta.seatLabel) ??
      this.composeSeat(meta);

    const gateInfo =
      this.str(meta.gate) ??
      this.str(meta.gate_info) ??
      this.str(meta.gateInfo) ??
      this.str(eventMeta.gateInfo) ??
      this.str(eventMeta.entryGate);

    const entryInstructions =
      this.str(meta.entry_instructions) ??
      this.str(meta.entryInstructions) ??
      this.str(eventMeta.entryInstructions);

    const arrivalInstructions =
      this.str(meta.arrival_instructions) ??
      this.str(meta.arrivalInstructions) ??
      this.str(eventMeta.arrivalInstructions) ??
      entryInstructions;

    return {
      id: r.id,
      ticketCode: r.ticket_code,
      qrPayload: this.str(meta.qr_payload) ?? this.str(meta.qrPayload) ?? r.ticket_code,
      tierName: this.str(meta.tier_name) ?? this.str(meta.tierName) ?? 'Ticket',
      eventId: r.event_id,
      eventTitle: r.title,
      eventCity: r.city ?? '',
      eventVenue: r.venue ?? '',
      venueAddress: r.venue_address ?? this.str(eventMeta.venueAddress) ?? '',
      startsAt: r.starts_at.toISOString(),
      endsAt: endsAt.toISOString(),
      status: r.status,
      issuedAt: r.issued_at.toISOString(),
      checkedInAt: r.checked_in_at?.toISOString() ?? null,
      accessLevel,
      seatLabel,
      gateInfo,
      entryInstructions,
      arrivalInstructions,
      supportContactEmail: this.str(eventMeta.organizerContactEmail),
      supportContactPhone: this.str(eventMeta.organizerContactPhone),
      groupLabel:
        this.str(meta.group_label) ??
        this.str(meta.groupLabel) ??
        this.str(meta.family_label) ??
        this.str(meta.familyLabel),
      ticketOrderId: r.ticket_order_id,
      siblingCount: Number(r.sibling_count) || 1,
    };
  }

  private composeSeat(meta: Record<string, unknown>): string | null {
    const table = this.str(meta.table) ?? this.str(meta.tableName) ?? this.str(meta.table_name);
    const seat = this.str(meta.seat) ?? this.str(meta.seatNumber) ?? this.str(meta.seat_number);
    if (table && seat) return `Table ${table} · Seat ${seat}`;
    if (seat) return `Seat ${seat}`;
    if (table) return `Table ${table}`;
    return null;
  }

  private str(v: unknown): string | null {
    if (v == null) return null;
    const s = String(v).trim();
    return s.length === 0 ? null : s;
  }
}
