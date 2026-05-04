import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { OwanbeRole } from '../../common/types/jwt-user';

export interface MeResponseDto {
  userId: string;
  email: string;
  displayName: string | null;
  tenantId: string;
  roles: OwanbeRole[];
}

@Injectable()
export class UsersService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getMe(tenantId: string, userId: string): Promise<MeResponseDto> {
    const { rows } = await this.pool.query<{
      id: string;
      email: string;
      display_name: string | null;
      tenant_id: string;
      roles: string[] | null;
    }>(
      `SELECT u.id, u.email, u.display_name, u.tenant_id,
        COALESCE(array_agg(r.code ORDER BY r.code) FILTER (WHERE r.code IS NOT NULL), '{}') AS roles
       FROM users u
       LEFT JOIN user_roles ur ON ur.user_id = u.id
       LEFT JOIN roles r ON r.id = ur.role_id
       WHERE u.id = $1 AND u.tenant_id = $2
       GROUP BY u.id, u.email, u.display_name, u.tenant_id`,
      [userId, tenantId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'User not found in tenant' });
    }
    return {
      userId: row.id,
      email: row.email,
      displayName: row.display_name,
      tenantId: row.tenant_id,
      roles: (row.roles ?? []) as OwanbeRole[],
    };
  }
}
