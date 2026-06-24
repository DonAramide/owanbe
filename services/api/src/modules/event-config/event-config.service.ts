import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

type ConfigRow = {
  id: string;
  slug: string;
  label: string;
  sort_order: number;
  is_active: boolean;
  metadata?: Record<string, unknown>;
  description?: string | null;
  icon_key?: string | null;
  access_mode?: string;
  category_slug?: string | null;
  checklist?: unknown;
  vendor_hints?: unknown;
  budget_hints?: unknown;
  allocations?: unknown;
};

@Injectable()
export class EventConfigService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async listCategories(tenantId: string) {
    const { rows } = await this.pool.query<ConfigRow>(
      `SELECT id, slug, label, description, icon_key, access_mode::text, sort_order, is_active, metadata
       FROM tenant_event_categories
       WHERE tenant_id = $1 AND is_active = true
       ORDER BY sort_order ASC, label ASC`,
      [tenantId],
    );
    return { items: rows.map((r) => this.mapCategory(r)) };
  }

  async listTags(tenantId: string) {
    const { rows } = await this.pool.query<ConfigRow>(
      `SELECT id, slug, label, sort_order, is_active
       FROM tenant_event_tags
       WHERE tenant_id = $1 AND is_active = true
       ORDER BY sort_order ASC, label ASC`,
      [tenantId],
    );
    return { items: rows.map((r) => ({ id: r.id, slug: r.slug, label: r.label })) };
  }

  async listTemplates(tenantId: string) {
    const { rows } = await this.pool.query<ConfigRow>(
      `SELECT id, slug, label, category_slug, access_mode::text, checklist, vendor_hints, budget_hints, sort_order
       FROM tenant_event_templates
       WHERE tenant_id = $1 AND is_active = true
       ORDER BY sort_order ASC, label ASC`,
      [tenantId],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        slug: r.slug,
        label: r.label,
        categorySlug: r.category_slug,
        accessMode: r.access_mode,
        checklist: r.checklist ?? [],
        vendorHints: r.vendor_hints ?? [],
        budgetHints: r.budget_hints ?? {},
      })),
    };
  }

  async listVendorCategories(tenantId: string) {
    await this.seedVendorCategoriesIfEmpty(tenantId);
    await this.ensureFashionAttireCategories(tenantId);
    await this.ensureRentalCategories(tenantId);
    const { rows } = await this.pool.query<ConfigRow>(
      `SELECT id, slug, label, icon_key, sort_order
       FROM tenant_vendor_categories
       WHERE tenant_id = $1 AND is_active = true
       ORDER BY sort_order ASC, label ASC`,
      [tenantId],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        slug: r.slug,
        label: r.label,
        iconKey: r.icon_key,
      })),
    };
  }

  async listBudgetTemplates(tenantId: string) {
    const { rows } = await this.pool.query<ConfigRow>(
      `SELECT id, slug, label, category_slug, access_mode::text, allocations, sort_order
       FROM tenant_budget_templates
       WHERE tenant_id = $1 AND is_active = true
       ORDER BY sort_order ASC, label ASC`,
      [tenantId],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        slug: r.slug,
        label: r.label,
        categorySlug: r.category_slug,
        accessMode: r.access_mode,
        allocations: r.allocations ?? [],
      })),
    };
  }

  async adminListCategories(tenantId: string) {
    const { rows } = await this.pool.query<ConfigRow>(
      `SELECT id, slug, label, description, icon_key, access_mode::text, sort_order, is_active, metadata
       FROM tenant_event_categories WHERE tenant_id = $1 ORDER BY sort_order ASC`,
      [tenantId],
    );
    return { items: rows.map((r) => this.mapCategory(r)) };
  }

  async adminUpsertCategory(tenantId: string, body: Record<string, unknown>) {
    const slug = String(body.slug ?? '').trim();
    const label = String(body.label ?? '').trim();
    if (!slug || !label) throw new NotFoundException({ code: 'INVALID_CATEGORY' });
    const id = body.id ? String(body.id) : null;
    if (id) {
      await this.pool.query(
        `UPDATE tenant_event_categories SET
           slug = $3, label = $4, description = $5, icon_key = $6,
           access_mode = $7::event_access_mode, sort_order = $8, is_active = $9,
           metadata = $10::jsonb, updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [
          tenantId,
          id,
          slug,
          label,
          body.description ?? null,
          body.iconKey ?? null,
          String(body.accessMode ?? 'PRIVATE_INVITATION'),
          Number(body.sortOrder ?? 0),
          body.isActive !== false,
          JSON.stringify(body.metadata ?? {}),
        ],
      );
      return { id };
    }
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO tenant_event_categories
         (tenant_id, slug, label, description, icon_key, access_mode, sort_order, is_active, metadata)
       VALUES ($1, $2, $3, $4, $5, $6::event_access_mode, $7, $8, $9::jsonb)
       RETURNING id`,
      [
        tenantId,
        slug,
        label,
        body.description ?? null,
        body.iconKey ?? null,
        String(body.accessMode ?? 'PRIVATE_INVITATION'),
        Number(body.sortOrder ?? 0),
        body.isActive !== false,
        JSON.stringify(body.metadata ?? {}),
      ],
    );
    return { id: rows[0]!.id };
  }

  async adminUpsertTag(tenantId: string, body: Record<string, unknown>) {
    const slug = String(body.slug ?? '').trim();
    const label = String(body.label ?? '').trim();
    if (!slug || !label) throw new NotFoundException({ code: 'INVALID_TAG' });
    const id = body.id ? String(body.id) : null;
    if (id) {
      await this.pool.query(
        `UPDATE tenant_event_tags SET slug = $3, label = $4, sort_order = $5, is_active = $6, updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, id, slug, label, Number(body.sortOrder ?? 0), body.isActive !== false],
      );
      return { id };
    }
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO tenant_event_tags (tenant_id, slug, label, sort_order, is_active) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [tenantId, slug, label, Number(body.sortOrder ?? 0), body.isActive !== false],
    );
    return { id: rows[0]!.id };
  }

  async seedDefaultsIfEmpty(tenantId: string) {
    const { rows } = await this.pool.query(`SELECT 1 FROM tenant_event_categories WHERE tenant_id = $1 LIMIT 1`, [
      tenantId,
    ]);
    if (rows.length) return;
    const categories: Array<[string, string, string, string]> = [
      ['wedding', 'Wedding', 'heart', 'PRIVATE_INVITATION'],
      ['birthday', 'Birthday', 'cake', 'PRIVATE_INVITATION'],
      ['naming-ceremony', 'Naming Ceremony', 'child_care', 'PRIVATE_INVITATION'],
      ['corporate', 'Corporate Event', 'business', 'PRIVATE_INVITATION'],
      ['festival', 'Festival', 'festival', 'PUBLIC_TICKETED'],
      ['conference', 'Conference', 'groups', 'PUBLIC_TICKETED'],
      ['other', 'Other', 'celebration', 'PRIVATE_INVITATION'],
    ];
    for (let i = 0; i < categories.length; i++) {
      const [slug, label, icon, mode] = categories[i]!;
      await this.pool.query(
        `INSERT INTO tenant_event_categories (tenant_id, slug, label, icon_key, access_mode, sort_order)
         VALUES ($1, $2, $3, $4, $5::event_access_mode, $6)`,
        [tenantId, slug, label, icon, mode, i],
      );
    }
    const tags = ['outdoor', 'indoor', 'black-tie', 'family', 'live-music', 'destination'];
    for (let i = 0; i < tags.length; i++) {
      await this.pool.query(
        `INSERT INTO tenant_event_tags (tenant_id, slug, label, sort_order) VALUES ($1, $2, $3, $4)`,
        [tenantId, tags[i], tags[i]!.replace('-', ' '), i],
      );
    }
  }

  async seedVendorCategoriesIfEmpty(tenantId: string) {
    const { rows } = await this.pool.query(
      `SELECT 1 FROM tenant_vendor_categories WHERE tenant_id = $1 LIMIT 1`,
      [tenantId],
    );
    if (rows.length) return;
    const categories: Array<[string, string, string]> = [
      ['venue', 'Venue', 'apartment'],
      ['decorator', 'Decorator', 'brush'],
      ['photographer', 'Photographer', 'photo_camera'],
      ['dj', 'DJ', 'music_note'],
      ['mc', 'MC', 'mic'],
      ['security', 'Security', 'shield'],
      ['cake', 'Cake', 'cake'],
      ['drinks', 'Drinks', 'local_bar'],
      ['ushers', 'Ushers', 'groups'],
      ['live-band', 'Live Band', 'nightlife'],
      ['catering', 'Catering', 'restaurant'],
      ['florist', 'Florist', 'local_florist'],
      ['av-production', 'AV Production', 'videocam'],
      ['fashion-attire', 'Fashion & Attire', 'checkroom'],
      ['aso-ebi', 'Aso-Ebi', 'style'],
      ['traditional-wear', 'Traditional Wear', 'dry_cleaning'],
      ['wedding-gowns', 'Wedding Gowns', 'favorite_border'],
      ['bridesmaid-dresses', 'Bridesmaid Dresses', 'groups'],
      ['suits', 'Suits', 'business_center'],
      ['gele', 'Gele', 'face_retouching_natural'],
      ['fashion-accessories', 'Accessories', 'diamond'],
      ['tailoring', 'Tailoring', 'content_cut'],
    ];
    for (let i = 0; i < categories.length; i++) {
      const [slug, label, icon] = categories[i]!;
      await this.pool.query(
        `INSERT INTO tenant_vendor_categories (tenant_id, slug, label, icon_key, sort_order)
         VALUES ($1, $2, $3, $4, $5)`,
        [tenantId, slug, label, icon, i],
      );
    }
  }

  async ensureFashionAttireCategories(tenantId: string) {
    const categories: Array<[string, string, string, number]> = [
      ['fashion-attire', 'Fashion & Attire', 'checkroom', 50],
      ['aso-ebi', 'Aso-Ebi', 'style', 51],
      ['traditional-wear', 'Traditional Wear', 'dry_cleaning', 52],
      ['wedding-gowns', 'Wedding Gowns', 'favorite_border', 53],
      ['bridesmaid-dresses', 'Bridesmaid Dresses', 'groups', 54],
      ['suits', 'Suits', 'business_center', 55],
      ['gele', 'Gele', 'face_retouching_natural', 56],
      ['fashion-accessories', 'Accessories', 'diamond', 57],
      ['tailoring', 'Tailoring', 'content_cut', 58],
    ];
    for (const [slug, label, icon, sortOrder] of categories) {
      await this.pool.query(
        `INSERT INTO tenant_vendor_categories (tenant_id, slug, label, icon_key, sort_order, is_active)
         VALUES ($1, $2, $3, $4, $5, true)
         ON CONFLICT (tenant_id, slug) DO UPDATE
           SET label = EXCLUDED.label, icon_key = EXCLUDED.icon_key, is_active = true`,
        [tenantId, slug, label, icon, sortOrder],
      );
    }
  }

  async ensureRentalCategories(tenantId: string) {
    const categories: Array<[string, string, string, number]> = [
      ['rentals-equipment', 'Rentals & Event Equipment', 'inventory_2', 60],
      ['chairs', 'Chairs', 'chair', 61],
      ['tables', 'Tables', 'table_restaurant', 62],
      ['canopies', 'Canopies', 'umbrella', 63],
      ['tents', 'Tents', 'cabin', 64],
      ['stage-platforms', 'Stage Platforms', 'foundation', 65],
      ['led-screens', 'LED Screens', 'tv', 66],
      ['sound-systems', 'Sound Systems', 'speaker', 67],
      ['lighting-systems', 'Lighting Systems', 'lightbulb', 68],
      ['generators', 'Generators', 'bolt', 69],
      ['mobile-toilets', 'Mobile Toilets', 'wc', 70],
      ['cooling-fans', 'Cooling Fans', 'mode_fan', 71],
      ['air-conditioners', 'Air Conditioners', 'ac_unit', 72],
      ['dance-floors', 'Dance Floors', 'grid_on', 73],
      ['cutlery-crockery', 'Cutlery & Crockery', 'restaurant', 74],
      ['thrones-vip-seating', 'Thrones & VIP Seating', 'king_bed', 75],
      ['backdrops', 'Backdrops', 'wallpaper', 76],
      ['photo-booths', 'Photo Booths', 'photo_camera', 77],
      ['event-equipment', 'Event Equipment', 'construction', 78],
    ];
    for (const [slug, label, icon, sortOrder] of categories) {
      await this.pool.query(
        `INSERT INTO tenant_vendor_categories (tenant_id, slug, label, icon_key, sort_order, is_active)
         VALUES ($1, $2, $3, $4, $5, true)
         ON CONFLICT (tenant_id, slug) DO UPDATE
           SET label = EXCLUDED.label, icon_key = EXCLUDED.icon_key, is_active = true`,
        [tenantId, slug, label, icon, sortOrder],
      );
    }
  }

  private mapCategory(r: ConfigRow) {
    return {
      id: r.id,
      slug: r.slug,
      label: r.label,
      description: r.description ?? '',
      iconKey: r.icon_key ?? 'celebration',
      accessMode: r.access_mode ?? 'PRIVATE_INVITATION',
      sortOrder: r.sort_order,
      isActive: r.is_active,
      metadata: r.metadata ?? {},
    };
  }
}
