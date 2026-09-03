import {
  ConflictException,
  Injectable,
  Inject,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CreateVendorDto } from './dto/create-vendor.dto';
import { VendorPricingRulesService } from '../vendor-operations/vendor-pricing-funds.service';
import {
  customerPriceFromVendorPayout,
  normalizeServiceKey,
  resolveMarkupFromRules,
} from '../vendor-operations/vendor-pricing.util';
import { VendorServicesService } from './vendor-services.service';
import { VendorAvailabilityService } from '../vendor-operations/vendor-availability.service';
import {
  parseVendorCapabilities,
  parseAdminCapabilities,
  categoryMatchesService,
  allowedCapabilitySet,
} from '../vendor-operations/vendor-capability.util';
import { resolveEventWindow } from '../vendor-operations/vendor-availability.util';

export interface VendorServiceOfferingDto {
  id: string;
  serviceKey: string;
  serviceName: string;
  serviceCode: string | null;
  description: string | null;
  /** Customer-facing price when a matching package exists (existing markup rules). */
  priceFromMinor: number | null;
  currency: string | null;
  offerStatus: string;
  availabilityStatus: 'AVAILABLE' | 'BOOKED' | 'CONFLICTING' | 'UNAVAILABLE' | null;
  bookedRanges: Array<{ startsAt: string; endsAt: string }>;
  /** Vendor-level overlay windows (blackout / vacation / not accepting). Additive. */
  unavailableRanges: Array<{ startsAt: string; endsAt: string; kind: 'blackout' | 'vacation' | 'closed' }>;
  /** Capabilities the vendor actually provides and Admin still enables (public). */
  capabilities: Array<{ key: string; label: string }>;
}

export interface VendorSummaryDto {
  id: string;
  slug: string;
  businessName: string;
  city: string | null;
  countryCode: string;
  status: string;
  ratingAverage: number | null;
  reviewCount: number | null;
  priceFromMinor: number | null;
  currency: string | null;
  category: string | null;
  servicesOffered: string[];
  /** First-class vendor_services rows (ids required for service-specific requests). */
  services: VendorServiceOfferingDto[];
}

export interface VendorDetailDto extends VendorSummaryDto {
  description: string | null;
  ownerUserId: string;
}

