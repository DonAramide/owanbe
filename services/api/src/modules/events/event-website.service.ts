import { BadRequestException, Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

export const WEBSITE_TEMPLATES = [
  'wedding_classic',
  'traditional_wedding',
  'birthday_celebration',
  'corporate_event',
  'naming_ceremony',
] as const;

export type WebsiteTemplateId = (typeof WEBSITE_TEMPLATES)[number];

export const DEFAULT_WEBSITE_SECTIONS: Record<string, boolean> = {
  our_story: true,
  event_details: true,
  gallery: true,
  rsvp: true,
  registry: false,
  directions: true,
  accommodation: false,
  vendors: false,
};

export type EventWebsiteView = {
  eventId: string;
  eventTitle: string;
  status: 'draft' | 'published';
  templateId: WebsiteTemplateId;
  publicSlug: string;
  publicUrl: string;
  themeColor: string;
  fontPair: string;
  coverImageUrl: string | null;
  heroImageUrl: string | null;
  sections: Record<string, boolean>;
  publishedAt: string | null;
  updatedAt: string;
};

@Injectable()
export class EventWebsiteService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  private publicBaseUrl(): string {
    const fromEnv = process.env.PUBLIC_SITE_BASE_URL?.replace(/\/$/, '');
    return fromEnv && fromEnv.length > 0 ? fromEnv : 'https://owanbe.com';
  }

  private buildPublicUrl(slug: string): string {
    return `${this.publicBaseUrl()}/e/${slug}`;
  }

  private normalizeSections(input: unknown): Record<string, boolean> {
    const out = { ...DEFAULT_WEBSITE_SECTIONS };
    if (input && typeof input === 'object' && !Array.isArray(input)) {
      for (const key of Object.keys(DEFAULT_WEBSITE_SECTIONS)) {
        const v = (input as Record<string, unknown>)[key];
        if (typeof v === 'boolean') out[key] = v;
      }
    }
    return out;
  }

  private rowToView(row: {
    event_id: string;
    event_title: string;
    status: string;
    template_id: string;
    public_slug: string;
    theme_color: string;
    font_pair: string;
    cover_image_url: string | null;
    hero_image_url: string | null;
    sections: Record<string, boolean>;
    published_at: Date | null;
    updated_at: Date;
  }): EventWebsiteView {
    return {
      eventId: row.event_id,
      eventTitle: row.event_title,
      status: row.status as 'draft' | 'published',
      templateId: row.template_id as WebsiteTemplateId,
      publicSlug: row.public_slug,
      publicUrl: this.buildPublicUrl(row.public_slug),
      themeColor: row.theme_color,
      fontPair: row.font_pair,
      coverImageUrl: row.cover_image_url,
      heroImageUrl: row.hero_image_url,
      sections: this.normalizeSections(row.sections),
      publishedAt: row.published_at?.toISOString() ?? null,
      updatedAt: row.updated_at.toISOString(),
    };
  }

  private async ensureRow(tenantId: string, eventId: string, eventTitle: string, slug: string) {
    await this.pool.query(
      `INSERT INTO event_websites (
         tenant_id, event_id, public_slug, sections
       ) VALUES ($1, $2, $3, $4::jsonb)
       ON CONFLICT (tenant_id, event_id) DO NOTHING`,
      [tenantId, eventId, slug, JSON.stringify(DEFAULT_WEBSITE_SECTIONS)],
    );
    const { rows } = await this.pool.query<{
      event_id: string;
      event_title: string;
      status: string;
      template_id: string;
      public_slug: string;
      theme_color: string;
      font_pair: string;
      cover_image_url: string | null;
      hero_image_url: string | null;
      sections: Record<string, boolean>;
      published_at: Date | null;
      updated_at: Date;
    }>(
      `SELECT w.event_id, e.title AS event_title, w.status, w.template_id, w.public_slug,
              w.theme_color, w.font_pair, w.cover_image_url, w.hero_image_url, w.sections,
              w.published_at, w.updated_at
       FROM event_websites w
       INNER JOIN events e ON e.id = w.event_id
       WHERE w.tenant_id = $1 AND w.event_id = $2`,
      [tenantId, eventId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'WEBSITE_NOT_FOUND', message: 'Event website not found' });
    }
    return this.rowToView({ ...row, event_title: row.event_title ?? eventTitle });
  }

  async getForOrganizer(actor: CommerceActor, eventKey: string): Promise<EventWebsiteView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    return this.ensureRow(actor.tenantId, event.id, event.title, event.slug);
  }

  async patch(actor: CommerceActor, eventKey: string, body: Record<string, unknown>): Promise<EventWebsiteView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.ensureRow(actor.tenantId, event.id, event.title, event.slug);

    const templateId = body.templateId ?? body.template_id;
    if (templateId != null && !WEBSITE_TEMPLATES.includes(templateId as WebsiteTemplateId)) {
      throw new BadRequestException({ code: 'INVALID_TEMPLATE', message: 'Unknown website template' });
    }

    const sections = body.sections != null ? this.normalizeSections(body.sections) : null;

    await this.pool.query(
      `UPDATE event_websites SET
         template_id = COALESCE($3, template_id),
         theme_color = COALESCE($4, theme_color),
         font_pair = COALESCE($5, font_pair),
         cover_image_url = COALESCE($6, cover_image_url),
         hero_image_url = COALESCE($7, hero_image_url),
         sections = COALESCE($8::jsonb, sections),
         updated_at = now()
       WHERE tenant_id = $1 AND event_id = $2`,
      [
        actor.tenantId,
        event.id,
        typeof templateId === 'string' ? templateId : null,
        typeof body.themeColor === 'string' ? body.themeColor : typeof body.theme_color === 'string' ? body.theme_color : null,
        typeof body.fontPair === 'string' ? body.fontPair : typeof body.font_pair === 'string' ? body.font_pair : null,
        typeof body.coverImageUrl === 'string' ? body.coverImageUrl : typeof body.cover_image_url === 'string' ? body.cover_image_url : null,
        typeof body.heroImageUrl === 'string' ? body.heroImageUrl : typeof body.hero_image_url === 'string' ? body.hero_image_url : null,
        sections ? JSON.stringify(sections) : null,
      ],
    );

    return this.ensureRow(actor.tenantId, event.id, event.title, event.slug);
  }

  async publish(actor: CommerceActor, eventKey: string): Promise<EventWebsiteView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.ensureRow(actor.tenantId, event.id, event.title, event.slug);
    await this.pool.query(
      `UPDATE event_websites SET status = 'published', published_at = COALESCE(published_at, now()), updated_at = now()
       WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );
    return this.ensureRow(actor.tenantId, event.id, event.title, event.slug);
  }

  async unpublish(actor: CommerceActor, eventKey: string): Promise<EventWebsiteView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.pool.query(
      `UPDATE event_websites SET status = 'draft', updated_at = now()
       WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );
    return this.ensureRow(actor.tenantId, event.id, event.title, event.slug);
  }

  async getPublic(tenantId: string, slug: string): Promise<EventWebsiteView> {
    const { rows } = await this.pool.query<{
      event_id: string;
      event_title: string;
      status: string;
      template_id: string;
      public_slug: string;
      theme_color: string;
      font_pair: string;
      cover_image_url: string | null;
      hero_image_url: string | null;
      sections: Record<string, boolean>;
      published_at: Date | null;
      updated_at: Date;
    }>(
      `SELECT w.event_id, e.title AS event_title, w.status, w.template_id, w.public_slug,
              w.theme_color, w.font_pair, w.cover_image_url, w.hero_image_url, w.sections,
              w.published_at, w.updated_at
       FROM event_websites w
       INNER JOIN events e ON e.id = w.event_id AND e.tenant_id = w.tenant_id
       WHERE w.tenant_id = $1 AND w.public_slug = $2 AND w.status = 'published'
         AND e.status::text IN ('published', 'live', 'completed')
       LIMIT 1`,
      [tenantId, slug],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'WEBSITE_NOT_FOUND', message: 'Published event website not found' });
    }
    return this.rowToView(row);
  }
}
