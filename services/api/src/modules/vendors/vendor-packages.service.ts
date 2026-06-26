import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { randomUUID } from 'crypto';
import { PG_POOL } from '../../database/database.tokens';
import type { JwtUser } from '../../common/types/jwt-user';
import { VendorAccessService } from '../../ownership/vendor-access.service';

export type VendorPackageView = {
  id: string;
  vendorId: string;
  code: string;
  name: string;
  description: string | null;
  billingUnit: string;
  currency: string;
  unitAmountMinor: number;
  minGuests: number | null;
  maxGuests: number | null;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  metadata: Record<string, unknown>;
};

@Injectable()
export class VendorPackagesService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly vendorAccess: VendorAccessService,
  ) {}

  private mapRow(row: {
    id: string;
    vendor_id: string;
    code: string;
    name: string;
    description: string | null;
    billing_unit: string;
    currency: string;
    unit_amount_minor: string;
    min_guests: number | null;
    max_guests: number | null;
    is_active: boolean;
    sort_order: number;
    created_at: Date;
    metadata: Record<string, unknown>;
  }): VendorPackageView {
    return {
      id: row.id,
      vendorId: row.vendor_id,
      code: row.code,
      name: row.name,
      description: row.description,
      billingUnit: row.billing_unit,
      currency: row.currency,
      unitAmountMinor: Number(row.unit_amount_minor),
      minGuests: row.min_guests,
      maxGuests: row.max_guests,
      isActive: row.is_active,
      sortOrder: row.sort_order,
      createdAt: row.created_at.toISOString(),
      metadata: row.metadata ?? {},
    };
  }

  async listForVendorUser(tenantId: string, user: JwtUser): Promise<{ items: VendorPackageView[] }> {
    const vendorId = await this.vendorAccess.resolveVendorIdForUser(tenantId, user.userId);
    const { rows } = await this.pool.query<{
      id: string;
      vendor_id: string;
      code: string;
      name: string;
      description: string | null;
      billing_unit: string;
      currency: string;
      unit_amount_minor: string;
      min_guests: number | null;
      max_guests: number | null;
      is_active: boolean;
      sort_order: number;
      created_at: Date;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, vendor_id, code, name, description, billing_unit::text, currency,
              unit_amount_minor, min_guests, max_guests, is_active, sort_order, created_at, metadata
       FROM vendor_packages
       WHERE tenant_id = $1 AND vendor_id = $2
       ORDER BY sort_order ASC, name ASC`,
      [tenantId, vendorId],
    );
    return { items: rows.map((r) => this.mapRow(r)) };
  }

  async createForVendorUser(
    tenantId: string,
    user: JwtUser,
    body: {
      name?: string;
      description?: string;
      category?: string;
      priceMinor?: number;
      currency?: string;
    },
  ): Promise<VendorPackageView> {
    const vendorId = await this.vendorAccess.resolveVendorIdForUser(tenantId, user.userId);
    const name = String(body.name ?? '').trim();
    if (!name) {
      throw new BadRequestException({ code: 'INVALID_PACKAGE', message: 'Package name is required' });
    }
    const priceMinor = Math.max(0, Math.floor(Number(body.priceMinor ?? 0)));
    if (priceMinor <= 0) {
      throw new BadRequestException({ code: 'INVALID_PRICE', message: 'Price must be greater than zero' });
    }
    const code = `pkg_${randomUUID().slice(0, 8)}`;
    const currency = (body.currency ?? 'NGN').trim().toUpperCase().slice(0, 3) || 'NGN';
    const { rows } = await this.pool.query<{
      id: string;
      vendor_id: string;
      code: string;
      name: string;
      description: string | null;
      billing_unit: string;
      currency: string;
      unit_amount_minor: string;
      min_guests: number | null;
      max_guests: number | null;
      is_active: boolean;
      sort_order: number;
      created_at: Date;
      metadata: Record<string, unknown>;
    }>(
      `INSERT INTO vendor_packages (
         tenant_id, vendor_id, code, name, description, billing_unit, currency, unit_amount_minor, metadata
       ) VALUES ($1, $2, $3, $4, $5, 'fixed', $6, $7, $8::jsonb)
       RETURNING id, vendor_id, code, name, description, billing_unit::text, currency,
                 unit_amount_minor, min_guests, max_guests, is_active, sort_order, created_at, metadata`,
      [
        tenantId,
        vendorId,
        code,
        name,
        body.description?.trim() || null,
        currency,
        priceMinor,
        JSON.stringify({ category: body.category?.trim() || null }),
      ],
    );
    return this.mapRow(rows[0]!);
  }

  async patchForVendorUser(
    tenantId: string,
    user: JwtUser,
    packageId: string,
    body: { isActive?: boolean; name?: string; description?: string },
  ): Promise<VendorPackageView> {
    const vendorId = await this.vendorAccess.resolveVendorIdForUser(tenantId, user.userId);
    const sets: string[] = [];
    const vals: unknown[] = [tenantId, vendorId, packageId];
    let idx = 4;
    if (body.isActive !== undefined) {
      sets.push(`is_active = $${idx++}`);
      vals.push(body.isActive);
    }
    if (body.name != null) {
      sets.push(`name = $${idx++}`);
      vals.push(String(body.name).trim());
    }
    if (body.description !== undefined) {
      sets.push(`description = $${idx++}`);
      vals.push(body.description ? String(body.description).trim() : null);
    }
    if (sets.length === 0) {
      throw new BadRequestException({ code: 'NO_CHANGES', message: 'No fields to update' });
    }
    sets.push('updated_at = now()');
    const { rows } = await this.pool.query<{
      id: string;
      vendor_id: string;
      code: string;
      name: string;
      description: string | null;
      billing_unit: string;
      currency: string;
      unit_amount_minor: string;
      min_guests: number | null;
      max_guests: number | null;
      is_active: boolean;
      sort_order: number;
      created_at: Date;
      metadata: Record<string, unknown>;
    }>(
      `UPDATE vendor_packages SET ${sets.join(', ')}
       WHERE tenant_id = $1 AND vendor_id = $2 AND id = $3::uuid
       RETURNING id, vendor_id, code, name, description, billing_unit::text, currency,
                 unit_amount_minor, min_guests, max_guests, is_active, sort_order, created_at, metadata`,
      vals,
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'PACKAGE_NOT_FOUND', message: 'Package not found' });
    }
    return this.mapRow(row);
  }
}
