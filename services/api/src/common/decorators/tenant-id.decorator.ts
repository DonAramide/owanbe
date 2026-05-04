import { createParamDecorator, ExecutionContext, BadRequestException } from '@nestjs/common';

/**
 * Effective tenant for the request:
 * - Authenticated: always `user.tenantId` (JWT; never trust header alone).
 * - Public: `catalogTenantId` from `X-Tenant-Id` (catalog scope).
 */
export const TenantId = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest<{
      tenantId?: string;
      catalogTenantId?: string;
    }>();
    if (request.tenantId) {
      return request.tenantId;
    }
    if (request.catalogTenantId) {
      return request.catalogTenantId;
    }
    throw new BadRequestException({
      code: 'TENANT_REQUIRED',
      message: 'Tenant context missing',
    });
  },
);
