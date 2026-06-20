import { Injectable, Inject, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

@Injectable()
export class EventOperationsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  async listCheckIns(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows: checked } = await this.pool.query<{
      id: string;
      ticket_code: string;
      holder_name: string;
      tier_name: string;
      checked_in_at: Date;
      source: string;
    }>(
      `SELECT id, ticket_code, holder_name, tier_name, checked_in_at, source
       FROM event_check_ins WHERE tenant_id = $1 AND event_id = $2 ORDER BY checked_in_at DESC`,
      [actor.tenantId, event.id],
    );

    const { rows: pending } = await this.pool.query<{
      id: string;
      ticket_code: string;
      tier_name: string;
      holder_email: string;
    }>(
      `SELECT te.id, te.ticket_code,
              COALESCE(te.metadata->>'tier_name', 'General') AS tier_name,
              u.email AS holder_email
       FROM ticket_entitlements te
       INNER JOIN users u ON u.id = te.holder_user_id
       WHERE te.tenant_id = $1 AND te.event_id = $2 AND te.status = 'issued'
       ORDER BY te.issued_at ASC`,
      [actor.tenantId, event.id],
    );

    return {
      checkedIn: checked.map((r) => ({
        id: r.id,
        ticketId: r.ticket_code,
        name: r.holder_name,
        tierName: r.tier_name,
        checkedIn: true,
        checkedInAt: r.checked_in_at.toISOString(),
        source: r.source,
      })),
      pending: pending.map((r) => ({
        id: r.id,
        ticketId: r.ticket_code,
        name: r.holder_email,
        tierName: r.tier_name,
        checkedIn: false,
      })),
    };
  }

  async checkIn(
    actor: CommerceActor,
    eventKey: string,
    body: { ticketCode?: string; entitlementId?: string; source?: string },
  ) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const ticketCode = body.ticketCode?.trim();
    const entitlementId = body.entitlementId?.trim();
    if (!ticketCode && !entitlementId) {
      throw new UnprocessableEntityException({ code: 'TICKET_REQUIRED', message: 'ticketCode or entitlementId required' });
    }

    const ent = await this.pool.query<{
      id: string;
      ticket_code: string;
      status: string;
      holder_user_id: string;
      metadata: Record<string, unknown>;
    }>(
      `SELECT te.id, te.ticket_code, te.status::text, te.holder_user_id, te.metadata
       FROM ticket_entitlements te
       WHERE te.tenant_id = $1 AND te.event_id = $2
         AND ($3::uuid IS NULL OR te.id = $3::uuid)
         AND ($4::text IS NULL OR lower(te.ticket_code) = lower($4::text))
       LIMIT 1`,
      [actor.tenantId, event.id, entitlementId ?? null, ticketCode ?? null],
    );
    const row = ent.rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'TICKET_NOT_FOUND', message: 'Ticket not recognized' });
    }
    if (row.status === 'checked_in') {
      return { ok: true, duplicate: true, ticketCode: row.ticket_code };
    }
    if (row.status !== 'issued') {
      throw new UnprocessableEntityException({ code: 'TICKET_INVALID', message: `Ticket status: ${row.status}` });
    }

    const holder = await this.pool.query<{ email: string; display_name: string | null }>(
      `SELECT email, display_name FROM users WHERE id = $1`,
      [row.holder_user_id],
    );
    const holderName = holder.rows[0]?.display_name ?? holder.rows[0]?.email ?? 'Guest';
    const tierName = String(row.metadata?.tier_name ?? 'General');
    const source = body.source ?? 'manual';

    await this.pool.query('BEGIN');
    try {
      await this.pool.query(
        `UPDATE ticket_entitlements SET status = 'checked_in', checked_in_at = now() WHERE id = $1`,
        [row.id],
      );
      await this.pool.query(
        `INSERT INTO event_check_ins (
           tenant_id, event_id, entitlement_id, ticket_code, holder_name, tier_name,
           checked_in_by_user_id, source
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (event_id, ticket_code) DO NOTHING`,
        [actor.tenantId, event.id, row.id, row.ticket_code, holderName, tierName, actor.userId, source],
      );
      await this.pool.query(
        `INSERT INTO event_feed_items (tenant_id, event_id, feed_type, headline, detail)
         VALUES ($1, $2, 'guest_checked_in', $3, $4)`,
        [actor.tenantId, event.id, `${holderName} checked in`, `${tierName} · ${source}`],
      );
      await this.pool.query('COMMIT');
    } catch (e) {
      await this.pool.query('ROLLBACK');
      throw e;
    }
    return { ok: true, ticketCode: row.ticket_code, holderName, tierName };
  }

  async listIncidents(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      title: string;
      category: string;
      priority: string;
      status: string;
      reporter: string;
      description: string;
      created_at: Date;
    }>(
      `SELECT id, title, category::text, priority::text, status::text, reporter, description, created_at
       FROM event_incidents WHERE tenant_id = $1 AND event_id = $2 ORDER BY created_at DESC`,
      [actor.tenantId, event.id],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        title: r.title,
        category: r.category,
        priority: r.priority,
        status: r.status,
        reporter: r.reporter,
        description: r.description,
        createdAt: r.created_at.toISOString(),
      })),
    };
  }

  async createIncident(
    actor: CommerceActor,
    eventKey: string,
    body: { title: string; category?: string; priority?: string; reporter?: string; description?: string },
  ) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO event_incidents (tenant_id, event_id, title, category, priority, reporter, description)
       VALUES ($1, $2, $3, $4::event_incident_category, $5::event_incident_priority, $6, $7)
       RETURNING id`,
      [
        actor.tenantId,
        event.id,
        body.title,
        body.category ?? 'other',
        body.priority ?? 'medium',
        body.reporter ?? actor.email ?? 'staff',
        body.description ?? '',
      ],
    );
    await this.pool.query(
      `INSERT INTO event_feed_items (tenant_id, event_id, feed_type, headline, detail)
       VALUES ($1, $2, 'incident_logged', $3, $4)`,
      [actor.tenantId, event.id, `Incident: ${body.title}`, body.category ?? 'other'],
    );
    return { id: rows[0]!.id };
  }

  async listFeed(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      feed_type: string;
      headline: string;
      detail: string;
      created_at: Date;
    }>(
      `SELECT id, feed_type, headline, detail, created_at
       FROM event_feed_items WHERE tenant_id = $1 AND event_id = $2 ORDER BY created_at DESC LIMIT 200`,
      [actor.tenantId, event.id],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        type: r.feed_type,
        headline: r.headline,
        detail: r.detail,
        timestamp: r.created_at.toISOString(),
      })),
    };
  }
}
