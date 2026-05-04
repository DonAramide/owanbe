import {
  BadRequestException,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { SKIP_TENANT_KEY } from '../decorators/skip-tenant.decorator';
import type { JwtUser } from '../types/jwt-user';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class TenantHeaderGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const skip = this.reflector.getAllAndOverride<boolean>(SKIP_TENANT_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (skip) {
      return true;
    }

    const req = context.switchToHttp().getRequest<
      Request & { tenantId?: string; catalogTenantId?: string; user?: JwtUser }
    >();
    const headerRaw = req.headers['x-tenant-id'];
    const header =
      typeof headerRaw === 'string' && headerRaw.trim() ? headerRaw.trim() : undefined;

    if (req.user) {
      const jwtTenant = req.user.tenantId;
      if (header && header !== jwtTenant) {
        throw new ForbiddenException({
          code: 'TENANT_MISMATCH',
          message: 'X-Tenant-Id must match JWT tenant when provided',
        });
      }
      req.tenantId = jwtTenant;
      return true;
    }

    // Anonymous / public catalog: tenant scope comes from header only (not impersonation).
    if (!header || !UUID_RE.test(header)) {
      throw new BadRequestException({
        code: 'TENANT_REQUIRED',
        message: 'X-Tenant-Id is required for unauthenticated requests',
      });
    }
    req.catalogTenantId = header;
    return true;
  }
}
