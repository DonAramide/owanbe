import { ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
import type { EnvVars } from '../config/env.schema';
import type { JwtUser } from '../common/types/jwt-user';
import { SUPER_ADMIN_ROLES } from '../common/permission-matrix';
import { RolesService } from '../roles/roles.service';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class DevSuperAdminAuthService {
  constructor(
    private readonly config: ConfigService<EnvVars, true>,
    private readonly rolesService: RolesService,
  ) {}

  allowed(): boolean {
    return (
      this.config.get('NODE_ENV', { infer: true }) !== 'production' &&
      this.config.get('ALLOW_DEV_SUPER_ADMIN_AUTH', { infer: true }) === true
    );
  }

  async tryResolve(context: ExecutionContext): Promise<JwtUser | null> {
    if (!this.allowed()) return null;

    const req = context.switchToHttp().getRequest<Request & { user?: JwtUser }>();
    const devUserHeader = req.headers['x-dev-user-id'];
    const devEmailHeader = req.headers['x-dev-user-email'];
    const tenantHeader = req.headers['x-tenant-id'];
    const userId = typeof devUserHeader === 'string' ? devUserHeader.trim() : '';
    if (!userId || !UUID_RE.test(userId)) return null;

    const tenantId =
      typeof tenantHeader === 'string' && UUID_RE.test(tenantHeader.trim())
        ? tenantHeader.trim()
        : '11111111-1111-4111-8111-111111111111';

    const principal = await this.rolesService.loadPrincipal(tenantId, userId);
    const isSuper = principal.roles.some((r) => (SUPER_ADMIN_ROLES as readonly string[]).includes(r));
    if (!isSuper) return null;

    const email =
      typeof devEmailHeader === 'string' && devEmailHeader.includes('@')
        ? devEmailHeader.trim()
        : undefined;

    return {
      userId,
      email,
      tenantId,
      jwtRoleHints: principal.roles,
      roles: principal.roles,
      userStatus: principal.userStatus,
    };
  }
}
