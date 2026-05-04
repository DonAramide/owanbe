import {
  ConflictException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { withActor } from '../../database/with-actor';
import { AuditLogService } from '../../audit/audit-log.service';
import { RolesService } from '../../roles/roles.service';

@Injectable()
export class AdminOnboardingService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
    private readonly rolesService: RolesService,
  ) {}

  async queue(
    tenantId: string,
    status?: 'applied' | 'under_review',
  ): Promise<{
    items: Array<{
      applicationId: string;
      vendorId: string;
      businessName: string;
      status: string;
    }>;
    nextCursor: string | null;
  }> {
    const statuses = status ? [status] : (['applied', 'under_review'] as const);
    const { rows } = await this.pool.query<{
      application_id: string;
      vendor_id: string;
      business_name: string;
      status: string;
    }>(
      `SELECT va.id AS application_id, va.vendor_id,
              v.business_name,
              va.status::text AS status
       FROM vendor_applications va
       INNER JOIN vendors v ON v.id = va.vendor_id
       WHERE va.tenant_id = $1 AND va.status::text = ANY($2::text[])
       ORDER BY va.submitted_at NULLS LAST, va.created_at ASC
       LIMIT 100`,
      [tenantId, statuses],
    );
    return {
      items: rows.map((r) => ({
        applicationId: r.application_id,
        vendorId: r.vendor_id,
        businessName: r.business_name,
        status: r.status,
      })),
      nextCursor: null,
    };
  }

  async getApplicationDetail(
    tenantId: string,
    applicationId: string,
    actorUserId: string,
  ): Promise<Record<string, unknown>> {
    const { rows } = await this.pool.query<{
      application_id: string;
      vendor_id: string;
      status: string;
      legal_name: string | null;
      country_code: string | null;
    }>(
      `SELECT va.id AS application_id, va.vendor_id, va.status::text AS status,
              b.legal_name, b.country_code
       FROM vendor_applications va
       LEFT JOIN vendor_application_business b ON b.application_id = va.id
       WHERE va.id = $1 AND va.tenant_id = $2`,
      [applicationId, tenantId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Application not found' });
    }

    const bank = await this.pool.query(
      `SELECT id, bank_name, account_number_last4, verification_status
       FROM vendor_bank_accounts
       WHERE application_id = $1 OR vendor_id = $2
       LIMIT 20`,
      [applicationId, row.vendor_id],
    );

    await this.audit.logRead({
      tenantId,
      actorUserId,
      action: 'VIEW_APPLICATION',
      resourceType: 'vendor_application',
      resourceId: applicationId,
      metadata: { vendorId: row.vendor_id },
    });

    return {
      applicationId: row.application_id,
      vendorId: row.vendor_id,
      status: row.status,
      business: {
        legalName: row.legal_name,
        countryCode: row.country_code,
      },
      bankAccountsMasked: bank.rows,
      kycSubmissionIds: [] as string[],
      portfolioItemCount: 0,
    };
  }

  async approve(
    tenantId: string,
    applicationId: string,
    adminUserId: string,
    reviewNotes?: string,
  ): Promise<{ applicationStatus: string; vendorStatus: string }> {
    const out = await withActor(this.pool, adminUserId, async (c) => {
      const cur = await c.query<{ vendor_id: string; status: string }>(
        `SELECT vendor_id, status::text AS status FROM vendor_applications
         WHERE id = $1 AND tenant_id = $2`,
        [applicationId, tenantId],
      );
      const row = cur.rows[0];
      if (!row) {
        throw new NotFoundException({ code: 'NOT_FOUND', message: 'Application not found' });
      }
      if (row.status !== 'under_review') {
        throw new ConflictException({
          code: 'INVALID_STATE',
          message: 'Application must be under_review to approve',
        });
      }

      const upd = await c.query<{ app_status: string }>(
        `UPDATE vendor_applications
         SET status = 'approved',
             reviewed_at = now(),
             reviewer_user_id = $3::uuid,
             review_notes = $4,
             updated_at = now()
         WHERE id = $1 AND tenant_id = $2 AND status = 'under_review'
         RETURNING status::text AS app_status`,
        [applicationId, tenantId, adminUserId, reviewNotes ?? null],
      );
      const appRow = upd.rows[0];
      if (!appRow) {
        throw new ConflictException({ code: 'CONFLICT', message: 'Could not approve application' });
      }

      await c.query(
        `UPDATE vendors SET status = 'active', verified_at = now(), updated_at = now()
         WHERE id = $1 AND tenant_id = $2`,
        [row.vendor_id, tenantId],
      );

      await this.promoteVendorOwnerRoles(c, tenantId, row.vendor_id);

      return { applicationStatus: appRow.app_status, vendorStatus: 'active' };
    });

    const owner = await this.pool.query<{ owner_user_id: string }>(
      `SELECT owner_user_id FROM vendors v
       INNER JOIN vendor_applications va ON va.vendor_id = v.id
       WHERE va.id = $1 AND va.tenant_id = $2`,
      [applicationId, tenantId],
    );
    const ou = owner.rows[0]?.owner_user_id;
    if (ou) {
      this.rolesService.invalidate(tenantId, ou);
    }
    return out;
  }

  private async promoteVendorOwnerRoles(
    c: PoolClient,
    tenantId: string,
    vendorId: string,
  ): Promise<void> {
    const { rows } = await c.query<{ owner_user_id: string }>(
      `SELECT owner_user_id FROM vendors WHERE id = $1 AND tenant_id = $2`,
      [vendorId, tenantId],
    );
    const ownerId = rows[0]?.owner_user_id;
    if (!ownerId) return;

    await c.query(
      `DELETE FROM user_roles ur
       USING roles r
       WHERE ur.user_id = $1::uuid
         AND ur.role_id = r.id
         AND r.code = 'vendor_pending'`,
      [ownerId],
    );

    await c.query(
      `INSERT INTO user_roles (user_id, role_id)
       SELECT $1::uuid, r.id FROM roles r WHERE r.code = 'vendor'
       ON CONFLICT DO NOTHING`,
      [ownerId],
    );
  }

  async reject(
    tenantId: string,
    applicationId: string,
    adminUserId: string,
    rejectionReason: string,
    reviewNotes?: string,
  ): Promise<{ applicationStatus: string }> {
    const out = await withActor(this.pool, adminUserId, async (c) => {
      const cur = await c.query<{ vendor_id: string; status: string }>(
        `SELECT vendor_id, status::text AS status FROM vendor_applications
         WHERE id = $1 AND tenant_id = $2`,
        [applicationId, tenantId],
      );
      const row = cur.rows[0];
      if (!row) {
        throw new NotFoundException({ code: 'NOT_FOUND', message: 'Application not found' });
      }
      if (!['applied', 'under_review'].includes(row.status)) {
        throw new ConflictException({
          code: 'INVALID_STATE',
          message: 'Application cannot be rejected from this state',
        });
      }

      const upd = await c.query<{ app_status: string }>(
        `UPDATE vendor_applications
         SET status = 'rejected',
             reviewed_at = now(),
             reviewer_user_id = $3::uuid,
             rejection_reason = $4,
             review_notes = $5,
             updated_at = now()
         WHERE id = $1 AND tenant_id = $2
         RETURNING status::text AS app_status`,
        [applicationId, tenantId, adminUserId, rejectionReason, reviewNotes ?? null],
      );
      const appRow = upd.rows[0];
      if (!appRow) {
        throw new ConflictException({ code: 'CONFLICT', message: 'Could not reject application' });
      }

      await c.query(
        `UPDATE vendors SET status = 'rejected', updated_at = now()
         WHERE id = $1 AND tenant_id = $2`,
        [row.vendor_id, tenantId],
      );

      return { applicationStatus: appRow.app_status };
    });

    const owner = await this.pool.query<{ owner_user_id: string }>(
      `SELECT owner_user_id FROM vendors v
       INNER JOIN vendor_applications va ON va.vendor_id = v.id
       WHERE va.id = $1 AND va.tenant_id = $2`,
      [applicationId, tenantId],
    );
    const ou = owner.rows[0]?.owner_user_id;
    if (ou) {
      this.rolesService.invalidate(tenantId, ou);
    }
    return out;
  }
}
