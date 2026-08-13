import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { normalizeServiceKey } from '../vendor-operations/vendor-pricing.util';

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
              base_payout_minor::text, currency, created_at, updated_at
       FROM vendor_services
       WHERE tenant_id = $1 AND vendor_id = $2
         AND ($3::boolean OR status = 'active')
       ORDER BY service_name ASC`,
      [tenantId, vendorId, opts?.includeInactive === true],
    );
    return rows.map((r) => this.mapRow(r));
  }

  /**
   * Upsert active services from profile labels; mark missing prior actives inactive.
   * Optional pricesByName (display name → base payout minor) writes vendor_services.base_payout_minor.
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
           status = 'active',
           base_payout_minor = COALESCE(EXCLUDED.base_payout_minor, vendor_services.base_payout_minor),
           updated_at = now()`,
        [tenantId, vendorId, key, name, basePayout],
      );
    }

    if (keys.size === 0) {
      await this.pool.query(
        `UPDATE vendor_services
         SET status = 'inactive', updated_at = now()
         WHERE tenant_id = $1 AND vendor_id = $2 AND status = 'active'`,
        [tenantId, vendorId],
      );
    } else {
      const keyList = [...keys];
      await this.pool.query(
        `UPDATE vendor_services
         SET status = 'inactive', updated_at = now()
         WHERE tenant_id = $1 AND vendor_id = $2 AND status = 'active'
           AND service_key <> ALL($3::text[])`,
        [tenantId, vendorId, keyList],
      );
    }

    return this.listForVendor(tenantId, vendorId, { includeInactive: false });
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
           status = 'active',
           base_payout_minor = EXCLUDED.base_payout_minor,
           updated_at = now()`,
        [tenantId, vendorId, key, name, base],
      );
    }
  }

  /**
   * Resolve existing service or create one for booking compatibility.
   */
  async ensureForBooking(
    tenantId: string,
    vendorId: string,
    serviceKeyRaw: string | null,
    serviceNameRaw: string | null,
  ): Promise<string | null> {
    const key = normalizeServiceKey(serviceKeyRaw ?? serviceNameRaw);
    if (!key || key === 'general') return null;
    const name = (serviceNameRaw ?? serviceKeyRaw ?? key).trim() || key;

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO vendor_services
         (tenant_id, vendor_id, service_key, service_name, service_code, status)
       VALUES ($1, $2, $3, $4, 'VS-' || lpad(nextval('vendor_service_code_seq')::text, 6, '0'), 'active')
       ON CONFLICT (vendor_id, service_key) DO UPDATE SET
         status = 'active',
         service_name = COALESCE(NULLIF(vendor_services.service_name, ''), EXCLUDED.service_name),
         updated_at = now()
       RETURNING id`,
      [tenantId, vendorId, key, name],
    );
    return rows[0]?.id ?? null;
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
      createdAt: r.created_at.toISOString(),
      updatedAt: r.updated_at.toISOString(),
    };
  }
}
