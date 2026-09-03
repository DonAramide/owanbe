import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import { parseBusinessCapabilityKey } from '../event-config/vendor-taxonomy.util';
import { normalizeServiceKey } from './vendor-pricing.util';
import { RentalsService } from '../rentals/rentals.service';

@Injectable()
export class VendorOfferingsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly audit: AuditLogService,
    private readonly rentals: RentalsService,
  ) {}

  private async assertOwns(actor: CommerceActor, vendorId: string) {
    const resolved = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (resolved !== vendorId) {
      throw new ForbiddenException({ code: 'VENDOR_FORBIDDEN', message: 'Not your vendor profile' });
    }
  }

  async getConfig(actor: CommerceActor, vendorId: string) {
    await this.assertOwns(actor, vendorId);
    const caps = await this.pool.query<{ capability_key: string }>(
      `SELECT capability_key FROM vendor_business_capability_assignments
       WHERE tenant_id = $1 AND vendor_id = $2::uuid`,
      [actor.tenantId, vendorId],
    );
    const cats = await this.pool.query<{ category_id: string; offering_kind: string; slug: string; label: string }>(
      `SELECT s.category_id, c.offering_kind, c.slug, c.label
       FROM vendor_offering_category_selections s
       JOIN tenant_vendor_categories c ON c.id = s.category_id
       WHERE s.tenant_id = $1 AND s.vendor_id = $2::uuid`,
      [actor.tenantId, vendorId],
    );
    return {
      capabilityKeys: caps.rows.map((r) => r.capability_key),
      categories: cats.rows.map((r) => ({
        id: r.category_id,
        offeringKind: r.offering_kind,
        slug: r.slug,
        label: r.label,
      })),
    };
  }

  async putCapabilities(actor: CommerceActor, vendorId: string, keysRaw: unknown[]) {
    await this.assertOwns(actor, vendorId);
    const keys = [...new Set(keysRaw.map((k) => parseBusinessCapabilityKey(k)).filter((k): k is NonNullable<typeof k> => !!k))];
    if (keys.length) {
      const { rows: allowed } = await this.pool.query<{ capability_key: string }>(
        `SELECT capability_key FROM tenant_vendor_business_capabilities
         WHERE tenant_id = $1 AND is_active = true`,
        [actor.tenantId],
      );
      const allowedSet = new Set(allowed.map((r) => r.capability_key));
      for (const k of keys) {
        if (!allowedSet.has(k)) {
          throw new BadRequestException({
            code: 'CAPABILITY_INACTIVE',
            message: `${k} is not an active Super Admin definition`,
          });
        }
      }
    }
    await this.pool.query(
      `DELETE FROM vendor_business_capability_assignments WHERE tenant_id = $1 AND vendor_id = $2::uuid`,
      [actor.tenantId, vendorId],
    );
    for (const k of keys) {
      await this.pool.query(
        `INSERT INTO vendor_business_capability_assignments (tenant_id, vendor_id, capability_key)
         VALUES ($1, $2::uuid, $3)`,
        [actor.tenantId, vendorId, k],
      );
    }
    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: 'vendor_offerings.capabilities.update',
      resourceType: 'vendor_business_capability_assignments',
      resourceId: vendorId,
      metadata: { capabilityKeys: keys },
    });
    return this.getConfig(actor, vendorId);
  }

  async putCategorySelections(actor: CommerceActor, vendorId: string, categoryIds: string[]) {
    await this.assertOwns(actor, vendorId);
    const ids = [...new Set(categoryIds.map((id) => String(id).trim()).filter(Boolean))];
    if (ids.length) {
      const { rows } = await this.pool.query<{ id: string }>(
        `SELECT id FROM tenant_vendor_categories
         WHERE tenant_id = $1 AND is_active = true AND id = ANY($2::uuid[])`,
        [actor.tenantId, ids],
      );
      if (rows.length !== ids.length) {
        throw new BadRequestException({
          code: 'CATEGORY_INVALID',
          message: 'One or more categories are inactive or unknown',
        });
      }
    }
    await this.pool.query(
      `DELETE FROM vendor_offering_category_selections WHERE tenant_id = $1 AND vendor_id = $2::uuid`,
      [actor.tenantId, vendorId],
    );
    for (const id of ids) {
      await this.pool.query(
        `INSERT INTO vendor_offering_category_selections (tenant_id, vendor_id, category_id)
         VALUES ($1, $2::uuid, $3::uuid)`,
        [actor.tenantId, vendorId, id],
      );
    }
    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: 'vendor_offerings.categories.update',
      resourceType: 'vendor_offering_category_selections',
      resourceId: vendorId,
      metadata: { categoryIds: ids },
    });
    return this.getConfig(actor, vendorId);
  }

  async createService(actor: CommerceActor, vendorId: string, body: Record<string, unknown>) {
    await this.assertOwns(actor, vendorId);
    const name = String(body.serviceName ?? body.name ?? '').trim();
    const categoryId = String(body.categoryId ?? '').trim();
    if (!name) throw new BadRequestException({ code: 'INVALID_NAME', message: 'serviceName required' });
    if (!categoryId) throw new BadRequestException({ code: 'CATEGORY_REQUIRED', message: 'categoryId required' });
    const { rows: cat } = await this.pool.query<{ id: string; offering_kind: string }>(
      `SELECT id, offering_kind FROM tenant_vendor_categories
       WHERE tenant_id = $1 AND id = $2::uuid AND is_active = true`,
      [actor.tenantId, categoryId],
    );
    if (!cat.length || cat[0]!.offering_kind === 'rental') {
      throw new BadRequestException({ code: 'CATEGORY_INVALID', message: 'Active service category required' });
    }
    const key = normalizeServiceKey(name);
    if (!key || key === 'general') {
      throw new BadRequestException({ code: 'INVALID_SERVICE_KEY', message: 'Invalid service name' });
    }
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO vendor_services
         (tenant_id, vendor_id, service_key, service_name, service_code, status, category_id, description)
       VALUES ($1, $2::uuid, $3, $4, 'VS-' || lpad(nextval('vendor_service_code_seq')::text, 6, '0'), 'active', $5::uuid, $6)
       ON CONFLICT (vendor_id, service_key) DO UPDATE SET
         service_name = EXCLUDED.service_name,
         category_id = EXCLUDED.category_id,
         description = COALESCE(EXCLUDED.description, vendor_services.description),
         updated_at = now()
       RETURNING id`,
      [actor.tenantId, vendorId, key, name, categoryId, String(body.description ?? '').trim() || null],
    );
    const serviceId = rows[0]!.id;
    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: 'vendor_offerings.service.upsert',
      resourceType: 'vendor_services',
      resourceId: serviceId,
      metadata: { vendorId, name, categoryId },
    });
    return this.getServiceDetail(actor, vendorId, serviceId);
  }

  async listServices(actor: CommerceActor, vendorId: string) {
    await this.assertOwns(actor, vendorId);
    const { rows } = await this.pool.query<{
      id: string;
      service_key: string;
      service_name: string;
      description: string | null;
      status: string;
      category_id: string | null;
    }>(
      `SELECT id, service_key, service_name, description, status, category_id
       FROM vendor_services
       WHERE tenant_id = $1 AND vendor_id = $2::uuid AND status <> 'archived'
       ORDER BY service_name ASC`,
      [actor.tenantId, vendorId],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        serviceKey: r.service_key,
        serviceName: r.service_name,
        description: r.description,
        status: r.status,
        categoryId: r.category_id,
      })),
    };
  }

  async getServiceDetail(actor: CommerceActor, vendorId: string, serviceId: string) {
    await this.assertOwns(actor, vendorId);
    const { rows } = await this.pool.query<{
      id: string;
      service_key: string;
      service_name: string;
      description: string | null;
      status: string;
      category_id: string | null;
    }>(
      `SELECT id, service_key, service_name, description, status, category_id
       FROM vendor_services WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid`,
      [actor.tenantId, vendorId, serviceId],
    );
    if (!rows.length) throw new NotFoundException({ code: 'VENDOR_SERVICE_NOT_FOUND' });
    const blueprint = await this.pool.query<{ resource_id: string; is_required: boolean; slug: string; label: string }>(
      `SELECT b.resource_id, b.is_required, r.slug, r.label
       FROM vendor_service_blueprint_resources b
       JOIN tenant_vendor_resource_catalog r ON r.id = b.resource_id
       WHERE b.vendor_service_id = $1
       ORDER BY r.sort_order, r.label`,
      [serviceId],
    );
    return {
      id: rows[0]!.id,
      serviceKey: rows[0]!.service_key,
      serviceName: rows[0]!.service_name,
      description: rows[0]!.description,
      status: rows[0]!.status,
      categoryId: rows[0]!.category_id,
      blueprint: blueprint.rows.map((r) => ({
        resourceId: r.resource_id,
        required: r.is_required,
        slug: r.slug,
        label: r.label,
      })),
    };
  }

  async putBlueprint(
    actor: CommerceActor,
    vendorId: string,
    serviceId: string,
    resources: Array<{ resourceId: string; required?: boolean }>,
  ) {
    await this.assertOwns(actor, vendorId);
    const svc = await this.pool.query(
      `SELECT id FROM vendor_services WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid`,
      [actor.tenantId, vendorId, serviceId],
    );
    if (!svc.rows.length) throw new NotFoundException({ code: 'VENDOR_SERVICE_NOT_FOUND' });
    const ids = [...new Set(resources.map((r) => String(r.resourceId ?? '').trim()).filter(Boolean))];
    if (ids.length) {
      const { rows } = await this.pool.query<{ id: string }>(
        `SELECT id FROM tenant_vendor_resource_catalog
         WHERE tenant_id = $1 AND is_active = true AND id = ANY($2::uuid[])`,
        [actor.tenantId, ids],
      );
      if (rows.length !== ids.length) {
        throw new BadRequestException({ code: 'RESOURCE_INVALID', message: 'Resources must be from the active master catalogue' });
      }
    }
    await this.pool.query(`DELETE FROM vendor_service_blueprint_resources WHERE vendor_service_id = $1`, [serviceId]);
    for (const r of resources) {
      const resourceId = String(r.resourceId ?? '').trim();
      if (!resourceId) continue;
      await this.pool.query(
        `INSERT INTO vendor_service_blueprint_resources
           (tenant_id, vendor_id, vendor_service_id, resource_id, is_required)
         VALUES ($1, $2::uuid, $3::uuid, $4::uuid, $5)`,
        [actor.tenantId, vendorId, serviceId, resourceId, r.required !== false],
      );
    }
    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: 'vendor_offerings.blueprint.update',
      resourceType: 'vendor_service_blueprint_resources',
      resourceId: serviceId,
      metadata: { vendorId, resourceCount: ids.length },
    });
    return this.getServiceDetail(actor, vendorId, serviceId);
  }

  async listPackages(actor: CommerceActor, vendorId: string) {
    await this.assertOwns(actor, vendorId);
    const { rows } = await this.pool.query<{
      id: string;
      name: string;
      description: string;
      category_slug: string;
      rental_fee_minor: string;
      deposit_minor: string;
      active: boolean;
    }>(
      `SELECT id, name, description, category_slug, rental_fee_minor::text, deposit_minor::text, active
       FROM rental_catalog_items
       WHERE tenant_id = $1 AND vendor_id = $2::uuid AND is_package = true
       ORDER BY name`,
      [actor.tenantId, vendorId],
    );
    const out = [];
    for (const row of rows) {
      out.push(await this.packageView(actor.tenantId, vendorId, row.id, row));
    }
    return { items: out };
  }

  async upsertPackage(actor: CommerceActor, vendorId: string, body: Record<string, unknown>) {
    await this.assertOwns(actor, vendorId);
    const name = String(body.name ?? '').trim();
    if (!name) throw new BadRequestException({ code: 'INVALID_NAME', message: 'Package name required' });
    const categorySlug = String(body.categorySlug ?? '').trim();
    if (!categorySlug) {
      throw new BadRequestException({ code: 'CATEGORY_REQUIRED', message: 'Rental category slug required' });
    }
    const { rows: cat } = await this.pool.query(
      `SELECT slug FROM tenant_vendor_categories
       WHERE tenant_id = $1 AND slug = $2 AND is_active = true AND offering_kind = 'rental'`,
      [actor.tenantId, categorySlug],
    );
    if (!cat.length) {
      throw new BadRequestException({ code: 'CATEGORY_INVALID', message: 'Active rental category required' });
    }
    const components = Array.isArray(body.components) ? body.components : [];
    const parsed: Array<{ resourceId: string; quantity: number }> = [];
    for (const c of components) {
      if (!c || typeof c !== 'object') continue;
      const rec = c as Record<string, unknown>;
      const resourceId = String(rec.resourceId ?? '').trim();
      const quantity = Math.max(1, Math.floor(Number(rec.quantity) || 1));
      if (resourceId) parsed.push({ resourceId, quantity });
    }
    if (!parsed.length) {
      throw new BadRequestException({
        code: 'COMPONENTS_REQUIRED',
        message: 'Add at least one catalogue resource to the package',
      });
    }
    const resourceIds = parsed.map((p) => p.resourceId);
    const { rows: resRows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM tenant_vendor_resource_catalog
       WHERE tenant_id = $1 AND is_active = true AND id = ANY($2::uuid[])`,
      [actor.tenantId, resourceIds],
    );
    if (resRows.length !== new Set(resourceIds).size) {
      throw new BadRequestException({ code: 'RESOURCE_INVALID', message: 'Components must use the master resource catalogue' });
    }

    let itemId = body.id ? String(body.id).trim() : '';
    const description = String(body.description ?? '').trim();
    const fee = Math.max(0, Math.floor(Number(body.rentalFeeMinor) || 0));
    const deposit = Math.max(0, Math.floor(Number(body.depositMinor) || 0));

    if (itemId) {
      const { rows: own } = await this.pool.query(
        `SELECT id FROM rental_catalog_items
         WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid AND is_package = true`,
        [actor.tenantId, vendorId, itemId],
      );
      if (!own.length) throw new NotFoundException({ code: 'PACKAGE_NOT_FOUND' });
      await this.pool.query(
        `UPDATE rental_catalog_items
         SET name = $4, description = $5, category_slug = $6, rental_fee_minor = $7, deposit_minor = $8,
             updated_at = now()
         WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid`,
        [actor.tenantId, vendorId, itemId, name, description, categorySlug, fee, deposit],
      );
    } else {
      const created = await this.rentals.createInventoryItem(actor, vendorId, {
        name,
        description,
        categorySlug,
        totalQuantity: 1,
        rentalFeeMinor: fee,
        depositMinor: deposit,
      });
      itemId = created.id;
      await this.pool.query(
        `UPDATE rental_catalog_items SET is_package = true, total_quantity = 1, available_quantity = GREATEST(1 - reserved_quantity, 0)
         WHERE id = $1::uuid`,
        [itemId],
      );
    }

    await this.pool.query(`DELETE FROM rental_package_components WHERE catalog_item_id = $1::uuid`, [itemId]);
    for (const p of parsed) {
      await this.pool.query(
        `INSERT INTO rental_package_components
           (tenant_id, vendor_id, catalog_item_id, resource_id, quantity)
         VALUES ($1, $2::uuid, $3::uuid, $4::uuid, $5)`,
        [actor.tenantId, vendorId, itemId, p.resourceId, p.quantity],
      );
    }
    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: itemId && body.id ? 'vendor_offerings.package.update' : 'vendor_offerings.package.create',
      resourceType: 'rental_catalog_items',
      resourceId: itemId,
      metadata: { vendorId, name, isPackage: true, componentCount: parsed.length },
    });
    return this.getPackage(actor, vendorId, itemId);
  }

  async getPackage(actor: CommerceActor, vendorId: string, itemId: string) {
    await this.assertOwns(actor, vendorId);
    const { rows } = await this.pool.query<{
      id: string;
      name: string;
      description: string;
      category_slug: string;
      rental_fee_minor: string;
      deposit_minor: string;
      active: boolean;
    }>(
      `SELECT id, name, description, category_slug, rental_fee_minor::text, deposit_minor::text, active
       FROM rental_catalog_items
       WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid AND is_package = true`,
      [actor.tenantId, vendorId, itemId],
    );
    if (!rows.length) throw new NotFoundException({ code: 'PACKAGE_NOT_FOUND' });
    return this.packageView(actor.tenantId, vendorId, itemId, rows[0]!);
  }

  private async packageView(
    tenantId: string,
    vendorId: string,
    itemId: string,
    row: {
      id: string;
      name: string;
      description: string;
      category_slug: string;
      rental_fee_minor: string;
      deposit_minor: string;
      active: boolean;
    },
  ) {
    const comps = await this.pool.query<{ resource_id: string; quantity: number; slug: string; label: string }>(
      `SELECT c.resource_id, c.quantity, r.slug, r.label
       FROM rental_package_components c
       JOIN tenant_vendor_resource_catalog r ON r.id = c.resource_id
       WHERE c.catalog_item_id = $1
       ORDER BY r.sort_order, r.label`,
      [itemId],
    );
    return {
      id: row.id,
      vendorId,
      name: row.name,
      description: row.description,
      categorySlug: row.category_slug,
      rentalFeeMinor: Number(row.rental_fee_minor),
      depositMinor: Number(row.deposit_minor),
      active: row.active,
      isPackage: true,
      components: comps.rows.map((c) => ({
        resourceId: c.resource_id,
        quantity: c.quantity,
        slug: c.slug,
        label: c.label,
      })),
    };
  }
}