@Injectable()
export class VendorsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly pricingRules: VendorPricingRulesService,
    @Optional() private readonly vendorServices?: VendorServicesService,
    @Optional() private readonly availability?: VendorAvailabilityService,
  ) {}

  async listCatalog(
    tenantId: string,
    opts: { includeNonActive: boolean; q?: string; city?: string; service?: string },
  ): Promise<{ items: VendorSummaryDto[]; nextCursor: string | null }> {
    const params: unknown[] = [tenantId];
    let p = 2;
    let statusClause = `v.status = 'active'`;
    if (opts.includeNonActive) {
      statusClause = 'TRUE';
    }
    let where = `WHERE v.tenant_id = $1 AND ${statusClause}`;
    if (opts.q) {
      // Marketplace search is vendor-public only. Do not match users.display_name,
      // leftover seed vendors.business_name/slug from account creation, or email.
      where += ` AND (
        COALESCE(NULLIF(TRIM(vp.business_name), ''), v.business_name) ILIKE $${p}
        OR COALESCE(v.city, '') ILIKE $${p}
        OR COALESCE(vp.city, '') ILIKE $${p}
        OR COALESCE(vp.state, '') ILIKE $${p}
        OR COALESCE(vp.country, '') ILIKE $${p}
        OR COALESCE(v.country_code, '') ILIKE $${p}
        OR COALESCE(vp.bio, '') ILIKE $${p}
        OR COALESCE(vp.category, '') ILIKE $${p}
        OR COALESCE(vp.subcategory, '') ILIKE $${p}
        OR COALESCE(vp.services_offered::text, '') ILIKE $${p}
        OR COALESCE(vp.service_areas::text, '') ILIKE $${p}
        OR v.id::text ILIKE $${p}
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(COALESCE(vp.services_offered, '[]'::jsonb)) s
          WHERE s ILIKE $${p}
        )
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(COALESCE(vp.service_areas, '[]'::jsonb)) a
          WHERE a ILIKE $${p}
        )
        OR EXISTS (
          SELECT 1 FROM vendor_services vs
          WHERE vs.tenant_id = v.tenant_id
            AND vs.vendor_id = v.id
            AND vs.status = 'active'
            AND (
              vs.service_name ILIKE $${p}
              OR vs.service_key ILIKE $${p}
              OR vs.service_code ILIKE $${p}
            )
        )
      )`;
      params.push(`%${opts.q}%`);
      p++;
    }
    if (opts.city) {
      where += ` AND v.city ILIKE $${p}`;
      params.push(`%${opts.city}%`);
      p++;
    }
    if (opts.service && opts.service.trim() && opts.service.trim().toLowerCase() !== 'all') {
      where += ` AND (
        vp.category ILIKE $${p}
        OR vp.services_offered::text ILIKE $${p}
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(COALESCE(vp.services_offered, '[]'::jsonb)) s
          WHERE s ILIKE $${p}
        )
        OR EXISTS (
          SELECT 1 FROM vendor_services vs
          WHERE vs.tenant_id = v.tenant_id
            AND vs.vendor_id = v.id
            AND vs.status = 'active'
            AND (vs.service_name ILIKE $${p} OR vs.service_key ILIKE $${p} OR vs.service_code ILIKE $${p})
        )
      )`;
      params.push(`%${opts.service.trim()}%`);
      p++;
    }
    const { rows } = await this.pool.query<{
      id: string;
      slug: string;
      business_name: string;
      city: string | null;
      country_code: string;
      status: string;
      category: string | null;
      services_offered: unknown;
      services_from_entity: string[] | null;
      services_json: unknown;
      currency: string | null;
      min_payout_minor: string | null;
    }>(
      `SELECT v.id,
              v.slug,
              COALESCE(NULLIF(vp.business_name, ''), v.business_name) AS business_name,
              v.city,
              v.country_code,
              v.status::text AS status,
              vp.category,
              vp.services_offered,
              (
                SELECT COALESCE(array_agg(vs.service_name ORDER BY vs.service_name), ARRAY[]::text[])
                FROM vendor_services vs
                WHERE vs.tenant_id = v.tenant_id
                  AND vs.vendor_id = v.id
                  AND vs.status = 'active'
              ) AS services_from_entity,
              (
                SELECT COALESCE(
                  json_agg(
                    json_build_object(
                      'id', vs.id,
                      'serviceKey', vs.service_key,
                      'serviceName', vs.service_name,
                      'serviceCode', vs.service_code,
                      'description', vs.description,
                      'payoutMinor', COALESCE(vs.base_payout_minor::text, pkg.unit_amount_minor),
                      'currency', COALESCE(NULLIF(vs.currency, ''), pkg.currency),
                      'capabilities', vs.capabilities
                    )
                    ORDER BY vs.service_name
                  ),
                  '[]'::json
                )
                FROM vendor_services vs
                LEFT JOIN LATERAL (
                  SELECT p.unit_amount_minor::text AS unit_amount_minor, p.currency
                  FROM vendor_packages p
                  WHERE p.tenant_id = vs.tenant_id
                    AND p.vendor_id = vs.vendor_id
                    AND COALESCE(p.is_active, true) = true
                    AND lower(trim(p.name)) = lower(trim(vs.service_name))
                  ORDER BY p.unit_amount_minor ASC
                  LIMIT 1
                ) pkg ON TRUE
                WHERE vs.tenant_id = v.tenant_id
                  AND vs.vendor_id = v.id
                  AND vs.status = 'active'
              ) AS services_json,
              pkg.currency,
              pkg.min_payout_minor
       FROM vendors v
       LEFT JOIN vendor_profiles vp
         ON vp.vendor_id = v.id AND vp.tenant_id = v.tenant_id
       LEFT JOIN LATERAL (
         SELECT p.currency, p.unit_amount_minor::text AS min_payout_minor
         FROM vendor_packages p
         WHERE p.tenant_id = v.tenant_id
           AND p.vendor_id = v.id
           AND COALESCE(p.is_active, true) = true
         ORDER BY p.unit_amount_minor ASC
         LIMIT 1
       ) pkg ON TRUE
       ${where}
         AND v.owner_user_id IS NOT NULL
       ORDER BY COALESCE(NULLIF(vp.business_name, ''), v.business_name) ASC
       LIMIT 100`,
      params,
    );
    const parseServices = (raw: unknown): string[] => {
      if (Array.isArray(raw)) return raw.map((x) => String(x)).filter(Boolean);
      if (typeof raw === 'string') {
        try {
          const j = JSON.parse(raw);
          if (Array.isArray(j)) return j.map((x) => String(x)).filter(Boolean);
        } catch {
          return raw.split(',').map((s) => s.trim()).filter(Boolean);
        }
      }
      return [];
    };

    const rules = await this.pricingRules.listRuleRows(tenantId);
    const categoryRows = await this.loadActiveCategoryCapabilityRows(tenantId);

    return {
      items: rows.map((r) => {
        const fromEntity = (r.services_from_entity ?? []).filter(Boolean);
        const servicesOffered =
          fromEntity.length > 0 ? fromEntity : parseServices(r.services_offered);
        const services = this.mapServiceOfferings(r.services_json, r.id, rules, categoryRows);
        const serviceKey =
          opts.service && opts.service.trim().toLowerCase() !== 'all'
            ? normalizeServiceKey(opts.service)
            : normalizeServiceKey(r.category ?? servicesOffered[0] ?? null);

        let priceFromMinor: number | null = null;
        const servicePrices = services
          .map((s) => s.priceFromMinor)
          .filter((p): p is number => p != null && p > 0);
        if (servicePrices.length > 0) {
          priceFromMinor = Math.min(...servicePrices);
        } else if (r.min_payout_minor != null) {
          const payout = BigInt(r.min_payout_minor);
          if (payout > 0n) {
            const { markupBps } = resolveMarkupFromRules(rules, serviceKey, r.id);
            priceFromMinor = Number(
              customerPriceFromVendorPayout(payout, markupBps).customerPriceMinor,
            );
          }
        }

        return {
          id: r.id,
          slug: r.slug,
          businessName: r.business_name,
          city: r.city,
          countryCode: r.country_code,
          status: r.status,
          ratingAverage: null,
          reviewCount: null,
          priceFromMinor,
          currency: r.currency ?? (priceFromMinor != null ? 'NGN' : null),
          category: r.category,
          servicesOffered,
          services,
        };
      }),
      nextCursor: null,
    };
  }

  /**
   * Public organizer-facing services for a vendor (first-class vendor_services + package price).
   * Optional from/to (ISO) compute service-specific date availability. Inactive services are omitted.
   */
  async listVendorServices(
    tenantId: string,
    vendorId: string,
    opts?: { from?: string; to?: string },
  ): Promise<{ items: VendorServiceOfferingDto[] }> {
    const { rows: vendorRows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM vendors
       WHERE tenant_id = $1 AND id = $2 AND owner_user_id IS NOT NULL`,
      [tenantId, vendorId],
    );
    if (!vendorRows.length) {
      throw new NotFoundException({ code: 'VENDOR_NOT_FOUND', message: 'Vendor not found' });
    }

    const window = this.parseWindow(opts?.from, opts?.to);

    const { rows } = await this.pool.query<{
      id: string;
      service_key: string;
      service_name: string;
      service_code: string | null;
      description: string | null;
      payout_minor: string | null;
      currency: string | null;
      capabilities: unknown;
      status: string;
    }>(
      `SELECT vs.id, vs.service_key, vs.service_name, vs.service_code, vs.description,
              COALESCE(vs.base_payout_minor::text, pkg.unit_amount_minor) AS payout_minor,
              COALESCE(NULLIF(vs.currency, ''), pkg.currency) AS currency,
              vs.capabilities, vs.status
       FROM vendor_services vs
       LEFT JOIN LATERAL (
         SELECT p.unit_amount_minor::text AS unit_amount_minor, p.currency
         FROM vendor_packages p
         WHERE p.tenant_id = vs.tenant_id
           AND p.vendor_id = vs.vendor_id
           AND COALESCE(p.is_active, true) = true
           AND lower(trim(p.name)) = lower(trim(vs.service_name))
         ORDER BY p.unit_amount_minor ASC
         LIMIT 1
       ) pkg ON TRUE
       WHERE vs.tenant_id = $1 AND vs.vendor_id = $2 AND vs.status = 'active'
       ORDER BY vs.service_name ASC`,
      [tenantId, vendorId],
    );

    const rules = await this.pricingRules.listRuleRows(tenantId);
    const categoryRows = await this.loadActiveCategoryCapabilityRows(tenantId);
    const items: VendorServiceOfferingDto[] = [];
    for (const r of rows) {
      let priceFromMinor: number | null = null;
      if (r.payout_minor != null) {
        const payout = BigInt(r.payout_minor);
        if (payout > 0n) {
          const { markupBps } = resolveMarkupFromRules(rules, r.service_key, vendorId);
          priceFromMinor = Number(
            customerPriceFromVendorPayout(payout, markupBps).customerPriceMinor,
          );
        }
      }
      const capabilities = this.publicCapabilities(
        categoryRows,
        r.service_key,
        r.service_name,
        r.capabilities,
      );
      let availabilityStatus: VendorServiceOfferingDto['availabilityStatus'] = window
        ? 'AVAILABLE'
        : null;
      let bookedRanges: VendorServiceOfferingDto['bookedRanges'] = [];
      let unavailableRanges: VendorServiceOfferingDto['unavailableRanges'] = [];
      if (window && this.availability) {
        const classified = await this.availability.classifyServiceWindow({
          tenantId,
          vendorId,
          vendorServiceId: r.id,
          serviceKey: r.service_key,
          window,
          offerActive: r.status === 'active',
        });
        availabilityStatus = classified.availabilityStatus;
        bookedRanges = classified.bookedRanges;
        unavailableRanges = classified.unavailableRanges;
      }
      items.push({
        id: r.id,
        serviceKey: r.service_key,
        serviceName: r.service_name,
        serviceCode: r.service_code ?? null,
        description: r.description,
        priceFromMinor,
        currency: r.currency ?? (priceFromMinor != null ? 'NGN' : null),
        offerStatus: r.status,
        availabilityStatus,
        bookedRanges,
        unavailableRanges,
        capabilities,
      });
    }

    if (items.length === 0 && this.vendorServices) {
      const synced = await this.vendorServices.listForVendor(tenantId, vendorId);
      return {
        items: synced
          .filter((s) => s.status === 'active')
          .map((s) => ({
            id: s.id,
            serviceKey: s.serviceKey,
            serviceName: s.serviceName,
            serviceCode: s.serviceCode ?? null,
            description: s.description,
            priceFromMinor: null,
            currency: null,
            offerStatus: s.status,
            availabilityStatus: window ? 'AVAILABLE' : null,
            bookedRanges: [],
            unavailableRanges: [],
            capabilities: this.publicCapabilities(
              categoryRows,
              s.serviceKey,
              s.serviceName,
              s.capabilities,
            ),
          })),
      };
    }

    return { items };
  }

  private async loadActiveCategoryCapabilityRows(
    tenantId: string,
  ): Promise<Array<{ slug: string; label: string; metadata: unknown }>> {
    const { rows } = await this.pool.query<{ slug: string; label: string; metadata: unknown }>(
      `SELECT slug, label, metadata FROM tenant_vendor_categories
       WHERE tenant_id = $1 AND is_active = true`,
      [tenantId],
    );
    return rows;
  }

  private publicCapabilities(
    categoryRows: Array<{ slug: string; label: string; metadata: unknown }>,
    serviceKey: string,
    serviceName: string,
    capabilitiesRaw: unknown,
  ): Array<{ key: string; label: string }> {
    const adminDefs = [];
    const seen = new Set<string>();
    for (const row of categoryRows) {
      if (!categoryMatchesService(row.slug, row.label, serviceKey, serviceName)) continue;
      for (const cap of parseAdminCapabilities(row.metadata)) {
        if (seen.has(cap.key)) continue;
        seen.add(cap.key);
        adminDefs.push(cap);
      }
    }
    const vendorDecls = parseVendorCapabilities(capabilitiesRaw);
    return Array.from(allowedCapabilitySet(adminDefs, vendorDecls).entries()).map(([key, label]) => ({
      key,
      label,
    }));
  }

  private parseWindow(fromRaw?: string, toRaw?: string): { start: Date; end: Date } | null {
    if (!fromRaw || !toRaw) return null;
    const from = new Date(fromRaw);
    const to = new Date(toRaw);
    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) return null;
    return resolveEventWindow(from, to);
  }

  private mapServiceOfferings(
    raw: unknown,
    vendorId: string,
    rules: Awaited<ReturnType<VendorPricingRulesService['listRuleRows']>>,
    categoryRows: Array<{ slug: string; label: string; metadata: unknown }> = [],
  ): VendorServiceOfferingDto[] {
    const list = Array.isArray(raw)
      ? raw
      : typeof raw === 'string'
        ? (() => {
            try {
              const j = JSON.parse(raw);
              return Array.isArray(j) ? j : [];
            } catch {
              return [];
            }
          })()
        : [];

    return list
      .map((entry): VendorServiceOfferingDto | null => {
        const e = entry as Record<string, unknown>;
        const id = String(e.id ?? '').trim();
        const serviceKey = String(e.serviceKey ?? e.service_key ?? '').trim();
        const serviceName = String(e.serviceName ?? e.service_name ?? '').trim();
        if (!id || !serviceKey || !serviceName) return null;
        const payoutRaw = e.payoutMinor ?? e.payout_minor;
        let priceFromMinor: number | null = null;
        if (payoutRaw != null && String(payoutRaw).trim() !== '') {
          try {
            const payout = BigInt(String(payoutRaw));
            if (payout > 0n) {
              const { markupBps } = resolveMarkupFromRules(rules, serviceKey, vendorId);
              priceFromMinor = Number(
                customerPriceFromVendorPayout(payout, markupBps).customerPriceMinor,
              );
            }
          } catch {
            priceFromMinor = null;
          }
        }
        const currency =
          e.currency != null
            ? String(e.currency)
            : priceFromMinor != null
              ? 'NGN'
              : null;
        const serviceCodeRaw = e.serviceCode ?? e.service_code;
        const capabilities = this.publicCapabilities(
          categoryRows,
          serviceKey,
          serviceName,
          e.capabilities,
        );
        return {
          id,
          serviceKey,
          serviceName,
          serviceCode:
            serviceCodeRaw != null && String(serviceCodeRaw).trim() !== ''
              ? String(serviceCodeRaw).trim()
              : null,
          description: e.description != null ? String(e.description) : null,
          priceFromMinor,
          currency,
          offerStatus: 'active',
          availabilityStatus: null,
          bookedRanges: [],
          unavailableRanges: [],
          capabilities,
        };
      })
      .filter((x): x is VendorServiceOfferingDto => x != null);
  }

  async createVendor(
    tenantId: string,
    ownerUserId: string,
    dto: CreateVendorDto,
  ): Promise<VendorDetailDto> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const ins = await client.query<{
        id: string;
        slug: string;
        business_name: string;
        city: string | null;
        country_code: string;
        status: string;
        description: string | null;
        owner_user_id: string;
      }>(
        `INSERT INTO vendors (tenant_id, owner_user_id, business_name, slug, status, description, country_code, city)
         VALUES ($1, $2, $3, $4, 'draft', $5, $6, $7)
         RETURNING id, slug, business_name, city, country_code, status::text AS status, description, owner_user_id`,
        [
          tenantId,
          ownerUserId,
          dto.businessName,
          dto.slug,
          dto.description ?? null,
          dto.countryCode.toUpperCase(),
          dto.city ?? null,
        ],
      );
      const v = ins.rows[0];
      if (!v) {
        throw new ConflictException({ code: 'VENDOR_CREATE_FAILED', message: 'Insert failed' });
      }
      await client.query(
        `INSERT INTO user_roles (user_id, role_id)
         SELECT $1::uuid, r.id FROM roles r WHERE r.code = 'vendor_pending'
         ON CONFLICT DO NOTHING`,
        [ownerUserId],
      );
      await client.query('COMMIT');
      return {
        id: v.id,
        slug: v.slug,
        businessName: v.business_name,
        city: v.city,
        countryCode: v.country_code,
        status: v.status,
        ratingAverage: null,
        reviewCount: null,
        priceFromMinor: null,
        currency: null,
        description: v.description,
        ownerUserId: v.owner_user_id,
        category: null,
        servicesOffered: [],
        services: [],
      };
    } catch (e: unknown) {
      await client.query('ROLLBACK');
      const err = e as { code?: string };
      if (err.code === '23505') {
        throw new ConflictException({
          code: 'SLUG_CONFLICT',
          message: 'Vendor slug already exists for this tenant',
        });
      }
      throw e;
    } finally {
      client.release();
    }
  }
}
