import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

export type EventGuestView = {
  id: string;
  name: string;
  email: string | null;
  phoneE164: string | null;
  groupLabel: string | null;
  rsvpStatus: 'invited' | 'pending' | 'confirmed' | 'declined';
  entitlementRef: string | null;
  source: string;
  createdAt: string;
  updatedAt: string;
};

@Injectable()
export class EventGuestsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  private mapRow(row: {
    id: string;
    name: string;
    email: string | null;
    phone_e164: string | null;
    group_label: string | null;
    rsvp_status: string;
    entitlement_ref: string | null;
    source: string;
    created_at: Date;
    updated_at: Date;
  }): EventGuestView {
    return {
      id: row.id,
      name: row.name,
      email: row.email,
      phoneE164: row.phone_e164,
      groupLabel: row.group_label,
      rsvpStatus: row.rsvp_status as EventGuestView['rsvpStatus'],
      entitlementRef: row.entitlement_ref,
      source: row.source,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  }

  async list(actor: CommerceActor, eventKey: string): Promise<{ items: EventGuestView[] }> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      name: string;
      email: string | null;
      phone_e164: string | null;
      group_label: string | null;
      rsvp_status: string;
      entitlement_ref: string | null;
      source: string;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT id, name, email, phone_e164, group_label, rsvp_status::text, entitlement_ref, source, created_at, updated_at
       FROM event_guests
       WHERE tenant_id = $1 AND event_id = $2
       ORDER BY name ASC`,
      [actor.tenantId, event.id],
    );
    return { items: rows.map((r) => this.mapRow(r)) };
  }

  async create(
    actor: CommerceActor,
    eventKey: string,
    body: {
      name?: string;
      email?: string;
      phoneE164?: string;
      groupLabel?: string;
      source?: string;
      notes?: string;
    },
  ): Promise<EventGuestView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const name = String(body.name ?? '').trim();
    if (!name) {
      throw new BadRequestException({ code: 'INVALID_GUEST', message: 'Guest name is required' });
    }
    const notes = body.notes?.trim();
    const metadata = notes ? JSON.stringify({ notes }) : '{}';
    const { rows } = await this.pool.query<{
      id: string;
      name: string;
      email: string | null;
      phone_e164: string | null;
      group_label: string | null;
      rsvp_status: string;
      entitlement_ref: string | null;
      source: string;
      created_at: Date;
      updated_at: Date;
    }>(
      `INSERT INTO event_guests (tenant_id, event_id, name, email, phone_e164, group_label, source, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
       RETURNING id, name, email, phone_e164, group_label, rsvp_status::text, entitlement_ref, source, created_at, updated_at`,
      [
        actor.tenantId,
        event.id,
        name,
        body.email?.trim() || null,
        body.phoneE164?.trim() || null,
        body.groupLabel?.trim() || null,
        body.source?.trim() || 'manual',
        metadata,
      ],
    );
    return this.mapRow(rows[0]!);
  }

  async bulkCreate(
    actor: CommerceActor,
    eventKey: string,
    guests: Array<{ name: string; email?: string; phoneE164?: string; groupLabel?: string }>,
  ): Promise<{ items: EventGuestView[]; imported: number }> {
    return this.importBulk(actor, eventKey, guests);
  }

  async importBulk(
    actor: CommerceActor,
    eventKey: string,
    guests: Array<{ name: string; email?: string; phoneE164?: string }>,
  ): Promise<{ items: EventGuestView[]; imported: number }> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const items: EventGuestView[] = [];
    for (const g of guests) {
      const name = g.name.trim();
      if (!name) continue;
      const { rows } = await this.pool.query<{
        id: string;
        name: string;
        email: string | null;
        phone_e164: string | null;
        group_label: string | null;
        rsvp_status: string;
        entitlement_ref: string | null;
        source: string;
        created_at: Date;
        updated_at: Date;
      }>(
        `INSERT INTO event_guests (tenant_id, event_id, name, email, phone_e164, source)
         VALUES ($1, $2, $3, $4, $5, 'import')
         RETURNING id, name, email, phone_e164, group_label, rsvp_status::text, entitlement_ref, source, created_at, updated_at`,
        [actor.tenantId, event.id, name, g.email?.trim() || null, g.phoneE164?.trim() || null],
      );
      items.push(this.mapRow(rows[0]!));
    }
    return { items, imported: items.length };
  }

  async patch(
    actor: CommerceActor,
    eventKey: string,
    guestId: string,
    body: Record<string, unknown>,
  ): Promise<EventGuestView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const sets: string[] = [];
    const vals: unknown[] = [actor.tenantId, event.id, guestId];
    let idx = 4;
    if (body.name != null) {
      sets.push(`name = $${idx++}`);
      vals.push(String(body.name).trim());
    }
    if (body.email !== undefined) {
      sets.push(`email = $${idx++}`);
      vals.push(body.email ? String(body.email).trim() : null);
    }
    if (body.phoneE164 !== undefined) {
      sets.push(`phone_e164 = $${idx++}`);
      vals.push(body.phoneE164 ? String(body.phoneE164).trim() : null);
    }
    if (body.groupLabel !== undefined) {
      sets.push(`group_label = $${idx++}`);
      vals.push(body.groupLabel ? String(body.groupLabel).trim() : null);
    }
    if (body.rsvpStatus != null) {
      sets.push(`rsvp_status = $${idx++}::event_guest_rsvp_status`);
      vals.push(String(body.rsvpStatus));
    }
    if (sets.length === 0) {
      throw new BadRequestException({ code: 'NO_CHANGES', message: 'No fields to update' });
    }
    sets.push('updated_at = now()');
    const { rows } = await this.pool.query<{
      id: string;
      name: string;
      email: string | null;
      phone_e164: string | null;
      group_label: string | null;
      rsvp_status: string;
      entitlement_ref: string | null;
      source: string;
      created_at: Date;
      updated_at: Date;
    }>(
      `UPDATE event_guests SET ${sets.join(', ')}
       WHERE tenant_id = $1 AND event_id = $2 AND id = $3::uuid
       RETURNING id, name, email, phone_e164, group_label, rsvp_status::text, entitlement_ref, source, created_at, updated_at`,
      vals,
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'GUEST_NOT_FOUND', message: 'Guest not found' });
    }
    return this.mapRow(row);
  }

  async remove(actor: CommerceActor, eventKey: string, guestId: string): Promise<{ ok: true }> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rowCount } = await this.pool.query(
      `DELETE FROM event_guests WHERE tenant_id = $1 AND event_id = $2 AND id = $3::uuid`,
      [actor.tenantId, event.id, guestId],
    );
    if (!rowCount) {
      throw new NotFoundException({ code: 'GUEST_NOT_FOUND', message: 'Guest not found' });
    }
    return { ok: true };
  }
}
