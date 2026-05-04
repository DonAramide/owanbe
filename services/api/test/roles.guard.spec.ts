import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from '../src/common/guards/roles.guard';
import { ROLES_KEY } from '../src/common/decorators/roles.decorator';
import { IS_PUBLIC_KEY } from '../src/common/decorators/public.decorator';
import type { JwtUser } from '../src/common/types/jwt-user';
import type { RolesService } from '../src/roles/roles.service';

function ctx(req: Record<string, unknown>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => req }),
    getHandler: () => ({}),
    getClass: () => ({}),
  } as ExecutionContext;
}

describe('RolesGuard', () => {
  const reflector = new Reflector();

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('denies when JWT claims a role not present in DB', async () => {
    const rolesService = {
      loadPrincipal: jest.fn().mockResolvedValue({
        roles: ['client'],
        rolesVersion: 1,
        userStatus: 'active',
      }),
    } as unknown as RolesService;
    const guard = new RolesGuard(reflector, rolesService);
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === ROLES_KEY) return ['client'];
      return undefined;
    });
    const user: JwtUser = {
      userId: 'u1',
      tenantId: 't1',
      jwtRoleHints: ['admin_super'],
      roles: [],
    };
    await expect(guard.canActivate(ctx({ user }))).rejects.toThrow(ForbiddenException);
  });

  it('denies client hitting admin-only route', async () => {
    const rolesService = {
      loadPrincipal: jest.fn().mockResolvedValue({
        roles: ['client'],
        rolesVersion: 1,
        userStatus: 'active',
      }),
    } as unknown as RolesService;
    const guard = new RolesGuard(reflector, rolesService);
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === ROLES_KEY) return ['admin_super'];
      return undefined;
    });
    const user: JwtUser = {
      userId: 'u1',
      tenantId: 't1',
      jwtRoleHints: ['client'],
      roles: [],
    };
    await expect(guard.canActivate(ctx({ user }))).rejects.toThrow(ForbiddenException);
  });

  it('denies vendor hitting approve route (admin_super only)', async () => {
    const rolesService = {
      loadPrincipal: jest.fn().mockResolvedValue({
        roles: ['vendor'],
        rolesVersion: 1,
        userStatus: 'active',
      }),
    } as unknown as RolesService;
    const guard = new RolesGuard(reflector, rolesService);
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === ROLES_KEY) return ['admin_super'];
      return undefined;
    });
    const user: JwtUser = {
      userId: 'u1',
      tenantId: 't1',
      jwtRoleHints: ['vendor'],
      roles: [],
    };
    await expect(guard.canActivate(ctx({ user }))).rejects.toThrow(ForbiddenException);
  });

  it('blocks suspended accounts', async () => {
    const rolesService = {
      loadPrincipal: jest.fn().mockResolvedValue({
        roles: ['client'],
        rolesVersion: 2,
        userStatus: 'suspended',
      }),
    } as unknown as RolesService;
    const guard = new RolesGuard(reflector, rolesService);
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === ROLES_KEY) return ['client'];
      return undefined;
    });
    const user: JwtUser = {
      userId: 'u1',
      tenantId: 't1',
      jwtRoleHints: ['client'],
      roles: [],
    };
    await expect(guard.canActivate(ctx({ user }))).rejects.toThrow(ForbiddenException);
  });

  it('hydrates roles on public route when optional JWT present', async () => {
    const rolesService = {
      loadPrincipal: jest.fn().mockResolvedValue({
        roles: ['client', 'vendor_pending'],
        rolesVersion: 1,
        userStatus: 'active',
      }),
    } as unknown as RolesService;
    const guard = new RolesGuard(reflector, rolesService);
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return true;
      return undefined;
    });
    const user: JwtUser = {
      userId: 'u1',
      tenantId: 't1',
      jwtRoleHints: ['client'],
      roles: [],
    };
    await expect(guard.canActivate(ctx({ user }))).resolves.toBe(true);
    expect(user.roles).toEqual(['client', 'vendor_pending']);
    expect(user.userStatus).toBe('active');
  });
});
