import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';
import {
  normalizeServiceKey,
  PRICING_RESOLUTION_ORDER,
} from '../vendor-operations/vendor-pricing.util';

export type VendorPricingRuleDto = {
  id: string;
  serviceKey: string | null;
  vendorId: string | null;
  vendorName: string | null;
  markupBps: number;
  markupPercent: number;
  isDefault: boolean;
  updatedAt: string;
};

function percentToBps(percent: number): number {
  if (!Number.isFinite(percent)) {
    throw new BadRequestException('markupPercent must be a number');
  }
  const rounded = Math.round(percent * 100) / 100;
  if (rounded < 0 || rounded > 90) {
    throw new BadRequestException('markupPercent must be between 0 and 90');
  }
  return Math.round(rounded * 100);
}

function bpsToPercent(bps: number): number {
  return Math.round((bps / 100) * 100) / 100;
}

function mapRow(row: {
  id: string;
  service_key: string | null;
  vendor_id?: string | null;
  vendor_name?: string | null;
  markup_bps: number;
  is_default: boolean;
  updated_at: Date | string;
}): VendorPricingRuleDto {
  return {
    id: row.id,
    serviceKey: row.service_key,
    vendorId: row.vendor_id ?? null,
    vendorName: row.vendor_name ?? null,
    markupBps: row.markup_bps,
    markupPercent: bpsToPercent(row.markup_bps),
    isDefault: row.is_default,
    updatedAt:
      row.updated_at instanceof Date
        ? row.updated_at.toISOString()
        : String(row.updated_at),
  };
}

/**
 * Admin-only CRUD for platform_vendor_pricing_rules (063 + 064 overrides).
 * Does not recalculate historical vendor_event_requests / funding / contracts —
 * only future pricing uses updated rules via VendorPricingRulesService.resolveMarkupBps.
 */
