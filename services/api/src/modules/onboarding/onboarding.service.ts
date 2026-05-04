import {
  ConflictException,
  Injectable,
  Inject,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { withActor } from '../../database/with-actor';
import type { UpsertBusinessDto } from './dto/upsert-business.dto';

@Injectable()
export class OnboardingService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async createApplication(
    tenantId: string,
    vendorId: string,
    actorUserId: string,
    idempotencyKey: string | undefined,
    bodyKey: string | undefined,
  ): Promise<{ id: string; vendorId: string; status: string }> {
    const key = idempotencyKey ?? bodyKey;
    if (!key || key.length < 8) {
      throw new UnprocessableEntityException({
        code: 'IDEMPOTENCY_REQUIRED',
        message: 'Provide Idempotency-Key header (8–128 chars) or body.idempotencyKey',
      });
    }
    if (key.length > 128) {
      throw new UnprocessableEntityException({
        code: 'IDEMPOTENCY_INVALID',
        message: 'Idempotency key too long',
      });
    }

    return withActor(this.pool, actorUserId, async (c) => {
      const existing = await c.query<{ id: string; vendor_id: string; status: string }>(
        `SELECT id, vendor_id, status::text AS status FROM vendor_applications
         WHERE tenant_id = $1 AND idempotency_key = $2`,
        [tenantId, key],
      );
      if (existing.rows[0]) {
        const row = existing.rows[0];
        return { id: row.id, vendorId: row.vendor_id, status: row.status };
      }

      try {
        const ins = await c.query<{ id: string; vendor_id: string; status: string }>(
          `INSERT INTO vendor_applications (tenant_id, vendor_id, idempotency_key)
           VALUES ($1, $2, $3)
           RETURNING id, vendor_id, status::text AS status`,
          [tenantId, vendorId, key],
        );
        const row = ins.rows[0];
        if (!row) throw new ConflictException({ code: 'INSERT_FAILED', message: 'No row' });
        return { id: row.id, vendorId: row.vendor_id, status: row.status };
      } catch (e: unknown) {
        const err = e as { code?: string };
        if (err.code === '23505') {
          const dup = await c.query<{ id: string; vendor_id: string; status: string }>(
            `SELECT id, vendor_id, status::text AS status FROM vendor_applications
             WHERE tenant_id = $1 AND idempotency_key = $2`,
            [tenantId, key],
          );
          const r = dup.rows[0];
          if (r) return { id: r.id, vendorId: r.vendor_id, status: r.status };
          throw new ConflictException({
            code: 'OPEN_APPLICATION_EXISTS',
            message: 'An open application already exists for this vendor (or idempotency conflict)',
          });
        }
        throw e;
      }
    });
  }

  async upsertBusiness(
    tenantId: string,
    vendorId: string,
    applicationId: string,
    actorUserId: string,
    dto: UpsertBusinessDto,
  ): Promise<{ business: Record<string, unknown> }> {
    return withActor(this.pool, actorUserId, async (c) => {
      const ok = await c.query(
        `SELECT 1 FROM vendor_applications va
         WHERE va.id = $1 AND va.vendor_id = $2 AND va.tenant_id = $3
           AND va.status IN ('applied', 'under_review')`,
        [applicationId, vendorId, tenantId],
      );
      if (!ok.rowCount) {
        throw new UnprocessableEntityException({
          code: 'APPLICATION_NOT_EDITABLE',
          message: 'Application not found or not editable',
        });
      }

      await c.query(
        `INSERT INTO vendor_application_business (
           application_id, legal_name, trading_name, registration_number, tax_id,
           address_line1, city, country_code, website_url
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (application_id) DO UPDATE SET
           legal_name = EXCLUDED.legal_name,
           trading_name = EXCLUDED.trading_name,
           registration_number = EXCLUDED.registration_number,
           tax_id = EXCLUDED.tax_id,
           address_line1 = EXCLUDED.address_line1,
           city = EXCLUDED.city,
           country_code = EXCLUDED.country_code,
           website_url = EXCLUDED.website_url,
           updated_at = now()`,
        [
          applicationId,
          dto.legalName,
          dto.tradingName ?? null,
          dto.registrationNumber ?? null,
          dto.taxId ?? null,
          dto.addressLine1 ?? null,
          dto.city ?? null,
          dto.countryCode.toUpperCase(),
          dto.websiteUrl ?? null,
        ],
      );

      const { rows } = await c.query<{
        legal_name: string;
        trading_name: string | null;
        country_code: string;
        city: string | null;
      }>(
        `SELECT legal_name, trading_name, country_code, city FROM vendor_application_business
         WHERE application_id = $1`,
        [applicationId],
      );
      const b = rows[0];
      return {
        business: {
          legalName: b?.legal_name,
          tradingName: b?.trading_name,
          countryCode: b?.country_code,
          city: b?.city,
        },
      };
    });
  }

  async submit(
    tenantId: string,
    vendorId: string,
    applicationId: string,
    actorUserId: string,
  ): Promise<{ status: string; submittedAt: string }> {
    return withActor(this.pool, actorUserId, async (c) => {
      const biz = await c.query(
        `SELECT 1 FROM vendor_application_business b
         INNER JOIN vendor_applications va ON va.id = b.application_id
         WHERE b.application_id = $1 AND va.vendor_id = $2 AND va.tenant_id = $3`,
        [applicationId, vendorId, tenantId],
      );
      if (!biz.rowCount) {
        throw new UnprocessableEntityException({
          code: 'BUSINESS_REQUIRED',
          message: 'Business profile must be saved before submit',
        });
      }

      const upd = await c.query<{ status: string; submitted_at: Date }>(
        `UPDATE vendor_applications
         SET status = 'under_review',
             submitted_at = COALESCE(submitted_at, now()),
             updated_at = now()
         WHERE id = $1 AND vendor_id = $2 AND tenant_id = $3
           AND status = 'applied'
         RETURNING status::text AS status, submitted_at`,
        [applicationId, vendorId, tenantId],
      );
      const row = upd.rows[0];
      if (!row) {
        throw new UnprocessableEntityException({
          code: 'INVALID_STATE',
          message: 'Application must be in applied state to submit',
        });
      }

      await c.query(
        `UPDATE vendors SET status = 'pending_review', updated_at = now()
         WHERE id = $1 AND tenant_id = $2`,
        [vendorId, tenantId],
      );

      return {
        status: row.status,
        submittedAt: row.submitted_at.toISOString(),
      };
    });
  }
}
