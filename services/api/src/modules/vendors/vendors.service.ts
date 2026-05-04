import {
  ConflictException,
  Injectable,
  Inject,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CreateVendorDto } from './dto/create-vendor.dto';

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
}

export interface VendorDetailDto extends VendorSummaryDto {
  description: string | null;
  ownerUserId: string;
}

@Injectable()
export class VendorsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async listCatalog(
    tenantId: string,
    opts: { includeNonActive: boolean; q?: string; city?: string },
  ): Promise<{ items: VendorSummaryDto[]; nextCursor: string | null }> {
    const params: unknown[] = [tenantId];
    let p = 2;
    let statusClause = `v.status = 'active'`;
    if (opts.includeNonActive) {
      statusClause = 'TRUE';
    }
    let where = `WHERE v.tenant_id = $1 AND ${statusClause}`;
    if (opts.q) {
      where += ` AND (v.business_name ILIKE $${p} OR v.slug ILIKE $${p})`;
      params.push(`%${opts.q}%`);
      p++;
    }
    if (opts.city) {
      where += ` AND v.city ILIKE $${p}`;
      params.push(`%${opts.city}%`);
      p++;
    }
    const { rows } = await this.pool.query<{
      id: string;
      slug: string;
      business_name: string;
      city: string | null;
      country_code: string;
      status: string;
    }>(
      `SELECT v.id, v.slug, v.business_name, v.city, v.country_code, v.status::text AS status
       FROM vendors v
       ${where}
       ORDER BY v.business_name ASC
       LIMIT 100`,
      params,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        slug: r.slug,
        businessName: r.business_name,
        city: r.city,
        countryCode: r.country_code,
        status: r.status,
        ratingAverage: null,
        reviewCount: null,
        priceFromMinor: null,
        currency: null,
      })),
      nextCursor: null,
    };
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
