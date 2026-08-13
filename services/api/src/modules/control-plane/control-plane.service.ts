import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';

/**
 * Phase 28 — Control plane consumer layer.
 * Composes tenants, vendors, mdm_* dictionaries, audit_log.
 * Does not own Finance / CRM / Tickets / Compliance data.
 */
@Injectable()
export class ControlPlaneService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async dashboard() {
    const [tenants, vendors, mdm, recent] = await Promise.all([
      this.pool.query<{ status: string; n: string }>(
        `SELECT status, COUNT(*)::text AS n FROM tenants GROUP BY status`,
      ),
      this.pool.query<{ status: string; n: string }>(
        `SELECT status::text AS status, COUNT(*)::text AS n FROM vendors GROUP BY status`,
      ),
      this.pool.query<{ domains: string; entities: string }>(
        `SELECT
           (SELECT COUNT(*)::text FROM mdm_domains) AS domains,
           (SELECT COUNT(*)::text FROM mdm_entities) AS entities`,
      ),
      this.pool.query(
        `SELECT id, tenant_id, actor_user_id, action, resource_type, resource_id, created_at
         FROM audit_log
         WHERE action LIKE 'control_plane.%'
            OR action LIKE 'tenant_%'
            OR action LIKE 'vendor_%'
            OR action LIKE 'mdm.%'
         ORDER BY created_at DESC
         LIMIT 30`,
      ),
    ]);

