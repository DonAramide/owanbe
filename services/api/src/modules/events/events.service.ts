import { Injectable, Inject, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

export interface EventView {
  id: string;
  externalRef: string | null;
  slug: string;
  title: string;
  tagline: string;
  description: string;
  city: string;
  venue: string;
  category: string;
  venueType: string;
  tags: string[];
  bannerLabel: string;
  mediaLabels: string[];
  coverGradientStart: number;
  coverGradientEnd: number;
  status: string;
  startsAt: string;
  endsAt: string | null;
  isFeatured: boolean;
  organizerId: string;
  createdAt: string;
  publishedAt: string | null;
  ticketTiers?: Array<Record<string, unknown>>;
  ticketsSold?: number;
  revenueMinor?: string;
  attendeeCount?: number;
}

@Injectable()
export class EventsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  private mapEvent(row: {
    id: string;
    external_ref: string | null;
    slug: string;
    title: string;
    status: string;
    organizer_id: string;
    starts_at: Date;
    ends_at: Date | null;
    metadata: Record<string, unknown>;
    created_at: Date;
  }): EventView {
    const m = row.metadata ?? {};
    return {
      id: row.id,
      externalRef: row.external_ref,
      slug: row.slug,
      title: row.title,
      tagline: String(m.tagline ?? ''),
      description: String(m.description ?? ''),
      city: String(m.city ?? ''),
      venue: String(m.venue ?? ''),
      category: String(m.category ?? 'Festival'),
      venueType: String(m.venueType ?? 'physical'),
      tags: Array.isArray(m.tags) ? (m.tags as string[]) : [],
      bannerLabel: String(m.bannerLabel ?? 'Default banner'),
      mediaLabels: Array.isArray(m.mediaLabels) ? (m.mediaLabels as string[]) : [],
      coverGradientStart: Number(m.coverGradientStart ?? 0xFF4B2C6F),
      coverGradientEnd: Number(m.coverGradientEnd ?? 0xFFD4A853),
      status: row.status,
      startsAt: row.starts_at.toISOString(),
      endsAt: row.ends_at?.toISOString() ?? null,
      isFeatured: m.isFeatured === true,
      organizerId: row.organizer_id,
      createdAt: row.created_at.toISOString(),
      publishedAt: m.publishedAt ? String(m.publishedAt) : null,
    };
  }

  async listPublic(tenantId: string, query?: string, category?: string): Promise<{ items: EventView[] }> {
    const { rows } = await this.pool.query<{
      id: string;
      external_ref: string | null;
      slug: string;
      title: string;
      status: string;
      organizer_id: string;
      starts_at: Date;
      ends_at: Date | null;
      metadata: Record<string, unknown>;
      created_at: Date;
    }>(
      `SELECT id, external_ref, slug, title, status::text, organizer_id, starts_at, ends_at, metadata, created_at
       FROM events
       WHERE tenant_id = $1 AND status::text IN ('published', 'live', 'completed')
       ORDER BY starts_at ASC`,
      [tenantId],
    );
    let items = rows.map((r) => this.mapEvent(r));
    if (category && category !== 'all') {
      items = items.filter((e) => e.category.toLowerCase() === category.toLowerCase());
    }
    if (query?.trim()) {
      const q = query.toLowerCase();
      items = items.filter(
        (e) =>
          e.title.toLowerCase().includes(q) ||
          e.city.toLowerCase().includes(q) ||
          e.category.toLowerCase().includes(q),
      );
    }
    for (const item of items) {
      item.ticketTiers = await this.loadTiersForEvent(tenantId, item.id);
    }
    return { items };
  }

  async getPublic(tenantId: string, eventKey: string): Promise<EventView> {
    const row = await this.access.resolveEventRow(tenantId, eventKey, true);
    const { rows } = await this.pool.query<{ created_at: Date }>(
      `SELECT created_at FROM events WHERE id = $1`,
      [row.id],
    );
    const view = this.mapEvent({ ...row, created_at: rows[0]?.created_at ?? new Date() });
    view.ticketTiers = await this.loadTiersForEvent(tenantId, row.id);
    return view;
  }

  async listForOrganizer(actor: CommerceActor): Promise<{ items: EventView[] }> {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const { rows } = await this.pool.query<{
      id: string;
      external_ref: string | null;
      slug: string;
      title: string;
      status: string;
      organizer_id: string;
      starts_at: Date;
      ends_at: Date | null;
      metadata: Record<string, unknown>;
      created_at: Date;
    }>(
      `SELECT id, external_ref, slug, title, status::text, organizer_id, starts_at, ends_at, metadata, created_at
       FROM events WHERE tenant_id = $1 AND organizer_id = $2
       ORDER BY created_at DESC`,
      [actor.tenantId, organizerId],
    );
    const items = rows.map((r) => this.mapEvent(r));
    for (const item of items) {
      item.ticketTiers = await this.loadTiersForEvent(actor.tenantId, item.id);
    }
    return { items };
  }

  async getForOrganizer(actor: CommerceActor, eventKey: string): Promise<EventView> {
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const row = await this.access.resolveEventRow(actor.tenantId, eventKey);
    const { rows } = await this.pool.query<{ created_at: Date }>(
      `SELECT created_at FROM events WHERE id = $1`,
      [row.id],
    );
    const view = this.mapEvent({ ...row, created_at: rows[0]?.created_at ?? new Date() });
    view.ticketTiers = await this.loadTiersForEvent(actor.tenantId, row.id);
    return view;
  }

  async create(actor: CommerceActor, body: Record<string, unknown>): Promise<EventView> {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const title = String(body.title ?? '').trim();
    if (!title) {
      throw new UnprocessableEntityException({ code: 'INVALID_TITLE', message: 'Title required' });
    }
    const slug = await this.uniqueSlug(actor.tenantId, this.access.slugify(title));
    const externalRef = `evt_${slug.replace(/-/g, '_')}`;
    const startsAt = body.startsAt ? new Date(String(body.startsAt)) : new Date();
    const endsAt = body.endsAt ? new Date(String(body.endsAt)) : null;
    const metadata = this.buildMetadata(body);
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO events (tenant_id, organizer_id, title, slug, status, starts_at, ends_at, external_ref, metadata)
       VALUES ($1, $2, $3, $4, 'draft', $5, $6, $7, $8::jsonb)
       RETURNING id`,
      [actor.tenantId, organizerId, title, slug, startsAt, endsAt, externalRef, JSON.stringify(metadata)],
    );
    const eventId = rows[0]!.id;
    const tiers = body.ticketTiers as Array<Record<string, unknown>> | undefined;
    if (tiers?.length) {
      for (const t of tiers) {
        await this.insertTier(actor.tenantId, eventId, t);
      }
    }
    return this.getForOrganizer(actor, eventId);
  }

  async patch(actor: CommerceActor, eventKey: string, body: Record<string, unknown>): Promise<EventView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const metadata = { ...event.metadata, ...this.buildMetadata(body) };
    const title = body.title != null ? String(body.title).trim() : event.title;
    await this.pool.query(
      `UPDATE events
       SET title = $3,
           starts_at = COALESCE($4::timestamptz, starts_at),
           ends_at = COALESCE($5::timestamptz, ends_at),
           metadata = $6::jsonb,
           updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [
        event.id,
        actor.tenantId,
        title,
        body.startsAt ? new Date(String(body.startsAt)) : null,
        body.endsAt ? new Date(String(body.endsAt)) : null,
        JSON.stringify(metadata),
      ],
    );
    return this.getForOrganizer(actor, event.id);
  }

  async publish(actor: CommerceActor, eventKey: string): Promise<EventView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const metadata = {
      ...event.metadata,
      publishedAt: new Date().toISOString(),
    };
    await this.pool.query(
      `UPDATE events SET status = 'published', metadata = $3::jsonb, updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [event.id, actor.tenantId, JSON.stringify(metadata)],
    );
    return this.getForOrganizer(actor, event.id);
  }

  async goLive(actor: CommerceActor, eventKey: string): Promise<EventView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.pool.query(
      `UPDATE events SET status = 'live', updated_at = now() WHERE id = $1 AND tenant_id = $2`,
      [event.id, actor.tenantId],
    );
    return this.getForOrganizer(actor, event.id);
  }

  private buildMetadata(body: Record<string, unknown>): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    const keys = [
      'tagline', 'description', 'city', 'venue', 'category', 'venueType', 'tags',
      'bannerLabel', 'mediaLabels', 'coverGradientStart', 'coverGradientEnd', 'isFeatured',
    ];
    for (const k of keys) {
      if (body[k] !== undefined) out[k] = body[k];
    }
    return out;
  }

  private async uniqueSlug(tenantId: string, base: string): Promise<string> {
    let slug = base;
    let n = 0;
    while (true) {
      const { rows } = await this.pool.query(
        `SELECT 1 FROM events WHERE tenant_id = $1 AND slug = $2`,
        [tenantId, slug],
      );
      if (!rows.length) return slug;
      n += 1;
      slug = `${base}-${n}`;
    }
  }

  async loadTiersForEvent(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      external_tier_id: string;
      name: string;
      description: string;
      tier_type: string;
      price_minor: string;
      currency: string;
      capacity: number;
      remaining: number;
      sales_paused: boolean;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, external_tier_id, name, description, tier_type, price_minor::text, currency,
              capacity, remaining, sales_paused, metadata
       FROM event_ticket_tiers WHERE tenant_id = $1 AND event_id = $2 ORDER BY price_minor ASC`,
      [tenantId, eventId],
    );
    return rows.map((t) => ({
      id: t.external_tier_id,
      tierId: t.id,
      name: t.name,
      description: t.description,
      tierType: t.tier_type,
      priceMinor: t.price_minor,
      currency: t.currency,
      capacity: t.capacity,
      remaining: t.remaining,
      salesPaused: t.sales_paused,
      visibility: (t.metadata?.visibility as string) ?? 'publicListing',
      salesStartAt: t.metadata?.salesStartAt ?? null,
      salesEndAt: t.metadata?.salesEndAt ?? null,
    }));
  }

  private async insertTier(tenantId: string, eventId: string, t: Record<string, unknown>) {
    const externalId = String(t.id ?? t.externalTierId ?? `tier_${Date.now()}`);
    const capacity = Number(t.capacity ?? 0);
    const remaining = Number(t.remaining ?? capacity);
    const meta = {
      visibility: t.visibility ?? 'publicListing',
      salesStartAt: t.salesStartAt ?? null,
      salesEndAt: t.salesEndAt ?? null,
    };
    await this.pool.query(
      `INSERT INTO event_ticket_tiers (
         tenant_id, event_id, external_tier_id, name, description, tier_type,
         price_minor, currency, capacity, remaining, sales_paused, metadata
       ) VALUES ($1, $2, $3, $4, $5, $6, $7::bigint, $8, $9, $10, $11, $12::jsonb)
       ON CONFLICT (tenant_id, event_id, external_tier_id) DO UPDATE SET
         name = EXCLUDED.name,
         description = EXCLUDED.description,
         tier_type = EXCLUDED.tier_type,
         price_minor = EXCLUDED.price_minor,
         capacity = EXCLUDED.capacity,
         remaining = EXCLUDED.remaining,
         metadata = EXCLUDED.metadata,
         updated_at = now()`,
      [
        tenantId,
        eventId,
        externalId,
        String(t.name ?? 'Ticket'),
        String(t.description ?? ''),
        String(t.tierType ?? t.tier_type ?? 'regular'),
        String(t.priceMinor ?? t.price_minor ?? '0'),
        String(t.currency ?? 'NGN'),
        capacity,
        remaining,
        t.salesPaused === true,
        JSON.stringify(meta),
      ],
    );
  }
}
