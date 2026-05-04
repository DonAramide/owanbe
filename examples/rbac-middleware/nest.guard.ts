/**
 * NestJS RBAC sketch — Owanbe
 * Use: @UseGuards(JwtAuthGuard, PermissionsGuard)
 *       @RequirePermissions('booking:create')
 */

import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

export const PERMISSIONS_KEY = 'owanbe:permissions';

/** Decorator — all listed permissions required */
export const RequirePermissions = (...perms: string[]) =>
  SetMetadata(PERMISSIONS_KEY, perms);

const ROLE_PERMISSIONS: Record<string, Set<string>> = {
  admin: new Set([
    'admin:onboarding:queue',
    'admin:onboarding:review',
    'admin:vendor:suspend',
    'booking:read:own',
    'booking:read:vendor_scope',
    'tenant:read',
    'catalog:read',
  ]),
  client: new Set([
    'booking:create',
    'booking:read:own',
    'booking:update:own',
    'payment:initiate:own',
    'payment:read:own',
    'chat:thread:read',
    'chat:message:send',
    'tenant:read',
    'catalog:read',
  ]),
  vendor: new Set([
    'vendor:profile:write:own',
    'vendor:onboarding:submit',
    'vendor:package:write',
    'booking:read:vendor_scope',
    'booking:update:vendor_scope',
    'payout:read:vendor_scope',
    'chat:thread:read',
    'chat:message:send',
    'payment:read:own',
    'tenant:read',
    'catalog:read',
  ]),
};

function expandPermissions(roles: string[]): Set<string> {
  const out = new Set<string>();
  for (const r of roles || []) {
    ROLE_PERMISSIONS[r]?.forEach((p) => out.add(p));
  }
  return out;
}

/** JwtAuthGuard should set request.user = { sub, tenantId, roles: string[] } */
@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const required =
      this.reflector.getAllAndOverride<string[]>(PERMISSIONS_KEY, [
        ctx.getHandler(),
        ctx.getClass(),
      ]) || [];
    if (!required.length) return true;

    const req = ctx.switchToHttp().getRequest();
    const perms = expandPermissions(req.user?.roles || []);
    const missing = required.filter((p) => !perms.has(p));
    if (missing.length) {
      throw new ForbiddenException({ code: 'FORBIDDEN', missing });
    }
    return true;
  }
}