    return {
      generatedAt: new Date().toISOString(),
      tenantsByStatus: Object.fromEntries(tenants.rows.map((r) => [r.status, parseInt(r.n, 10)])),
      vendorsByStatus: Object.fromEntries(vendors.rows.map((r) => [r.status, parseInt(r.n, 10)])),
      mdm: {
        domains: parseInt(mdm.rows[0]?.domains ?? '0', 10),
        entities: parseInt(mdm.rows[0]?.entities ?? '0', 10),
      },
      devices: {
        available: false,
        reason:
          'No device enrollment infrastructure exists in the platform. Device MDM deferred — invented device states are forbidden.',
        items: [],
      },
      recentActivity: recent.rows.map((r) => ({
        id: r.id,
        tenantId: r.tenant_id,
        actorUserId: r.actor_user_id,
        action: r.action,
        resourceType: r.resource_type,
        resourceId: r.resource_id,
        createdAt: r.created_at,
      })),
    };
  }

  // ── Tenants (canonical `tenants` table) ─────────────────────────────

  async listTenants(query?: string, status?: string) {
    const params: unknown[] = [];
    let where = 'WHERE 1=1';
    if (status && status !== 'all') {
      params.push(status);
      where += ` AND t.status = $${params.length}`;
    }
    if (query?.trim()) {
      params.push(`%${query.trim().toLowerCase()}%`);
      where += ` AND (lower(t.name) LIKE $${params.length} OR lower(t.slug) LIKE $${params.length})`;
    }
    const { rows } = await this.pool.query(
      `SELECT t.id, t.slug, t.name, t.status, t.metadata, t.created_at, t.updated_at,
              (SELECT COUNT(*)::text FROM organizers o WHERE o.tenant_id = t.id) AS organizer_count,
              (SELECT COUNT(*)::text FROM vendors v WHERE v.tenant_id = t.id) AS vendor_count,
              (SELECT COUNT(*)::text FROM events e WHERE e.tenant_id = t.id) AS event_count,
              (SELECT COUNT(*)::text FROM users u WHERE u.tenant_id = t.id) AS user_count
       FROM tenants t
       ${where}
       ORDER BY t.created_at DESC
       LIMIT 200`,
      params,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        slug: r.slug,
        name: r.name,
        status: r.status,
        metadata: r.metadata ?? {},
        createdAt: r.created_at,
        updatedAt: r.updated_at,
        organizerCount: parseInt(r.organizer_count, 10),
        vendorCount: parseInt(r.vendor_count, 10),
        eventCount: parseInt(r.event_count, 10),
        userCount: parseInt(r.user_count, 10),
      })),
    };
  }

  async getTenant(tenantId: string) {
    const { rows } = await this.pool.query(
      `SELECT id, slug, name, status, metadata, created_at, updated_at
       FROM tenants WHERE id = $1::uuid`,
      [tenantId],
    );
    if (!rows[0]) throw new NotFoundException('Tenant not found');
    const t = rows[0];

    const [flags, activity, orgs, vendors] = await Promise.all([
      this.pool.query(
        `SELECT flag_key, enabled, updated_at FROM tenant_feature_flags WHERE tenant_id = $1 ORDER BY flag_key`,
        [tenantId],
      ),
      this.pool.query(
        `SELECT id, actor_user_id, action, resource_type, resource_id, metadata, created_at
         FROM audit_log WHERE tenant_id = $1
         ORDER BY created_at DESC LIMIT 50`,
        [tenantId],
      ),
      this.pool.query(
        `SELECT id, display_name, slug, status::text FROM organizers WHERE tenant_id = $1 LIMIT 50`,
        [tenantId],
      ),
      this.pool.query(
        `SELECT id, business_name, slug, status::text, suspended_reason
         FROM vendors WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT 50`,
        [tenantId],
      ),
    ]);

    return {
      profile: {
        id: t.id,
        slug: t.slug,
        name: t.name,
        status: t.status,
        metadata: t.metadata ?? {},
        createdAt: t.created_at,
        updatedAt: t.updated_at,
      },
      configuration: {
        featureFlags: flags.rows.map((f) => ({
          flagKey: f.flag_key,
          enabled: f.enabled,
          updatedAt: f.updated_at,
        })),
      },
      organizations: orgs.rows.map((o) => ({
        id: o.id,
        displayName: o.display_name,
        slug: o.slug,
        status: o.status,
      })),
      vendors: vendors.rows.map((v) => ({
        id: v.id,
        businessName: v.business_name,
        slug: v.slug,
        status: v.status,
        suspendedReason: v.suspended_reason,
      })),
      activity: activity.rows.map((a) => ({
        id: a.id,
        actorUserId: a.actor_user_id,
        action: a.action,
        resourceType: a.resource_type,
        resourceId: a.resource_id,
        metadata: a.metadata,
        createdAt: a.created_at,
      })),
    };
  }

  async updateTenantMetadata(
    actorUserId: string,
    tenantId: string,
    metadata: Record<string, unknown>,
  ) {
    const { rows } = await this.pool.query(
      `UPDATE tenants
       SET metadata = COALESCE(metadata, '{}'::jsonb) || $2::jsonb, updated_at = now()
       WHERE id = $1::uuid
       RETURNING id, slug, name, status, metadata`,
      [tenantId, JSON.stringify(metadata)],
    );
    if (!rows[0]) throw new NotFoundException('Tenant not found');
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'control_plane.tenant_config_updated',
      resourceType: 'tenant',
      resourceId: tenantId,
      metadata: { patch: metadata },
    });
    return {
      id: rows[0].id,
      slug: rows[0].slug,
      name: rows[0].name,
      status: rows[0].status,
      metadata: rows[0].metadata,
    };
  }

  async setTenantStatus(
    actorUserId: string,
    tenantId: string,
    status: 'active' | 'suspended',
  ) {
    const { rows } = await this.pool.query(
      `SELECT id, status, slug FROM tenants WHERE id = $1::uuid`,
      [tenantId],
    );
    if (!rows[0]) throw new NotFoundException('Tenant not found');
    await this.pool.query(`UPDATE tenants SET status = $2, updated_at = now() WHERE id = $1::uuid`, [
      tenantId,
      status,
    ]);
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: status === 'suspended' ? 'control_plane.tenant_suspended' : 'control_plane.tenant_reactivated',
      resourceType: 'tenant',
      resourceId: tenantId,
      metadata: { previousStatus: rows[0].status, slug: rows[0].slug },
    });
    return { ok: true, status };
  }

  // ── Vendor governance (canonical `vendors`) ─────────────────────────

  async listVendors(query?: string, status?: string, tenantId?: string) {
    const params: unknown[] = [];
    let where = 'WHERE 1=1';
    if (tenantId) {
      params.push(tenantId);
      where += ` AND v.tenant_id = $${params.length}::uuid`;
    }
    if (status && status !== 'all') {
      params.push(status);
      where += ` AND v.status::text = $${params.length}`;
    }
    if (query?.trim()) {
      params.push(`%${query.trim().toLowerCase()}%`);
      where += ` AND (lower(v.business_name) LIKE $${params.length} OR lower(v.slug) LIKE $${params.length})`;
    }
    const { rows } = await this.pool.query(
      `SELECT v.id, v.tenant_id, v.business_name, v.slug, v.status::text, v.city,
              v.suspended_reason, v.created_at, v.updated_at,
              t.name AS tenant_name, t.slug AS tenant_slug,
              (SELECT COUNT(*)::text FROM vendor_event_participations vep WHERE vep.vendor_id = v.id) AS participation_count
       FROM vendors v
       INNER JOIN tenants t ON t.id = v.tenant_id
       ${where}
       ORDER BY v.updated_at DESC NULLS LAST, v.created_at DESC
       LIMIT 200`,
      params,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        tenantId: r.tenant_id,
        tenantName: r.tenant_name,
        tenantSlug: r.tenant_slug,
        businessName: r.business_name,
        slug: r.slug,
        status: r.status,
        city: r.city ?? '',
        suspendedReason: r.suspended_reason,
        participationCount: parseInt(r.participation_count, 10),
        complianceState: this.vendorComplianceState(r.status as string),
        createdAt: r.created_at,
        updatedAt: r.updated_at,
      })),
    };
  }

  async getVendorGovernance(tenantId: string, vendorId: string) {
    const { rows } = await this.pool.query(
      `SELECT v.id, v.tenant_id, v.business_name, v.slug, v.status::text, v.city,
              v.description, v.suspended_reason, v.owner_user_id, v.created_at, v.updated_at
       FROM vendors v WHERE v.tenant_id = $1::uuid AND v.id = $2::uuid`,
      [tenantId, vendorId],
    );
    if (!rows[0]) throw new NotFoundException('Vendor not found');
    const v = rows[0];

    const [activity, participations] = await Promise.all([
      this.pool.query(
        `SELECT id, actor_user_id, action, resource_type, metadata, created_at
         FROM audit_log
         WHERE tenant_id = $1 AND resource_type = 'vendor' AND resource_id = $2
         ORDER BY created_at DESC LIMIT 40`,
        [tenantId, vendorId],
      ),
      this.pool.query(
        `SELECT vep.id, vep.status::text, e.title, e.starts_at
         FROM vendor_event_participations vep
         INNER JOIN events e ON e.id = vep.event_id
         WHERE vep.tenant_id = $1 AND vep.vendor_id = $2
         ORDER BY e.starts_at DESC LIMIT 30`,
        [tenantId, vendorId],
      ),
    ]);

    return {
      profile: {
        id: v.id,
        tenantId: v.tenant_id,
        businessName: v.business_name,
        slug: v.slug,
        status: v.status,
        city: v.city ?? '',
        description: v.description ?? '',
        suspendedReason: v.suspended_reason,
        ownerUserId: v.owner_user_id,
        complianceState: this.vendorComplianceState(v.status as string),
        createdAt: v.created_at,
        updatedAt: v.updated_at,
      },
      activity: activity.rows.map((a) => ({
        id: a.id,
        actorUserId: a.actor_user_id,
        action: a.action,
        metadata: a.metadata,
        createdAt: a.created_at,
      })),
      participations: participations.rows.map((p) => ({
        id: p.id,
        status: p.status,
        eventTitle: p.title,
        startsAt: p.starts_at,
      })),
    };
  }

  async transitionVendor(
    actorUserId: string,
    tenantId: string,
    vendorId: string,
    action: 'approve' | 'suspend' | 'reactivate' | 'reject',
    reason?: string,
  ) {
    const statusMap: Record<string, string> = {
      approve: 'active',
      suspend: 'suspended',
      reactivate: 'active',
      reject: 'rejected',
    };
    const next = statusMap[action];
    if (!next) throw new BadRequestException('Unknown governance action');

    const { rows } = await this.pool.query(
      `SELECT id, status::text, business_name FROM vendors WHERE tenant_id = $1::uuid AND id = $2::uuid`,
      [tenantId, vendorId],
    );
    if (!rows[0]) throw new NotFoundException('Vendor not found');

    await this.pool.query(
      `UPDATE vendors SET status = $3::vendor_status,
         suspended_reason = CASE WHEN $3::text = 'suspended' THEN $4 ELSE NULL END,
         updated_at = now()
       WHERE id = $2::uuid AND tenant_id = $1::uuid`,
      [tenantId, vendorId, next, reason ?? 'Control plane action'],
    );

    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: `control_plane.vendor_${action}`,
      resourceType: 'vendor',
      resourceId: vendorId,
      metadata: {
        previousStatus: rows[0].status,
        businessName: rows[0].business_name,
        reason: reason ?? null,
      },
    });

    return this.getVendorGovernance(tenantId, vendorId);
  }

  private vendorComplianceState(status: string): string {
    if (status === 'active') return 'compliant';
    if (status === 'pending_review' || status === 'draft') return 'review_required';
    if (status === 'suspended' || status === 'rejected') return 'restricted';
    return status;
  }

  // ── MDM dictionaries (039 mdm_*) ────────────────────────────────────

  async listMdmDomains() {
    const { rows } = await this.pool.query(
      `SELECT d.id, d.domain_key, d.label, d.icon, d.metadata_schema, d.created_at, d.updated_at,
              (SELECT COUNT(*)::text FROM mdm_entities e WHERE e.domain_id = d.id) AS entity_count
       FROM mdm_domains d
       ORDER BY d.label`,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        domainKey: r.domain_key,
        label: r.label,
        icon: r.icon,
        metadataSchema: r.metadata_schema,
        entityCount: parseInt(r.entity_count, 10),
        createdAt: r.created_at,
        updatedAt: r.updated_at,
      })),
    };
  }

  async listMdmEntities(domainKey: string, parentId?: string | null, search?: string) {
    const domain = await this.resolveDomain(domainKey);
    const params: unknown[] = [domain.id];
    let where = 'WHERE e.domain_id = $1';
    if (parentId === null || parentId === 'root') {
      where += ' AND e.parent_id IS NULL';
    } else if (parentId) {
      params.push(parentId);
      where += ` AND e.parent_id = $${params.length}::uuid`;
    }
    if (search?.trim()) {
      params.push(`%${search.trim().toLowerCase()}%`);
      where += ` AND (lower(e.label) LIKE $${params.length} OR lower(e.slug) LIKE $${params.length})`;
    }
    const { rows } = await this.pool.query(
      `SELECT e.id, e.domain_id, e.parent_id, e.slug, e.label, e.description, e.status,
              e.sort_order, e.effective_date, e.expiry_date, e.properties, e.created_at, e.updated_at
       FROM mdm_entities e
       ${where}
       ORDER BY e.sort_order, e.label
       LIMIT 500`,
      params,
    );
    return {
      domainKey,
      items: rows.map((r) => this.mapEntity(r, domainKey)),
    };
  }

  async createMdmEntity(
    actorUserId: string,
    actorTenantId: string,
    domainKey: string,
    body: {
      slug: string;
      label: string;
      description?: string;
      parentId?: string | null;
      status?: string;
      sortOrder?: number;
      properties?: Record<string, unknown>;
    },
  ) {
    const domain = await this.resolveDomain(domainKey);
    const status = body.status ?? 'draft';
    if (!['draft', 'published', 'archived'].includes(status)) {
      throw new BadRequestException('Invalid status');
    }
    const { rows } = await this.pool.query(
      `INSERT INTO mdm_entities
         (domain_id, parent_id, slug, label, description, status, sort_order, properties)
       VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, $7, $8::jsonb)
       RETURNING *`,
      [
        domain.id,
        body.parentId ?? null,
        body.slug.trim().toLowerCase(),
        body.label.trim(),
        body.description ?? '',
        status,
        body.sortOrder ?? 0,
        JSON.stringify(body.properties ?? {}),
      ],
    );
    const entity = rows[0];
    await this.pool.query(
      `INSERT INTO mdm_versions (entity_id, version_number, status, data_snapshot, created_by)
       VALUES ($1::uuid, 1, $2, $3::jsonb, $4)`,
      [entity.id, status, JSON.stringify(entity), actorUserId],
    );
    await this.audit.logAction({
      tenantId: actorTenantId,
      actorUserId,
      action: 'mdm.entity_created',
      resourceType: 'mdm_entity',
      resourceId: entity.id,
      metadata: { domainKey, slug: entity.slug },
    });
    return this.mapEntity(entity, domainKey);
  }

  async updateMdmEntity(
    actorUserId: string,
    actorTenantId: string,
    entityId: string,
    patch: {
      label?: string;
      description?: string;
      status?: string;
      sortOrder?: number;
      properties?: Record<string, unknown>;
    },
  ) {
    const { rows: existing } = await this.pool.query(
      `SELECT e.*, d.domain_key
       FROM mdm_entities e
       INNER JOIN mdm_domains d ON d.id = e.domain_id
       WHERE e.id = $1::uuid`,
      [entityId],
    );
    if (!existing[0]) throw new NotFoundException('MDM entity not found');
    const prev = existing[0];
    if (patch.status && !['draft', 'published', 'archived'].includes(patch.status)) {
      throw new BadRequestException('Invalid status');
    }

    const { rows } = await this.pool.query(
      `UPDATE mdm_entities SET
         label = COALESCE($2, label),
         description = COALESCE($3, description),
         status = COALESCE($4, status),
         sort_order = COALESCE($5, sort_order),
         properties = COALESCE($6::jsonb, properties),
         updated_at = now()
       WHERE id = $1::uuid
       RETURNING *`,
      [
        entityId,
        patch.label ?? null,
        patch.description ?? null,
        patch.status ?? null,
        patch.sortOrder ?? null,
        patch.properties ? JSON.stringify(patch.properties) : null,
      ],
    );
    const entity = rows[0];
    const { rows: ver } = await this.pool.query<{ n: string }>(
      `SELECT COALESCE(MAX(version_number), 0)::text AS n FROM mdm_versions WHERE entity_id = $1::uuid`,
      [entityId],
    );
    await this.pool.query(
      `INSERT INTO mdm_versions (entity_id, version_number, status, data_snapshot, created_by)
       VALUES ($1::uuid, $2, $3, $4::jsonb, $5)`,
      [
        entityId,
        parseInt(ver[0].n, 10) + 1,
        entity.status,
        JSON.stringify(entity),
        actorUserId,
      ],
    );
    await this.audit.logAction({
      tenantId: actorTenantId,
      actorUserId,
      action: 'mdm.entity_updated',
      resourceType: 'mdm_entity',
      resourceId: entityId,
      metadata: { previousStatus: prev.status, patch },
    });
    return this.mapEntity(entity, prev.domain_key as string);
  }

  async listMdmActivity(limit = 40) {
    const n = Math.min(100, Math.max(1, limit));
    const { rows } = await this.pool.query(
      `SELECT id, actor_user_id, action, resource_type, resource_id, metadata, created_at
       FROM audit_log
       WHERE action LIKE 'mdm.%' OR action LIKE 'control_plane.%'
       ORDER BY created_at DESC
       LIMIT $1`,
      [n],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        actorUserId: r.actor_user_id,
        action: r.action,
        resourceType: r.resource_type,
        resourceId: r.resource_id,
        metadata: r.metadata,
        createdAt: r.created_at,
      })),
    };
  }

  /** Honest Unavailable — no device enrollment schema in platform. */
  devicesUnavailable() {
    return {
      available: false,
      reason:
        'Device enrollment / inventory tables do not exist. Phase 28 activates dictionary MDM (mdm_*). Device MDM requires approved schema work — fake device states are forbidden.',
      items: [],
    };
  }

  private async resolveDomain(domainKey: string) {
    const { rows } = await this.pool.query(
      `SELECT id, domain_key, label FROM mdm_domains WHERE domain_key = $1`,
      [domainKey],
    );
    if (!rows[0]) throw new NotFoundException(`MDM domain not found: ${domainKey}`);
    return rows[0] as { id: string; domain_key: string; label: string };
  }

  private mapEntity(r: Record<string, unknown>, domainKey: string) {
    return {
      id: r.id,
      domainKey,
      domainId: r.domain_id,
      parentId: r.parent_id,
      slug: r.slug,
      label: r.label,
      description: r.description ?? '',
      status: r.status,
      sortOrder: r.sort_order,
      effectiveDate: r.effective_date,
      expiryDate: r.expiry_date,
      properties: r.properties ?? {},
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }
}
