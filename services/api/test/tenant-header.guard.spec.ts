import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { TenantHeaderGuard } from '../src/common/guards/tenant-header.guard';
import { SKIP_TENANT_KEY } from '../src/common/decorators/skip-tenant.decorator';
import type { JwtUser } from '../src/common/types/jwt-user';

function ctx(req: Record<string, unknown>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => req }),
    getHandler: () => ({}),
    getClass: () => ({}),
  } as ExecutionContext;
}

describe('TenantHeaderGuard', () => {
  const reflector = new Reflector();
  const guard = new TenantHeaderGuard(reflector);

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('sets tenant from JWT and rejects spoofed X-Tenant-Id', () => {
    const tenant = '11111111-1111-4111-8111-111111111111';
    const spoof = '22222222-2222-4222-8222-222222222222';
    const user: JwtUser = {
      userId: '33333333-3333-4333-8333-333333333333',
      tenantId: tenant,
      jwtRoleHints: [],
      roles: [],
    };
    const req = {
      user,
      headers: { 'x-tenant-id': spoof },
    };
    expect(() => guard.canActivate(ctx(req))).toThrow(ForbiddenException);
  });

  it('allows authenticated request when header matches JWT tenant', () => {
    const tenant = '11111111-1111-4111-8111-111111111111';
    const user: JwtUser = {
      userId: '33333333-3333-4333-8333-333333333333',
      tenantId: tenant,
      jwtRoleHints: [],
      roles: [],
    };
    const req = { user, headers: { 'x-tenant-id': tenant } };
    expect(guard.canActivate(ctx(req))).toBe(true);
    expect((req as { tenantId?: string }).tenantId).toBe(tenant);
  });

  it('allows authenticated request when X-Tenant-Id omitted', () => {
    const tenant = '11111111-1111-4111-8111-111111111111';
    const user: JwtUser = {
      userId: '33333333-3333-4333-8333-333333333333',
      tenantId: tenant,
      jwtRoleHints: [],
      roles: [],
    };
    const req = { user, headers: {} };
    expect(guard.canActivate(ctx(req))).toBe(true);
    expect((req as { tenantId?: string }).tenantId).toBe(tenant);
  });

  it('skips when SkipTenant metadata set', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === SKIP_TENANT_KEY) return true;
      return false;
    });
    const req = { headers: {} };
    expect(guard.canActivate(ctx(req))).toBe(true);
    jest.restoreAllMocks();
  });
});
