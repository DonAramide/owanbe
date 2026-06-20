import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

export interface TicketEntitlementView {
  id: string;
  ticketCode: string;
  qrPayload: string;
  tierName: string;
  eventId: string;
  eventTitle: string;
  eventCity: string;
  eventVenue: string;
  startsAt: string;
  status: string;
  issuedAt: string;
}

@Injectable()
export class TicketEntitlementsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async listForUser(tenantId: string, userId: string): Promise<TicketEntitlementView[]> {
    const { rows } = await this.pool.query<{
      id: string;
      ticket_code: string;
      metadata: { qr_payload?: string; tier_name?: string };
      event_id: string;
      status: string;
      issued_at: Date;
      title: string;
      city: string;
      venue: string;
      starts_at: Date;
    }>(
      `SELECT te.id, te.ticket_code, te.metadata, te.event_id, te.status::text, te.issued_at,
              e.title, e.metadata->>'city' AS city, e.metadata->>'venue' AS venue, e.starts_at
       FROM ticket_entitlements te
       INNER JOIN events e ON e.id = te.event_id
       WHERE te.tenant_id = $1 AND te.holder_user_id = $2
       ORDER BY te.issued_at DESC`,
      [tenantId, userId],
    );

    return rows.map((r) => ({
      id: r.id,
      ticketCode: r.ticket_code,
      qrPayload: r.metadata?.qr_payload ?? r.ticket_code,
      tierName: r.metadata?.tier_name ?? 'Ticket',
      eventId: r.event_id,
      eventTitle: r.title,
      eventCity: r.city ?? '',
      eventVenue: r.venue ?? '',
      startsAt: r.starts_at.toISOString(),
      status: r.status,
      issuedAt: r.issued_at.toISOString(),
    }));
  }
}
