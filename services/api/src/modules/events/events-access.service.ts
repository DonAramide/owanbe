import { ForbiddenException, Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class EventsAccessService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async resolveOrganizerId(tenantId: string, userId: string): Promise<string> {
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM organizers WHERE tenant_id = $1 AND owner_user_id = $2 AND status = 'active' LIMIT 1`,
      [tenantId, userId],
    );
    const id = rows[0]?.id;
    if (!id) {
      throw new ForbiddenException({ code: 'ORGANIZER_REQUIRED', message: 'Active organizer profile required' });
    }
    return id;
  }

  async resolveVendorId(tenantId: string, userId: string): Promise<string> {
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM vendors WHERE tenant_id = $1 AND owner_user_id = $2 AND status = 'active' LIMIT 1`,
      [tenantId, userId],
    );
    const id = rows[0]?.id;
    if (!id) {
      throw new ForbiddenException({ code: 'VENDOR_REQUIRED', message: 'Active vendor profile required' });
    }
    return id;
  }

  async resolveEventRow(
    tenantId: string,
    eventKey: string,
    publicOnly = false,
  ): Promise<{
    id: string;
    organizer_id: string;
    title: string;
    slug: string;
    status: string;
    external_ref: string | null;
    starts_at: Date;
    ends_at: Date | null;
    metadata: Record<string, unknown>;
  }> {
    const { rows } = await this.pool.query<{
      id: string;
      organizer_id: string;
      title: string;
      slug: string;
      status: string;
      external_ref: string | null;
      starts_at: Date;
      ends_at: Date | null;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, organizer_id, title, slug, status::text, external_ref, starts_at, ends_at, metadata
       FROM events
       WHERE tenant_id = $1
         AND (id::text = $2 OR external_ref = $2 OR slug = $2)
         ${publicOnly ? `AND status::text IN ('published', 'live', 'completed')` : ''}
       LIMIT 1`,
      [tenantId, eventKey],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found' });
    }
    return row;
  }

  async assertOrganizerOwnsEvent(tenantId: string, userId: string, eventKey: string) {
    const event = await this.resolveEventRow(tenantId, eventKey);
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT o.id FROM organizers o
       WHERE o.id = $1 AND o.tenant_id = $2 AND o.owner_user_id = $3`,
      [event.organizer_id, tenantId, userId],
    );
    if (!rows[0]) {
      throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not event organizer' });
    }
    return event;
  }

  slugify(title: string): string {
    const base = title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 48);
    return base || `event-${Date.now()}`;
  }
}
