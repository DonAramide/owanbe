import { Injectable, Inject } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool } from 'pg';
import { PG_POOL } from '../database/database.tokens';
import type { OwanbeRole } from '../common/types/jwt-user';
import type { UserLifecycleStatus } from '../common/types/user-status';
import type { EnvVars } from '../config/env.schema';

export interface PrincipalSnapshot {
  roles: OwanbeRole[];
  rolesVersion: number;
  userStatus: UserLifecycleStatus;
}

interface CacheEntry extends PrincipalSnapshot {
  at: number;
}

@Injectable()
export class RolesService {
  private readonly cache = new Map<string, CacheEntry>();

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
  ) {}

  private key(tenantId: string, userId: string) {
    return `${tenantId}:${userId}`;
  }

  /** Clears in-memory entry; DB triggers still bump `roles_version` for other instances. */
  invalidate(tenantId: string, userId: string) {
    this.cache.delete(this.key(tenantId, userId));
  }

  /**
   * Authoritative principal: roles from `user_roles`, version from `users.roles_version`,
   * status from `users.status`. Cache invalidates on version/status mismatch or TTL.
   */
  async loadPrincipal(tenantId: string, userId: string): Promise<PrincipalSnapshot> {
    const ttlMs = this.config.get('ROLES_CACHE_TTL_MS', { infer: true });
    const k = this.key(tenantId, userId);

    const { rows: metaRows } = await this.pool.query<{
      roles_version: string;
      user_status: string;
    }>(
      `SELECT roles_version::text, status::text AS user_status
       FROM users WHERE id = $1 AND tenant_id = $2`,
      [userId, tenantId],
    );
    const meta = metaRows[0];
    if (!meta) {
      return { roles: [], rolesVersion: -1, userStatus: 'deleted' };
    }
    const rolesVersion = Number(meta.roles_version);
    const userStatus = meta.user_status as UserLifecycleStatus;

    const hit = this.cache.get(k);
    if (
      hit &&
      Date.now() - hit.at < ttlMs &&
      hit.rolesVersion === rolesVersion &&
      hit.userStatus === userStatus
    ) {
      return {
        roles: hit.roles,
        rolesVersion: hit.rolesVersion,
        userStatus: hit.userStatus,
      };
    }

    const { rows } = await this.pool.query<{ code: string }>(
      `SELECT r.code
       FROM user_roles ur
       INNER JOIN roles r ON r.id = ur.role_id
       INNER JOIN users u ON u.id = ur.user_id
       WHERE ur.user_id = $1 AND u.tenant_id = $2`,
      [userId, tenantId],
    );
    const roles = rows.map((r) => r.code as OwanbeRole);
    const snapshot: PrincipalSnapshot = { roles, rolesVersion, userStatus };
    this.cache.set(k, { ...snapshot, at: Date.now() });
    return snapshot;
  }
}
