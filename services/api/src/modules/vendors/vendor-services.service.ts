import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { normalizeServiceKey } from '../vendor-operations/vendor-pricing.util';
import {
  parseVendorCapabilities,
  parseAdminCapabilities,
  categoryMatchesService,
  type VendorCapabilityDecl,
  type AdminCapabilityDef,
} from '../vendor-operations/vendor-capability.util';
import {
  normalizeVendorCustomExtrasInput,
  parseVendorCustomExtras,
  type VendorCustomExtra,
} from '../vendor-operations/vendor-custom-extras.util';

export type VendorServiceRow = {
  id: string;
  tenantId: string;
  vendorId: string;
  serviceKey: string;
  serviceName: string;
  serviceCode: string;
  description: string | null;
  status: string;
  basePayoutMinor: number | null;
  currency: string;
  capabilities: VendorCapabilityDecl[];
  customExtras: VendorCustomExtra[];
  createdAt: string;
  updatedAt: string;
};

export type VendorServicePriceInput = {
  name: string;
  basePayoutMinor: number;
};

/**
 * First-class vendor service entities (migration 065 + 066 base price).
 * Additive — does not replace services_offered JSON or service_key on requests.
 */
@Injectable()
export class VendorServicesService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async listForVendor(
    tenantId: string,
    vendorId: string,
    opts?: { includeInactive?: boolean },
  ): Promise<VendorServiceRow[]> {
    const { rows } = await this.pool.query<{
      id: string;
      tenant_id: string;
      vendor_id: string;
      service_key: string;
      service_name: string;
      service_code: string;
      description: string | null;
      status: string;
      base_payout_minor: string | null;
      currency: string;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT id, tenant_id, vendor_id, service_key, service_name, service_code, description, status,
              base_payout_minor::text, currency, capabilities, custom_extras, created_at, updated_at
       FROM vendor_services
       WHERE tenant_id = $1 AND vendor_id = $2
         AND ($3::boolean OR status = 'active')
         AND status <> 'archived'
       ORDER BY service_name ASC`,
      [tenantId, vendorId, opts?.includeInactive === true],
    );
    return rows.map((r) => this.mapRow(r));
  }

  /**
   * Upsert services from profile labels.
   * Does NOT flip status: ON/OFF is owned by patchStatus (dedicated path).
   * New rows insert as active. Existing rows keep their status.
   */
  async syncFromOfferedLabels(
    tenantId: string,
    vendorId: string | null | undefined,
    labels: string[],
    pricesByName?: Record<string, number>,
  ): Promise<VendorServiceRow[]> {
    if (!vendorId) return [];

    const cleaned = labels
      .map((l) => l.trim())
      .filter((l) => l.length > 0)
      .slice(0, 48);

    const keys = new Set<string>();
    for (const name of cleaned) {
      const key = normalizeServiceKey(name);
      if (!key || key === 'general') continue;
      if (keys.has(key)) continue;
      keys.add(key);

      const priceRaw = pricesByName?.[name] ?? pricesByName?.[key];
      const basePayout =
        priceRaw != null && Number.isFinite(priceRaw) && priceRaw > 0
          ? Math.floor(priceRaw)
          : null;

      await this.pool.query(
        `INSERT INTO vendor_services
           (tenant_id, vendor_id, service_key, service_name, service_code, status, base_payout_minor, currency)
         VALUES ($1, $2, $3, $4, 'VS-' || lpad(nextval('vendor_service_code_seq')::text, 6, '0'), 'active', $5, 'NGN')
         ON CONFLICT (vendor_id, service_key) DO UPDATE SET
           service_name = EXCLUDED.service_name,
           base_payout_minor = COALESCE(EXCLUDED.base_payout_minor, vendor_services.base_payout_minor),
           updated_at = now()`,
        [tenantId, vendorId, key, name, basePayout],
      );
    }

    return this.listForVendor(tenantId, vendorId, { includeInactive: true });
  }

  /** Apply/update base payouts for named services (does not deactivate others). */
  async applyServicePrices(
    tenantId: string,
    vendorId: string,
    prices: VendorServicePriceInput[],
  ): Promise<void> {
    for (const p of prices) {
      const name = String(p.name ?? '').trim();
      if (!name) continue;
      const key = normalizeServiceKey(name);
      if (!key || key === 'general') continue;
      const base = Math.floor(Number(p.basePayoutMinor));
      if (!Number.isFinite(base) || base < 0) continue;
      await this.pool.query(
        `INSERT INTO vendor_services
           (tenant_id, vendor_id, service_key, service_name, service_code, status, base_payout_minor, currency)
         VALUES ($1, $2, $3, $4, 'VS-' || lpad(nextval('vendor_service_code_seq')::text, 6, '0'), 'active', $5, 'NGN')
         ON CONFLICT (vendor_id, service_key) DO UPDATE SET
           service_name = EXCLUDED.service_name,
           base_payout_minor = EXCLUDED.base_payout_minor,
           updated_at = now()`,
        [tenantId, vendorId, key, name, base],
      );
    }
  }

  /**
   * Resolve existing service or create one for booking compatibility.
   * Never reactivates an inactive/archived row — vendor must PATCH status back to active.
   */
  async ensureForBooking(
    tenantId: string,
    vendorId: string,
    serviceKeyRaw: string | null,
    serviceNameRaw: string | null,
  ): Promise<{ id: string; status: string } | null> {
    const key = normalizeServiceKey(serviceKeyRaw ?? serviceNameRaw);
    if (!key || key === 'general') return null;
    const name = (serviceNameRaw ?? serviceKeyRaw ?? key).trim() || key;

    const existing = await this.pool.query<{ id: string; status: string }>(
      `SELECT id, status FROM vendor_services
       WHERE tenant_id = $1 AND vendor_id = $2 AND service_key = $3
       LIMIT 1`,
      [tenantId, vendorId, key],
    );
    if (existing.rows[0]) {
      return { id: existing.rows[0].id, status: existing.rows[0].status };
    }

    const { rows } = await this.pool.query<{ id: string; status: string }>(
      `INSERT INTO vendor_services
         (tenant_id, vendor_id, service_key, service_name, service_code, status)
       VALUES ($1, $2, $3, $4, 'VS-' || lpad(nextval('vendor_service_code_seq')::text, 6, '0'), 'active')
       ON CONFLICT (vendor_id, service_key) DO UPDATE SET
         service_name = COALESCE(NULLIF(vendor_services.service_name, ''), EXCLUDED.service_name),
         updated_at = now()
       RETURNING id, status`,
      [tenantId, vendorId, key, name],
    );
    const row = rows[0];
    return row ? { id: row.id, status: row.status } : null;
  }

  async getById(
    tenantId: string,
    vendorId: string,
    serviceId: string,
  ): Promise<VendorServiceRow | null> {
    const { rows } = await this.pool.query(
      `SELECT id, tenant_id, vendor_id, service_key, service_name, service_code, description, status,
              base_payout_minor::text, currency, capabilities, custom_extras, created_at, updated_at
       FROM vendor_services
       WHERE tenant_id = $1 AND vendor_id = $2 AND id = $3
       LIMIT 1`,
      [tenantId, vendorId, serviceId],
    );
    return rows[0] ? this.mapRow(rows[0]) : null;
  }

  async patchOwnedService(opts: {
    tenantId: string;
    vendorId: string;
    serviceId: string;
    status?: 'active' | 'inactive';
    capabilities?: VendorCapabilityDecl[];
    customExtras?: VendorCustomExtra[];
  }): Promise<VendorServiceRow> {
    const current = await this.getById(opts.tenantId, opts.vendorId, opts.serviceId);
    if (!current) {
      throw new NotFoundException({ code: 'VENDOR_SERVICE_NOT_FOUND', message: 'Vendor service not found' });
    }
    if (current.vendorId !== opts.vendorId) {
      throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not your service' });
    }
    if (current.status === 'archived') {
      throw new ForbiddenException({
        code: 'SERVICE_ARCHIVED',
        message: 'Archived services cannot be restored from this endpoint',
      });
    }

    const sets: string[] = ['updated_at = now()'];
    const params: unknown[] = [opts.tenantId, opts.vendorId, opts.serviceId];
    if (opts.status != null) {
      if (opts.status !== 'active' && opts.status !== 'inactive') {
        throw new BadRequestException({ code: 'INVALID_STATUS', message: 'status must be active or inactive' });
      }
      params.push(opts.status);
      sets.push(`status = $${params.length}`);
    }
    if (opts.capabilities != null) {
      const allowed = await this.allowedCapabilityKeys(opts.tenantId, current.serviceKey, current.serviceName);
      const cleaned: VendorCapabilityDecl[] = [];
      const seen = new Set<string>();
      for (const c of opts.capabilities) {
        const key = String(c.key ?? '').trim();
        if (!key || seen.has(key)) continue;
        if (!allowed.has(key)) {
          // Reject newly selecting Admin-disabled / unknown keys.
          // Preserve already-stored declarations below so history is not wiped.
          if (c.provided === true && !current.capabilities.some((x) => x.key === key && x.provided)) {
            throw new BadRequestException({
              code: 'CAPABILITY_INVALID',
              message: `Capability is not enabled for this service: ${key || c.label}`,
            });
          }
          continue;
        }
        seen.add(key);
        cleaned.push({
          key,
          label: allowed.get(key) || c.label,
          provided: c.provided === true,
        });
      }
      // Preserve Admin-disabled (or unmatched) declarations already on the row.
      for (const existing of current.capabilities) {
        if (seen.has(existing.key)) continue;
        if (allowed.has(existing.key)) continue;
        seen.add(existing.key);
        cleaned.push(existing);
      }
      params.push(JSON.stringify(cleaned));
      sets.push(`capabilities = $${params.length}::jsonb`);
    }
    if (opts.customExtras != null) {
      const cleaned = normalizeVendorCustomExtrasInput(opts.customExtras);
      params.push(JSON.stringify(cleaned));
      sets.push(`custom_extras = $${params.length}::jsonb`);
    }
    if (params.length === 3) {
      return current;
    }
    const { rows } = await this.pool.query(
      `UPDATE vendor_services SET ${sets.join(', ')}
       WHERE tenant_id = $1 AND vendor_id = $2 AND id = $3
       RETURNING id, tenant_id, vendor_id, service_key, service_name, service_code, description, status,
                 base_payout_minor::text, currency, capabilities, custom_extras, created_at, updated_at`,
      params,
    );
    if (!rows[0]) {
      throw new NotFoundException({ code: 'VENDOR_SERVICE_NOT_FOUND', message: 'Vendor service not found' });
    }
    return this.mapRow(rows[0]);
  }

  async allowedCapabilityKeys(
    tenantId: string,
    serviceKey: string,
    serviceName: string,
  ): Promise<Map<string, string>> {
    const defs = await this.adminCapabilityDefsForService(tenantId, serviceKey, serviceName);
    const allowed = new Map<string, string>();
    for (const cap of defs) {
      if (cap.enabled) allowed.set(cap.key, cap.label);
    }
    return allowed;
  }

  /** Full Admin defs matching a service (enabled + disabled) for vendor UI / marketplace filter. */
  async adminCapabilityDefsForService(
    tenantId: string,
    serviceKey: string,
    serviceName: string,
  ): Promise<AdminCapabilityDef[]> {
    const { rows } = await this.pool.query<{ slug: string; label: string; metadata: unknown }>(
      `SELECT slug, label, metadata FROM tenant_vendor_categories
       WHERE tenant_id = $1 AND is_active = true`,
      [tenantId],
    );
    const out: AdminCapabilityDef[] = [];
    const seen = new Set<string>();
    for (const row of rows) {
      if (!categoryMatchesService(row.slug, row.label, serviceKey, serviceName)) continue;
      for (const cap of parseAdminCapabilities(row.metadata)) {
        if (seen.has(cap.key)) continue;
        seen.add(cap.key);
        out.push(cap);
      }
    }
    return out;
  }

  async findId(
    tenantId: string,
    vendorId: string,
    serviceKey: string,
  ): Promise<string | null> {
    const key = normalizeServiceKey(serviceKey);
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM vendor_services
       WHERE tenant_id = $1 AND vendor_id = $2 AND service_key = $3
       LIMIT 1`,
      [tenantId, vendorId, key],
    );
    return rows[0]?.id ?? null;
  }

  /** Resolve vendor base payout for a service (entity price, then package name fallback). */
  async resolveBasePayoutMinor(
    tenantId: string,
    vendorId: string,
    opts: { vendorServiceId?: string | null; serviceKey?: string | null; serviceName?: string | null },
  ): Promise<{ basePayoutMinor: number; currency: string; vendorServiceId: string | null } | null> {
    if (opts.vendorServiceId) {
      const { rows } = await this.pool.query<{
        id: string;
        base_payout_minor: string | null;
        currency: string;
        service_name: string;
      }>(
        `SELECT id, base_payout_minor::text, currency, service_name
         FROM vendor_services
         WHERE tenant_id = $1 AND vendor_id = $2 AND id = $3`,
        [tenantId, vendorId, opts.vendorServiceId],
      );
      const row = rows[0];
      if (row?.base_payout_minor != null && BigInt(row.base_payout_minor) > 0n) {
        return {
          basePayoutMinor: Number(row.base_payout_minor),
          currency: row.currency || 'NGN',
          vendorServiceId: row.id,
        };
      }
      if (row) {
        const pkg = await this.packagePayoutForName(tenantId, vendorId, row.service_name);
        if (pkg) {
          return { ...pkg, vendorServiceId: row.id };
        }
      }
    }

    const key = normalizeServiceKey(opts.serviceKey ?? opts.serviceName);
    if (key && key !== 'general') {
      const { rows } = await this.pool.query<{
        id: string;
        base_payout_minor: string | null;
        currency: string;
        service_name: string;
      }>(
        `SELECT id, base_payout_minor::text, currency, service_name
         FROM vendor_services
         WHERE tenant_id = $1 AND vendor_id = $2 AND service_key = $3
         LIMIT 1`,
        [tenantId, vendorId, key],
      );
      const row = rows[0];
      if (row?.base_payout_minor != null && BigInt(row.base_payout_minor) > 0n) {
        return {
          basePayoutMinor: Number(row.base_payout_minor),
          currency: row.currency || 'NGN',
          vendorServiceId: row.id,
        };
      }
      if (row) {
        const pkg = await this.packagePayoutForName(tenantId, vendorId, row.service_name);
        if (pkg) return { ...pkg, vendorServiceId: row.id };
      }
    }

    if (opts.serviceName) {
      const pkg = await this.packagePayoutForName(tenantId, vendorId, opts.serviceName);
      if (pkg) return { ...pkg, vendorServiceId: null };
    }
    return null;
  }

  private async packagePayoutForName(
    tenantId: string,
    vendorId: string,
    serviceName: string,
  ): Promise<{ basePayoutMinor: number; currency: string } | null> {
    const { rows } = await this.pool.query<{
      unit_amount_minor: string;
      currency: string;
    }>(
      `SELECT unit_amount_minor::text, currency
       FROM vendor_packages
       WHERE tenant_id = $1 AND vendor_id = $2
         AND COALESCE(is_active, true) = true
         AND lower(trim(name)) = lower(trim($3))
       ORDER BY unit_amount_minor ASC
       LIMIT 1`,
      [tenantId, vendorId, serviceName],
    );
    const row = rows[0];
    if (!row || BigInt(row.unit_amount_minor) <= 0n) return null;
    return {
      basePayoutMinor: Number(row.unit_amount_minor),
      currency: row.currency || 'NGN',
    };
  }

  private mapRow(r: {
    id: string;
    tenant_id: string;
    vendor_id: string;
    service_key: string;
    service_name: string;
    service_code: string;
    description: string | null;
    status: string;
    base_payout_minor: string | null;
    currency: string;
    capabilities?: unknown;
    custom_extras?: unknown;
    created_at: Date;
    updated_at: Date;
  }): VendorServiceRow {
    return {
      id: r.id,
      tenantId: r.tenant_id,
      vendorId: r.vendor_id,
      serviceKey: r.service_key,
      serviceName: r.service_name,
      serviceCode: r.service_code,
      description: r.description,
      status: r.status,
      basePayoutMinor:
        r.base_payout_minor != null && r.base_payout_minor !== ''
          ? Number(r.base_payout_minor)
          : null,
      currency: r.currency || 'NGN',
      capabilities: parseVendorCapabilities(r.capabilities),
      customExtras: parseVendorCustomExtras(r.custom_extras),
      createdAt: r.created_at.toISOString(),
      updatedAt: r.updated_at.toISOString(),
    };
  }
}
