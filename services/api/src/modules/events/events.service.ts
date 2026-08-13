import { Injectable, Inject, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';
import { isPubliclyListable } from '../commerce/ticket-tier-rules';
import {
  isPublicEventPageAllowed,
  isPubliclyDiscoverable,
} from '../commerce/event-visibility-rules';

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
  eventAccessMode: string;
  budgetMinor: string | null;
  expectedGuests: number | null;
  venueName: string;
  venueAddress: string;
  venueLatitude: number | null;
  venueLongitude: number | null;
  googlePlaceId: string | null;
  categorySlug: string | null;
  celebrantImageUrl: string | null;
  ticketTiers?: Array<Record<string, unknown>>;
  ticketsSold?: number;
  revenueMinor?: string;
  attendeeCount?: number;
  ordersCount?: number;
  buyersCount?: number;
  /** Ticket buyers for organizer manage views (from entitlements). */
  attendees?: Array<{
    id: string;
    name: string;
    email: string;
    tierName: string;
    ticketId: string;
    checkedIn: boolean;
    purchasedAt: string | null;
    orderId: string | null;
    orderStatus: string | null;
    entitlementStatus: string;
  }>;
  /** Phase 3 detail content (event metadata; optional). */
  galleryMedia?: Array<{ url: string; type?: string; label?: string }>;
  speakers?: Array<{ name: string; title?: string; bio?: string; imageUrl?: string }>;
  sponsors?: Array<{ name: string; tier?: string; logoUrl?: string; websiteUrl?: string }>;
  faqs?: Array<{ question: string; answer: string }>;
  organizerName?: string | null;
  organizerContactEmail?: string | null;
  organizerContactPhone?: string | null;
  language?: string;
  ageRestrictionMin?: number;
  listingVisibility?: string;
  registrationEnabled?: boolean;
  checkInEnabled?: boolean;
  themeColor?: string;
  requiredServices?: string[];
  venueDeferred?: boolean;
  state?: string;
  lga?: string;
  selectedTemplateSlug?: string | null;
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
      eventAccessMode: String(m.eventAccessMode ?? 'PRIVATE_INVITATION'),
      budgetMinor: m.budgetMinor != null ? String(m.budgetMinor) : null,
      expectedGuests: m.expectedGuests != null ? Number(m.expectedGuests) : null,
      venueName: String(m.venueName ?? m.venue ?? ''),
      venueAddress: String(m.venueAddress ?? ''),
      venueLatitude: m.venueLatitude != null ? Number(m.venueLatitude) : null,
      venueLongitude: m.venueLongitude != null ? Number(m.venueLongitude) : null,
      googlePlaceId: m.googlePlaceId != null ? String(m.googlePlaceId) : null,
      categorySlug: m.categorySlug != null ? String(m.categorySlug) : null,
      celebrantImageUrl: m.celebrantImageUrl != null ? String(m.celebrantImageUrl) : null,
      galleryMedia: Array.isArray(m.galleryMedia) ? (m.galleryMedia as Array<{ url: string; type?: string; label?: string }>) : [],
      speakers: Array.isArray(m.speakers) ? (m.speakers as Array<{ name: string; title?: string; bio?: string; imageUrl?: string }>) : [],
      sponsors: Array.isArray(m.sponsors) ? (m.sponsors as Array<{ name: string; tier?: string; logoUrl?: string; websiteUrl?: string }>) : [],
      faqs: Array.isArray(m.faqs) ? (m.faqs as Array<{ question: string; answer: string }>) : [],
      organizerName: m.organizerName != null ? String(m.organizerName) : null,
      organizerContactEmail: m.organizerContactEmail != null ? String(m.organizerContactEmail) : null,
      organizerContactPhone: m.organizerContactPhone != null ? String(m.organizerContactPhone) : null,
      language: String(m.language ?? 'en'),
      ageRestrictionMin: m.ageRestrictionMin != null ? Number(m.ageRestrictionMin) : 0,
      listingVisibility: String(m.listingVisibility ?? 'invite_only'),
      registrationEnabled: m.registrationEnabled !== false,
      checkInEnabled: m.checkInEnabled !== false,
      themeColor: String(m.themeColor ?? '#4B2C6F'),
      requiredServices: Array.isArray(m.requiredServices) ? (m.requiredServices as string[]) : [],
      venueDeferred: m.venueDeferred === true,
      state: String(m.state ?? ''),
      lga: String(m.lga ?? ''),
      selectedTemplateSlug: m.selectedTemplateSlug != null ? String(m.selectedTemplateSlug) : null,
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
    // Phase 14: Discover / search / featured / trending all share this feed — enforce visibility.
    let items = rows
      .filter((r) => isPubliclyDiscoverable({ status: r.status, metadata: r.metadata }))
      .map((r) => this.mapEvent(r));
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
      item.ticketTiers = await this.loadTiersForEvent(tenantId, item.id, {
        includeArchived: false,
        publicStorefront: true,
      });
      // Lightweight popularity signal for discovery trending (replaceable by analytics engine).
      item.ticketsSold = (item.ticketTiers ?? []).reduce((sum: number, t) => {
        const capacity = Number(t.capacity ?? 0);
        const remaining = Number(t.remaining ?? 0);
        const sold = Math.max(0, capacity - remaining);
        return sum + sold;
      }, 0);
    }
    return { items };
  }

  async getPublic(tenantId: string, eventKey: string): Promise<EventView> {
    const row = await this.access.resolveEventRow(tenantId, eventKey, true);
    if (
      !isPublicEventPageAllowed({
        status: row.status,
        metadata: row.metadata as Record<string, unknown>,
      })
    ) {
      throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found' });
    }
    const { rows } = await this.pool.query<{ created_at: Date }>(
      `SELECT created_at FROM events WHERE id = $1`,
      [row.id],
    );
    const view = this.mapEvent({ ...row, created_at: rows[0]?.created_at ?? new Date() });
    view.ticketTiers = await this.loadTiersForEvent(tenantId, row.id, { includeArchived: false, publicStorefront: true });
    return view;
  }

  async listForOrganizer(
    actor: CommerceActor,
    options?: { q?: string; status?: string; sort?: string },
  ): Promise<{ items: EventView[] }> {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const params: unknown[] = [actor.tenantId, organizerId];
    const clauses = ['tenant_id = $1', 'organizer_id = $2'];
    if (options?.status?.trim()) {
      params.push(options.status.trim().toLowerCase());
      clauses.push(`status::text = $${params.length}`);
    } else {
      // Discarded drafts are soft-cancelled — hide from normal organizer views.
      clauses.push(`status::text <> 'cancelled'`);
    }
    if (options?.q?.trim()) {
      const like = `%${options.q.trim().replace(/%/g, '\\%')}%`;
      params.push(like);
      clauses.push(
        `(title ILIKE $${params.length} OR COALESCE(metadata->>'city', '') ILIKE $${params.length})`,
      );
    }
    const orderBy = (() => {
      switch ((options?.sort ?? 'created_desc').toLowerCase()) {
        case 'starts_asc':
          return 'starts_at ASC';
        case 'starts_desc':
          return 'starts_at DESC';
        case 'title_asc':
          return 'title ASC';
        case 'title_desc':
          return 'title DESC';
        default:
          return 'created_at DESC';
      }
    })();
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
       FROM events WHERE ${clauses.join(' AND ')}
       ORDER BY ${orderBy}`,
      params,
    );
    const items = rows.map((r) => this.mapEvent(r));
    for (const item of items) {
      item.ticketTiers = await this.loadTiersForEvent(actor.tenantId, item.id, { includeArchived: true });
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
    view.ticketTiers = await this.loadTiersForEvent(actor.tenantId, row.id, { includeArchived: true });
    await this.attachOrganizerSalesSnapshot(actor.tenantId, view);
    return view;
  }

  /** Wire real buyers from ticket_entitlements + sales counters for manage UI.
   * Private invitation events also attach guests as attendees when no entitlements yet.
   */
  private async attachOrganizerSalesSnapshot(tenantId: string, view: EventView): Promise<void> {
    const { rows: buyers } = await this.pool.query<{
      id: string;
      ticket_code: string;
      status: string;
      tier_name: string | null;
      created_at: Date;
      order_id: string | null;
      order_status: string | null;
      email: string | null;
      display_name: string | null;
    }>(
      `SELECT te.id, te.ticket_code, te.status::text,
              COALESCE(te.metadata->>'tier_name', tol.tier_name) AS tier_name,
              te.issued_at AS created_at, te.ticket_order_id AS order_id, o.status::text AS order_status,
              u.email, COALESCE(u.display_name, split_part(COALESCE(u.email, ''), '@', 1)) AS display_name
       FROM ticket_entitlements te
       LEFT JOIN ticket_order_lines tol ON tol.id = te.ticket_order_line_id
       LEFT JOIN ticket_orders o ON o.id = te.ticket_order_id
       LEFT JOIN users u ON u.id = te.holder_user_id
       WHERE te.tenant_id = $1 AND te.event_id = $2
       ORDER BY te.issued_at DESC
       LIMIT 500`,
      [tenantId, view.id],
    );

    view.attendees = buyers.map((b) => ({
      id: b.id,
      name: (b.display_name && b.display_name.trim()) || b.email || 'Attendee',
      email: b.email ?? '',
      tierName: b.tier_name ?? 'Ticket',
      ticketId: b.ticket_code,
      checkedIn: b.status === 'checked_in',
      purchasedAt: b.created_at?.toISOString() ?? null,
      orderId: b.order_id,
      orderStatus: b.order_status,
      entitlementStatus: b.status,
    }));

    if (
      (view.attendees?.length ?? 0) === 0 &&
      String(view.eventAccessMode) !== 'PUBLIC_TICKETED'
    ) {
      const { rows: guests } = await this.pool.query<{
        id: string;
        name: string;
        email: string | null;
        rsvp_status: string;
        entitlement_ref: string | null;
        updated_at: Date;
        created_at: Date;
      }>(
        `SELECT id, name, email, rsvp_status::text, entitlement_ref, updated_at, created_at
         FROM event_guests WHERE tenant_id = $1 AND event_id = $2
         ORDER BY name ASC LIMIT 500`,
        [tenantId, view.id],
      );
      view.attendees = guests.map((g) => ({
        id: g.id,
        name: g.name,
        email: g.email ?? '',
        tierName: 'Invitation',
        ticketId: g.entitlement_ref ?? g.rsvp_status,
        checkedIn: false,
        purchasedAt: g.updated_at.toISOString(),
        orderId: null,
        orderStatus: g.rsvp_status,
        entitlementStatus: g.entitlement_ref ? 'issued' : g.rsvp_status,
      }));
    }

    view.attendeeCount = view.attendees?.length ?? 0;
    view.buyersCount = new Set((view.attendees ?? []).map((b) => b.email || b.id)).size;

    const { rows: orderAgg } = await this.pool.query<{
      orders_count: string;
      revenue_minor: string;
    }>(
      `SELECT COUNT(*)::text AS orders_count,
              COALESCE(SUM(subtotal_minor), 0)::text AS revenue_minor
       FROM ticket_orders
       WHERE tenant_id = $1 AND event_id = $2
         AND status::text IN ('confirmed', 'fulfilled')`,
      [tenantId, view.id],
    );
    view.ordersCount = parseInt(orderAgg[0]?.orders_count ?? '0', 10);
    view.revenueMinor = orderAgg[0]?.revenue_minor ?? '0';
    view.ticketsSold = buyers.length;
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
    const accessMode = String(metadata.eventAccessMode ?? 'PRIVATE_INVITATION');
    const tiers = body.ticketTiers as Array<Record<string, unknown>> | undefined;
    if (accessMode === 'PUBLIC_TICKETED' && tiers?.length) {
      for (const t of tiers) {
        await this.insertTier(actor.tenantId, eventId, t);
      }
    }
    return this.getForOrganizer(actor, eventId);
  }

  async patch(actor: CommerceActor, eventKey: string, body: Record<string, unknown>): Promise<EventView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    if (event.status === 'cancelled') {
      throw new UnprocessableEntityException({
        code: 'INVALID_STATUS',
        message: 'Cannot update a discarded draft',
      });
    }
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
    if (Array.isArray(body.ticketTiers)) {
      await this.syncDraftTiers(
        actor.tenantId,
        event.id,
        body.ticketTiers as Array<Record<string, unknown>>,
      );
    }
    return this.getForOrganizer(actor, event.id);
  }

  /**
   * Soft-discard an in-progress wizard draft (status → cancelled).
   * Cancelled events are excluded from normal organizer list/dashboard views.
   */
  async discardDraft(actor: CommerceActor, eventKey: string): Promise<{ ok: true; id: string }> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    if (event.status !== 'draft') {
      throw new UnprocessableEntityException({
        code: 'INVALID_STATUS',
        message: `Only draft events can be discarded (status=${event.status})`,
      });
    }
    const metadata = {
      ...event.metadata,
      discardedAt: new Date().toISOString(),
      discardedReason: 'wizard_discard',
    };
    await this.pool.query(
      `UPDATE events SET status = 'cancelled', metadata = $3::jsonb, updated_at = now()
       WHERE id = $1 AND tenant_id = $2 AND status = 'draft'`,
      [event.id, actor.tenantId, JSON.stringify(metadata)],
    );
    return { ok: true, id: event.id };
  }

  async publish(actor: CommerceActor, eventKey: string): Promise<EventView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    if (event.status !== 'draft' && event.status !== 'published') {
      throw new UnprocessableEntityException({
        code: 'INVALID_STATUS',
        message: `Cannot publish from status ${event.status}`,
      });
    }
    const accessMode = String(event.metadata?.eventAccessMode ?? 'PRIVATE_INVITATION');
    if (accessMode === 'PUBLIC_TICKETED') {
      const tiers = await this.loadTiersForEvent(actor.tenantId, event.id);
      if (!tiers.length) {
        throw new UnprocessableEntityException({
          code: 'TICKETS_REQUIRED',
          message: 'Add at least one ticket tier before publishing a public event',
        });
      }
    }
    if (!event.title?.trim()) {
      throw new UnprocessableEntityException({
        code: 'INVALID_TITLE',
        message: 'Title required before publish',
      });
    }
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
      'eventAccessMode', 'budgetMinor', 'expectedGuests', 'categorySlug',
      'venueName', 'venueAddress', 'venueLatitude', 'venueLongitude', 'googlePlaceId',
      'budgetAllocation', 'selectedTemplateSlug', 'preferredVendorIds',
      'requiredServices', 'venueDeferred', 'state', 'lga', 'celebrantImageUrl',
      'galleryMedia', 'speakers', 'sponsors', 'faqs',
      'organizerName', 'organizerContactEmail', 'organizerContactPhone',
      'language', 'ageRestrictionMin', 'listingVisibility',
      'registrationEnabled', 'checkInEnabled', 'themeColor',
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

  async loadTiersForEvent(
    tenantId: string,
    eventId: string,
    opts?: { includeArchived?: boolean; publicStorefront?: boolean },
  ) {
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
       FROM event_ticket_tiers
       WHERE tenant_id = $1 AND event_id = $2
       ORDER BY COALESCE((metadata->>'sortOrder')::int, 999999) ASC, price_minor ASC`,
      [tenantId, eventId],
    );
    let items = rows.map((t) => {
      const m = t.metadata ?? {};
      return {
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
        visibility: (m.visibility as string) ?? 'publicListing',
        salesStartAt: m.salesStartAt ?? null,
        salesEndAt: m.salesEndAt ?? null,
        benefits: Array.isArray(m.benefits) ? m.benefits : [],
        accessLevel: m.accessLevel != null ? String(m.accessLevel) : null,
        perks: Array.isArray(m.perks) ? m.perks : [],
        restrictions: Array.isArray(m.restrictions) ? m.restrictions : [],
        archived: m.archived === true,
        unlimitedCapacity: m.unlimitedCapacity === true,
        minQuantity: m.minQuantity != null ? Number(m.minQuantity) : 1,
        maxQuantity: m.maxQuantity != null ? Number(m.maxQuantity) : null,
        maxPerUser: m.maxPerUser != null ? Number(m.maxPerUser) : null,
        sortOrder: m.sortOrder != null ? Number(m.sortOrder) : 0,
      };
    });

    if (!opts?.includeArchived) {
      items = items.filter((t) => !t.archived);
    }
    if (opts?.publicStorefront) {
      items = items.filter((t) => {
        const row = rows.find((r) => r.external_tier_id === t.id);
        return isPubliclyListable({
          salesPaused: t.salesPaused,
          metadata: row?.metadata,
        });
      });
    }
    return items;
  }

  private async syncDraftTiers(
    tenantId: string,
    eventId: string,
    tiers: Array<Record<string, unknown>>,
  ): Promise<void> {
    const existing = await this.loadTiersForEvent(tenantId, eventId);
    const keepIds = new Set(
      tiers
        .map((t) => String(t.id ?? t.externalTierId ?? '').trim())
        .filter((id) => id.length > 0),
    );
    for (const e of existing) {
      const externalId = String(e.id ?? '');
      const sold = Number(e.capacity ?? 0) - Number(e.remaining ?? 0);
      if (!keepIds.has(externalId) && sold <= 0) {
        await this.pool.query(
          `DELETE FROM event_ticket_tiers
           WHERE tenant_id = $1 AND event_id = $2 AND external_tier_id = $3
             AND (capacity - remaining) = 0`,
          [tenantId, eventId, externalId],
        );
      }
    }
    for (const t of tiers) {
      await this.insertTier(tenantId, eventId, t);
    }
  }

  private async insertTier(tenantId: string, eventId: string, t: Record<string, unknown>) {
    const externalId = String(t.id ?? t.externalTierId ?? `tier_${Date.now()}`);
    const capacity = Number(t.capacity ?? 0);
    const remaining = Number(t.remaining ?? capacity);
    const meta = {
      visibility: t.visibility ?? 'publicListing',
      salesStartAt: t.salesStartAt ?? null,
      salesEndAt: t.salesEndAt ?? null,
      benefits: t.benefits ?? [],
      accessLevel: t.accessLevel ?? null,
      perks: t.perks ?? [],
      restrictions: t.restrictions ?? [],
      unlimitedCapacity: t.unlimitedCapacity === true,
      minQuantity: t.minQuantity != null ? Number(t.minQuantity) : 1,
      maxQuantity: t.maxQuantity != null ? Number(t.maxQuantity) : null,
      maxPerUser: t.maxPerUser != null ? Number(t.maxPerUser) : null,
      sortOrder: t.sortOrder != null ? Number(t.sortOrder) : 0,
      archived: t.archived === true,
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
