import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class AdminOperationsCenterService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getOverview(tenantId: string) {
    const [live, checkIns, incidents, feed] = await Promise.all([
      this.liveEvents(tenantId),
      this.recentCheckIns(tenantId),
      this.openIncidents(tenantId),
      this.recentFeed(tenantId),
    ]);
    return { liveEvents: live, checkIns, incidents, feed };
  }

  async liveEvents(tenantId: string) {
    const { rows } = await this.pool.query(
      `SELECT e.id, e.external_ref, e.title, e.starts_at, o.display_name AS organizer_name,
              (SELECT COUNT(*)::text FROM event_check_ins ci WHERE ci.event_id = e.id) AS checked_in
       FROM events e
       INNER JOIN organizers o ON o.id = e.organizer_id
       WHERE e.tenant_id = $1 AND e.status::text IN ('live', 'published')
       ORDER BY e.starts_at ASC
       LIMIT 50`,
      [tenantId],
    );
    return rows.map((r) => ({
      eventId: r.external_ref ?? r.id,
      title: r.title,
      organizerName: r.organizer_name,
      startsAt: r.starts_at.toISOString(),
      checkedIn: Number(r.checked_in),
    }));
  }

  async recentCheckIns(tenantId: string, limit = 50) {
    const { rows } = await this.pool.query(
      `SELECT ci.id, ci.ticket_code, ci.holder_name, ci.tier_name, ci.checked_in_at,
              e.title AS event_title, e.external_ref
       FROM event_check_ins ci
       INNER JOIN events e ON e.id = ci.event_id
       WHERE ci.tenant_id = $1
       ORDER BY ci.checked_in_at DESC
       LIMIT $2`,
      [tenantId, limit],
    );
    return rows.map((r) => ({
      id: r.id,
      ticketCode: r.ticket_code,
      holderName: r.holder_name,
      tierName: r.tier_name,
      eventTitle: r.event_title,
      eventId: r.external_ref ?? '',
      checkedInAt: r.checked_in_at.toISOString(),
    }));
  }

  async openIncidents(tenantId: string) {
    const { rows } = await this.pool.query(
      `SELECT ei.id, ei.title, ei.category::text, ei.priority::text, ei.status::text,
              ei.created_at, e.title AS event_title, e.external_ref
       FROM event_incidents ei
       INNER JOIN events e ON e.id = ei.event_id
       WHERE ei.tenant_id = $1 AND ei.status::text = 'open'
       ORDER BY ei.created_at DESC
       LIMIT 100`,
      [tenantId],
    );
    return rows.map((r) => ({
      id: r.id,
      title: r.title,
      category: r.category,
      priority: r.priority,
      status: r.status,
      eventTitle: r.event_title,
      eventId: r.external_ref ?? '',
      createdAt: r.created_at.toISOString(),
    }));
  }

  async recentFeed(tenantId: string, limit = 80) {
    const { rows } = await this.pool.query(
      `SELECT fi.id, fi.feed_type, fi.headline, fi.detail, fi.created_at, e.title AS event_title
       FROM event_feed_items fi
       INNER JOIN events e ON e.id = fi.event_id
       WHERE fi.tenant_id = $1
       ORDER BY fi.created_at DESC
       LIMIT $2`,
      [tenantId, limit],
    );
    return rows.map((r) => ({
      id: r.id,
      type: r.feed_type,
      headline: r.headline,
      detail: r.detail,
      eventTitle: r.event_title,
      timestamp: r.created_at.toISOString(),
    }));
  }
}
