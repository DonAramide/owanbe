import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../database/database.tokens';
import type { OwanbePermission } from './permissions.constants';

@Injectable()
export class PermissionsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async loadPermissions(tenantId: string, userId: string): Promise<OwanbePermission[]> {
    const { rows } = await this.pool.query<{ code: string }>(
      `SELECT DISTINCT p.code
       FROM user_roles ur
       INNER JOIN roles r ON r.id = ur.role_id
       INNER JOIN role_permissions rp ON rp.role_id = r.id
       INNER JOIN permissions p ON p.code = rp.permission_code
       INNER JOIN users u ON u.id = ur.user_id
       WHERE ur.user_id = $1 AND u.tenant_id = $2`,
      [userId, tenantId],
    );
    return rows.map((r) => r.code as OwanbePermission);
  }

  async roleHasPermission(
    tenantId: string,
    userId: string,
    permission: OwanbePermission,
  ): Promise<boolean> {
    const perms = await this.loadPermissions(tenantId, userId);
    return perms.includes(permission);
  }
}
