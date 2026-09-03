import { BadRequestException, Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';
import {
  DEFAULT_RESOURCE_SEEDS,
  normalizeTaxonomySlug,
  parseBusinessCapabilityKey,
  parseOfferingKind,
  type OfferingKind,
  type VendorBusinessCapabilityKey,
} from './vendor-taxonomy.util';

type CapabilityRow = {
  id: string;
  capability_key: string;
  label: string;
  description: string;
  is_active: boolean;
  sort_order: number;
};

type ResourceRow = {
  id: string;
  slug: string;
  label: string;
  description: string;
  is_active: boolean;
  sort_order: number;
};

type CategoryRow = {
  id: string;
  slug: string;
  label: string;
  icon_key: string | null;
  sort_order: number;
  is_active: boolean;
  offering_kind: string;
  parent_id: string | null;
  metadata: unknown;
};

@Injectable()
export class VendorTaxonomyService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async ensureBusinessCapabilities(tenantId: string) {
    await this.pool.query(
      `INSERT INTO tenant_vendor_business_capabilities
         (tenant_id, capability_key, label, description, is_active, sort_order)
       VALUES
         ($1, 'SERVICE_PROVIDER', 'Service Provider',
          'Vendor performs a service (e.g. DJ, catering). Organizers book the service.', true, 0),
         ($1, 'RENTAL_PROVIDER', 'Rental Provider',
          'Vendor supplies rental packages/sets of equipment or resources.', true, 1)
       ON CONFLICT (tenant_id, capability_key) DO NOTHING`,
      [tenantId],
    );
  }

  async ensureResourceCatalog(tenantId: string) {
    for (const r of DEFAULT_RESOURCE_SEEDS) {
      await this.pool.query(
        `INSERT INTO tenant_vendor_resource_catalog
           (tenant_id, slug, label, description, is_active, sort_order)
         VALUES ($1, $2, $3, $4, true, $5)
         ON CONFLICT (tenant_id, slug) DO NOTHING`,
        [tenantId, r.slug, r.label, r.description, r.sortOrder],
      );
    }
  }

  async listBusinessCapabilities(tenantId: string) {
    await this.ensureBusinessCapabilities(tenantId);
    const { rows } = await this.pool.query<CapabilityRow>(
      `SELECT id, capability_key, label, description, is_active, sort_order
       FROM tenant_vendor_business_capabilities
       WHERE tenant_id = $1
       ORDER BY sort_order ASC, capability_key ASC`,
      [tenantId],
    );
    return { items: rows.map((r) => this.mapCapability(r)) };
  }

  async listActiveBusinessCapabilities(tenantId: string) {
    await this.ensureBusinessCapabilities(tenantId);
    const { rows } = await this.pool.query<CapabilityRow>(
      `SELECT id, capability_key, label, description, is_active, sort_order
       FROM tenant_vendor_business_capabilities
       WHERE tenant_id = $1 AND is_active = true
       ORDER BY sort_order ASC, capability_key ASC`,
      [tenantId],
    );
    return { items: rows.map((r) => this.mapCapability(r)) };
  }

  async patchBusinessCapability(
    tenantId: string,
    actorUserId: string,
    body: Record<string, unknown>,
  ) {
    await this.ensureBusinessCapabilities(tenantId);
    const key = parseBusinessCapabilityKey(body.capabilityKey ?? body.capability_key);
    if (!key) {
      throw new BadRequestException({
        code: 'INVALID_CAPABILITY',
        message: 'capabilityKey must be SERVICE_PROVIDER or RENTAL_PROVIDER',
      });
    }
    const { rows: prev } = await this.pool.query<CapabilityRow>(
      `SELECT id, capability_key, label, description, is_active, sort_order
       FROM tenant_vendor_business_capabilities
       WHERE tenant_id = $1 AND capability_key = $2`,
      [tenantId, key],
    );
    if (!prev.length) throw new NotFoundException({ code: 'CAPABILITY_NOT_FOUND' });

    const hasActive = body.isActive !== undefined || body.is_active !== undefined;
    const isActive = hasActive
      ? body.isActive !== false && body.isActive !== 'false' && body.is_active !== false
      : prev[0]!.is_active;
    const label = body.label != null ? String(body.label).trim() : prev[0]!.label;
    const description =
      body.description != null ? String(body.description).trim() : prev[0]!.description;
    if (!label) throw new BadRequestException({ code: 'INVALID_LABEL', message: 'label required' });

    const { rows } = await this.pool.query<CapabilityRow>(
      `UPDATE tenant_vendor_business_capabilities
       SET label = $3, description = $4, is_active = $5, updated_at = now()
       WHERE tenant_id = $1 AND capability_key = $2
       RETURNING id, capability_key, label, description, is_active, sort_order`,
      [tenantId, key, label, description, isActive],
    );
    const next = rows[0]!;
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'vendor_taxonomy.business_capability.update',
      resourceType: 'tenant_vendor_business_capabilities',
      resourceId: next.id,
      metadata: { capabilityKey: key, before: this.mapCapability(prev[0]!), after: this.mapCapability(next) },
    });
    return this.mapCapability(next);
  }

  async listOfferingCategories(tenantId: string, kind?: OfferingKind | null) {
    const params: unknown[] = [tenantId];
    let kindSql = '';
    if (kind && kind !== 'unclassified') {
      params.push(kind);
      kindSql = ` AND offering_kind = $${params.length}`;
    }
    const { rows } = await this.pool.query<CategoryRow>(
      `SELECT id, slug, label, icon_key, sort_order, is_active, offering_kind, parent_id, metadata
       FROM tenant_vendor_categories
       WHERE tenant_id = $1${kindSql}
       ORDER BY sort_order ASC, label ASC`,
      params,
    );
    return { items: rows.map((r) => this.mapCategory(r)) };
  }

  async listActiveOfferingCategories(tenantId: string, kind?: OfferingKind | null) {
    const params: unknown[] = [tenantId];
    let kindSql = '';
    if (kind && kind !== 'unclassified') {
      params.push(kind);
      kindSql = ` AND offering_kind = $${params.length}`;
    }
    const { rows } = await this.pool.query<CategoryRow>(
      `SELECT id, slug, label, icon_key, sort_order, is_active, offering_kind, parent_id, metadata
       FROM tenant_vendor_categories
       WHERE tenant_id = $1 AND is_active = true${kindSql}
       ORDER BY sort_order ASC, label ASC`,
      params,
    );
    return { items: rows.map((r) => this.mapCategory(r)) };
  }

  async listActiveResources(tenantId: string) {
    await this.ensureResourceCatalog(tenantId);
    const { rows } = await this.pool.query<ResourceRow>(
      `SELECT id, slug, label, description, is_active, sort_order
       FROM tenant_vendor_resource_catalog
       WHERE tenant_id = $1 AND is_active = true
       ORDER BY sort_order ASC, label ASC`,
      [tenantId],
    );
    return { items: rows.map((r) => this.mapResource(r)) };
  }

  async upsertOfferingCategory(tenantId: string, actorUserId: string, body: Record<string, unknown>) {
    const id = body.id ? String(body.id).trim() : '';
    const label = String(body.label ?? '').trim();
    const slugInput = String(body.slug ?? '').trim();
    const slug = normalizeTaxonomySlug(slugInput || label);
    const kind = parseOfferingKind(body.offeringKind ?? body.offering_kind ?? body.kind);
    if (!label) throw new BadRequestException({ code: 'INVALID_LABEL', message: 'label required' });
    if (!slug) throw new BadRequestException({ code: 'INVALID_SLUG', message: 'slug required' });
    if (!kind || kind === 'unclassified') {
      throw new BadRequestException({
        code: 'INVALID_OFFERING_KIND',
        message: 'offeringKind must be service or rental',
      });
    }

    const iconKey = body.iconKey != null ? String(body.iconKey).trim() : 'storefront';
    const sortOrder = Number(body.sortOrder ?? body.sort_order ?? 100);
    const hasActive = body.isActive !== undefined || body.is_active !== undefined;
    const isActive = hasActive
      ? body.isActive !== false && body.isActive !== 'false' && body.is_active !== false
      : true;
    const parentIdRaw = body.parentId ?? body.parent_id;
    const parentId =
      parentIdRaw == null || String(parentIdRaw).trim() === '' ? null : String(parentIdRaw).trim();

    if (parentId) {
      const { rows: parents } = await this.pool.query<{ id: string; offering_kind: string }>(
        `SELECT id, offering_kind FROM tenant_vendor_categories WHERE tenant_id = $1 AND id = $2`,
        [tenantId, parentId],
      );
      if (!parents.length) throw new BadRequestException({ code: 'PARENT_NOT_FOUND' });
      if (parents[0]!.offering_kind !== kind && parents[0]!.offering_kind !== 'unclassified') {
        throw new BadRequestException({
          code: 'PARENT_KIND_MISMATCH',
          message: 'Parent category must be the same offering kind',
        });
      }
      if (id && parentId === id) {
        throw new BadRequestException({ code: 'INVALID_PARENT', message: 'Category cannot parent itself' });
      }
    }

    if (id) {
      const { rows: existing } = await this.pool.query<CategoryRow>(
        `SELECT id, slug, label, icon_key, sort_order, is_active, offering_kind, parent_id, metadata
         FROM tenant_vendor_categories WHERE tenant_id = $1 AND id = $2`,
        [tenantId, id],
      );
      if (!existing.length) throw new NotFoundException({ code: 'CATEGORY_NOT_FOUND' });
      if (existing[0]!.slug !== slug) {
        const { rows: clash } = await this.pool.query(
          `SELECT 1 FROM tenant_vendor_categories WHERE tenant_id = $1 AND slug = $2 AND id <> $3`,
          [tenantId, slug, id],
        );
        if (clash.length) {
          throw new BadRequestException({ code: 'SLUG_IN_USE', message: 'Another category already uses this slug' });
        }
      }

      const { rows } = await this.pool.query<CategoryRow>(
        `UPDATE tenant_vendor_categories
         SET slug = $3, label = $4, icon_key = $5, sort_order = $6, is_active = $7,
             offering_kind = $8, parent_id = $9::uuid, updated_at = now()
         WHERE tenant_id = $1 AND id = $2
         RETURNING id, slug, label, icon_key, sort_order, is_active, offering_kind, parent_id, metadata`,
        [tenantId, id, slug, label, iconKey || 'storefront', sortOrder, isActive, kind, parentId],
      );
      const next = rows[0]!;
      await this.audit.logAction({
        tenantId,
        actorUserId,
        action: 'vendor_taxonomy.offering_category.update',
        resourceType: 'tenant_vendor_categories',
        resourceId: next.id,
        metadata: { before: this.mapCategory(existing[0]!), after: this.mapCategory(next) },
      });
      return this.mapCategory(next);
    }

    try {
      const { rows } = await this.pool.query<CategoryRow>(
        `INSERT INTO tenant_vendor_categories
           (tenant_id, slug, label, icon_key, sort_order, is_active, offering_kind, parent_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8::uuid)
         RETURNING id, slug, label, icon_key, sort_order, is_active, offering_kind, parent_id, metadata`,
        [tenantId, slug, label, iconKey || 'storefront', sortOrder, isActive, kind, parentId],
      );
      const next = rows[0]!;
      await this.audit.logAction({
        tenantId,
        actorUserId,
        action: 'vendor_taxonomy.offering_category.create',
        resourceType: 'tenant_vendor_categories',
        resourceId: next.id,
        metadata: { after: this.mapCategory(next) },
      });
      return this.mapCategory(next);
    } catch (err: unknown) {
      const code = (err as { code?: string }).code;
      if (code === '23505') {
        throw new BadRequestException({ code: 'SLUG_IN_USE', message: 'A category with this slug already exists' });
      }
      throw err;
    }
  }

  async listResources(tenantId: string) {
    await this.ensureResourceCatalog(tenantId);
    const { rows } = await this.pool.query<ResourceRow>(
      `SELECT id, slug, label, description, is_active, sort_order
       FROM tenant_vendor_resource_catalog
       WHERE tenant_id = $1
       ORDER BY sort_order ASC, label ASC`,
      [tenantId],
    );
    return { items: rows.map((r) => this.mapResource(r)) };
  }

  async upsertResource(tenantId: string, actorUserId: string, body: Record<string, unknown>) {
    await this.ensureResourceCatalog(tenantId);
    const id = body.id ? String(body.id).trim() : '';
    const label = String(body.label ?? '').trim();
    const slug = normalizeTaxonomySlug(String(body.slug ?? label));
    if (!label) throw new BadRequestException({ code: 'INVALID_LABEL', message: 'label required' });
    if (!slug) throw new BadRequestException({ code: 'INVALID_SLUG', message: 'slug required' });
    const description = String(body.description ?? '').trim();
    const sortOrder = Number(body.sortOrder ?? body.sort_order ?? 100);
    const hasActive = body.isActive !== undefined || body.is_active !== undefined;
    const isActive = hasActive
      ? body.isActive !== false && body.isActive !== 'false' && body.is_active !== false
      : true;

    if (id) {
      const { rows: existing } = await this.pool.query<ResourceRow>(
        `SELECT id, slug, label, description, is_active, sort_order
         FROM tenant_vendor_resource_catalog WHERE tenant_id = $1 AND id = $2`,
        [tenantId, id],
      );
      if (!existing.length) throw new NotFoundException({ code: 'RESOURCE_NOT_FOUND' });
      const { rows } = await this.pool.query<ResourceRow>(
        `UPDATE tenant_vendor_resource_catalog
         SET slug = $3, label = $4, description = $5, is_active = $6, sort_order = $7, updated_at = now()
         WHERE tenant_id = $1 AND id = $2
         RETURNING id, slug, label, description, is_active, sort_order`,
        [tenantId, id, slug, label, description, isActive, sortOrder],
      );
      const next = rows[0]!;
      await this.audit.logAction({
        tenantId,
        actorUserId,
        action: 'vendor_taxonomy.resource.update',
        resourceType: 'tenant_vendor_resource_catalog',
        resourceId: next.id,
        metadata: { before: this.mapResource(existing[0]!), after: this.mapResource(next) },
      });
      return this.mapResource(next);
    }

    try {
      const { rows } = await this.pool.query<ResourceRow>(
        `INSERT INTO tenant_vendor_resource_catalog
           (tenant_id, slug, label, description, is_active, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, slug, label, description, is_active, sort_order`,
        [tenantId, slug, label, description, isActive, sortOrder],
      );
      const next = rows[0]!;
      await this.audit.logAction({
        tenantId,
        actorUserId,
        action: 'vendor_taxonomy.resource.create',
        resourceType: 'tenant_vendor_resource_catalog',
        resourceId: next.id,
        metadata: { after: this.mapResource(next) },
      });
      return this.mapResource(next);
    } catch (err: unknown) {
      const code = (err as { code?: string }).code;
      if (code === '23505') {
        throw new BadRequestException({ code: 'SLUG_IN_USE', message: 'A resource with this slug already exists' });
      }
      throw err;
    }
  }

  private mapCapability(r: CapabilityRow) {
    return {
      id: r.id,
      capabilityKey: r.capability_key as VendorBusinessCapabilityKey,
      label: r.label,
      description: r.description,
      isActive: r.is_active !== false,
      sortOrder: r.sort_order,
    };
  }

  mapCategory(r: CategoryRow) {
    return {
      id: r.id,
      slug: r.slug,
      label: r.label,
      iconKey: r.icon_key,
      sortOrder: r.sort_order,
      isActive: r.is_active !== false,
      offeringKind: (parseOfferingKind(r.offering_kind) ?? 'unclassified') as OfferingKind,
      parentId: r.parent_id,
    };
  }

  private mapResource(r: ResourceRow) {
    return {
      id: r.id,
      slug: r.slug,
      label: r.label,
      description: r.description,
      isActive: r.is_active !== false,
      sortOrder: r.sort_order,
    };
  }
}