@Injectable()
export class AdminVendorPricingService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async listRules(tenantId: string): Promise<{
    defaultRule: VendorPricingRuleDto | null;
    serviceRules: VendorPricingRuleDto[];
    vendorRules: VendorPricingRuleDto[];
    vendorServiceRules: VendorPricingRuleDto[];
    resolutionOrder: string[];
  }> {
    await this.ensureDefault(tenantId);
    const { rows } = await this.pool.query<{
      id: string;
      service_key: string | null;
      vendor_id: string | null;
      vendor_name: string | null;
      markup_bps: number;
      is_default: boolean;
      updated_at: Date;
    }>(
      `SELECT r.id,
              r.service_key,
              r.vendor_id,
              v.business_name AS vendor_name,
              r.markup_bps,
              r.is_default,
              r.updated_at
       FROM platform_vendor_pricing_rules r
       LEFT JOIN vendors v ON v.id = r.vendor_id AND v.tenant_id = r.tenant_id
       WHERE r.tenant_id = $1
       ORDER BY r.is_default DESC,
                r.vendor_id NULLS FIRST,
                r.service_key ASC NULLS LAST`,
      [tenantId],
    );
    const mapped = rows.map(mapRow);
    return {
      defaultRule: mapped.find((r) => r.isDefault) ?? null,
      serviceRules: mapped.filter(
        (r) => !r.isDefault && r.vendorId == null && r.serviceKey != null,
      ),
      vendorRules: mapped.filter(
        (r) => !r.isDefault && r.vendorId != null && r.serviceKey == null,
      ),
      vendorServiceRules: mapped.filter(
        (r) => !r.isDefault && r.vendorId != null && r.serviceKey != null,
      ),
      resolutionOrder: [...PRICING_RESOLUTION_ORDER],
    };
  }

  async upsertDefault(
    tenantId: string,
    actorUserId: string,
    markupPercent: number,
  ): Promise<VendorPricingRuleDto> {
    const markupBps = percentToBps(markupPercent);
    await this.ensureDefault(tenantId);
    const { rows: before } = await this.pool.query<{ markup_bps: number }>(
      `SELECT markup_bps FROM platform_vendor_pricing_rules
       WHERE tenant_id = $1 AND is_default = true LIMIT 1`,
      [tenantId],
    );
    const { rows } = await this.pool.query<{
      id: string;
      service_key: string | null;
      vendor_id: string | null;
      markup_bps: number;
      is_default: boolean;
      updated_at: Date;
    }>(
      `UPDATE platform_vendor_pricing_rules
       SET markup_bps = $2, updated_at = now()
       WHERE tenant_id = $1 AND is_default = true
       RETURNING id, service_key, vendor_id, markup_bps, is_default, updated_at`,
      [tenantId, markupBps],
    );
    if (!rows[0]) {
      throw new NotFoundException('Default pricing rule not found');
    }
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'vendor_pricing_default_updated',
      resourceType: 'platform_vendor_pricing_rules',
      resourceId: rows[0].id,
      metadata: {
        previousMarkupBps: before[0]?.markup_bps ?? null,
        markupBps,
        markupPercent: bpsToPercent(markupBps),
        appliesTo: 'future_bookings_only',
      },
    });
    return mapRow(rows[0]);
  }

  async upsertServiceRule(
    tenantId: string,
    actorUserId: string,
    serviceKeyRaw: string,
    markupPercent: number,
  ): Promise<VendorPricingRuleDto> {
    const serviceKey = normalizeServiceKey(serviceKeyRaw);
    if (!serviceKey || serviceKey === 'general') {
      throw new BadRequestException(
        'serviceKey is required for service-specific rules (use default endpoint for platform default)',
      );
    }
    const markupBps = percentToBps(markupPercent);
    const existing = await this.pool.query<{ id: string }>(
      `SELECT id FROM platform_vendor_pricing_rules
       WHERE tenant_id = $1 AND service_key = $2 AND vendor_id IS NULL AND is_default = false
       LIMIT 1`,
      [tenantId, serviceKey],
    );
    let row: {
      id: string;
      service_key: string | null;
      vendor_id: string | null;
      markup_bps: number;
      is_default: boolean;
      updated_at: Date;
    };
    if (existing.rows[0]) {
      const updated = await this.pool.query<{
        id: string;
        service_key: string | null;
        vendor_id: string | null;
        markup_bps: number;
        is_default: boolean;
        updated_at: Date;
      }>(
        `UPDATE platform_vendor_pricing_rules
         SET markup_bps = $3, updated_at = now()
         WHERE id = $1 AND tenant_id = $2
         RETURNING id, service_key, vendor_id, markup_bps, is_default, updated_at`,
        [existing.rows[0].id, tenantId, markupBps],
      );
      row = updated.rows[0]!;
    } else {
      const inserted = await this.pool.query<{
        id: string;
        service_key: string | null;
        vendor_id: string | null;
        markup_bps: number;
        is_default: boolean;
        updated_at: Date;
      }>(
        `INSERT INTO platform_vendor_pricing_rules
           (tenant_id, service_key, vendor_id, markup_bps, is_default)
         VALUES ($1, $2, NULL, $3, false)
         RETURNING id, service_key, vendor_id, markup_bps, is_default, updated_at`,
        [tenantId, serviceKey, markupBps],
      );
      row = inserted.rows[0]!;
    }
    await this.auditRule(
      tenantId,
      actorUserId,
      'vendor_pricing_service_rule_upserted',
      row.id,
      { serviceKey, markupBps },
    );
    return mapRow(row);
  }

  async deleteServiceRule(
    tenantId: string,
    actorUserId: string,
    serviceKeyRaw: string,
  ): Promise<{ ok: true }> {
    const serviceKey = normalizeServiceKey(serviceKeyRaw);
    const { rows } = await this.pool.query<{ id: string; markup_bps: number }>(
      `DELETE FROM platform_vendor_pricing_rules
       WHERE tenant_id = $1
         AND service_key = $2
         AND vendor_id IS NULL
         AND is_default = false
       RETURNING id, markup_bps`,
      [tenantId, serviceKey],
    );
    if (!rows[0]) {
      throw new NotFoundException(`No service rule for ${serviceKey}`);
    }
    await this.auditRule(
      tenantId,
      actorUserId,
      'vendor_pricing_service_rule_deleted',
      rows[0].id,
      { serviceKey, previousMarkupBps: rows[0].markup_bps },
    );
    return { ok: true };
  }

  /**
   * Vendor override (vendors.id) or vendor+service override.
   * Pass serviceKey empty/null for vendor-wide markup.
   */
  async upsertVendorRule(
    tenantId: string,
    actorUserId: string,
    vendorId: string,
    markupPercent: number,
    serviceKeyRaw?: string | null,
  ): Promise<VendorPricingRuleDto> {
    const vid = String(vendorId ?? '').trim();
    if (!vid) {
      throw new BadRequestException('vendorId is required (must be vendors.id)');
    }
    await this.assertVendorInTenant(tenantId, vid);
    const markupBps = percentToBps(markupPercent);
    const rawService = (serviceKeyRaw ?? '').trim();
    const serviceKey = rawService ? normalizeServiceKey(rawService) : null;
    if (serviceKey === 'general') {
      throw new BadRequestException(
        'Use vendor-wide override (omit serviceKey) instead of general',
      );
    }

    const existing = serviceKey
      ? await this.pool.query<{ id: string }>(
          `SELECT id FROM platform_vendor_pricing_rules
           WHERE tenant_id = $1 AND vendor_id = $2 AND service_key = $3 AND is_default = false
           LIMIT 1`,
          [tenantId, vid, serviceKey],
        )
      : await this.pool.query<{ id: string }>(
          `SELECT id FROM platform_vendor_pricing_rules
           WHERE tenant_id = $1 AND vendor_id = $2 AND service_key IS NULL AND is_default = false
           LIMIT 1`,
          [tenantId, vid],
        );

    let row: {
      id: string;
      service_key: string | null;
      vendor_id: string | null;
      markup_bps: number;
      is_default: boolean;
      updated_at: Date;
    };

    if (existing.rows[0]) {
      const updated = await this.pool.query<{
        id: string;
        service_key: string | null;
        vendor_id: string | null;
        markup_bps: number;
        is_default: boolean;
        updated_at: Date;
      }>(
        `UPDATE platform_vendor_pricing_rules
         SET markup_bps = $3, updated_at = now()
         WHERE id = $1 AND tenant_id = $2
         RETURNING id, service_key, vendor_id, markup_bps, is_default, updated_at`,
        [existing.rows[0].id, tenantId, markupBps],
      );
      row = updated.rows[0]!;
    } else {
      const inserted = await this.pool.query<{
        id: string;
        service_key: string | null;
        vendor_id: string | null;
        markup_bps: number;
        is_default: boolean;
        updated_at: Date;
      }>(
        `INSERT INTO platform_vendor_pricing_rules
           (tenant_id, service_key, vendor_id, markup_bps, is_default)
         VALUES ($1, $2, $3, $4, false)
         RETURNING id, service_key, vendor_id, markup_bps, is_default, updated_at`,
        [tenantId, serviceKey, vid, markupBps],
      );
      row = inserted.rows[0]!;
    }

    await this.auditRule(
      tenantId,
      actorUserId,
      serviceKey
        ? 'vendor_pricing_vendor_service_rule_upserted'
        : 'vendor_pricing_vendor_rule_upserted',
      row.id,
      { vendorId: vid, serviceKey, markupBps },
    );

    const { rows: named } = await this.pool.query<{ business_name: string }>(
      `SELECT business_name FROM vendors WHERE id = $1 AND tenant_id = $2`,
      [vid, tenantId],
    );
    return mapRow({ ...row, vendor_name: named[0]?.business_name ?? null });
  }

  async deleteVendorRule(
    tenantId: string,
    actorUserId: string,
    vendorId: string,
    serviceKeyRaw?: string | null,
  ): Promise<{ ok: true }> {
    const vid = String(vendorId ?? '').trim();
    if (!vid) {
      throw new BadRequestException('vendorId is required (must be vendors.id)');
    }
    const rawService = (serviceKeyRaw ?? '').trim();
    const serviceKey = rawService ? normalizeServiceKey(rawService) : null;

    const { rows } = serviceKey
      ? await this.pool.query<{ id: string; markup_bps: number }>(
          `DELETE FROM platform_vendor_pricing_rules
           WHERE tenant_id = $1
             AND vendor_id = $2
             AND service_key = $3
             AND is_default = false
           RETURNING id, markup_bps`,
          [tenantId, vid, serviceKey],
        )
      : await this.pool.query<{ id: string; markup_bps: number }>(
          `DELETE FROM platform_vendor_pricing_rules
           WHERE tenant_id = $1
             AND vendor_id = $2
             AND service_key IS NULL
             AND is_default = false
           RETURNING id, markup_bps`,
          [tenantId, vid],
        );

    if (!rows[0]) {
      throw new NotFoundException(
        serviceKey
          ? `No vendor+service rule for ${vid} / ${serviceKey}`
          : `No vendor override for ${vid}`,
      );
    }

    await this.auditRule(
      tenantId,
      actorUserId,
      serviceKey
        ? 'vendor_pricing_vendor_service_rule_deleted'
        : 'vendor_pricing_vendor_rule_deleted',
      rows[0].id,
      {
        vendorId: vid,
        serviceKey,
        previousMarkupBps: rows[0].markup_bps,
      },
    );
    return { ok: true };
  }

  private async assertVendorInTenant(tenantId: string, vendorId: string) {
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM vendors WHERE id = $1::uuid AND tenant_id = $2::uuid LIMIT 1`,
      [vendorId, tenantId],
    );
    if (!rows[0]) {
      throw new BadRequestException(
        'vendorId must reference an existing vendors.id in this tenant',
      );
    }
  }

  private async auditRule(
    tenantId: string,
    actorUserId: string,
    action: string,
    ruleId: string,
    metadata: Record<string, unknown>,
  ) {
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action,
      resourceType: 'platform_vendor_pricing_rules',
      resourceId: ruleId,
      metadata: {
        ...metadata,
        markupPercent:
          typeof metadata.markupBps === 'number'
            ? bpsToPercent(metadata.markupBps as number)
            : undefined,
        appliesTo: 'future_bookings_only',
      },
    });
  }

  private async ensureDefault(tenantId: string) {
    await this.pool.query(
      `INSERT INTO platform_vendor_pricing_rules (tenant_id, service_key, vendor_id, markup_bps, is_default)
       SELECT $1::uuid, NULL, NULL, 4000, true
       WHERE NOT EXISTS (
         SELECT 1 FROM platform_vendor_pricing_rules
         WHERE tenant_id = $1::uuid AND is_default = true
       )`,
      [tenantId],
    );
  }
}
