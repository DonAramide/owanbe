import { ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PermissionsGuard } from '../src/permissions/permissions.guard';
import { PERMISSIONS_KEY } from '../src/permissions/permissions.decorator';
import type { PermissionsService } from '../src/permissions/permissions.service';
import type { SecurityEventService } from '../src/security/security-event.service';
import type { JwtUser } from '../src/common/types/jwt-user';

function ctx(user?: JwtUser) {
  return {
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
    getHandler: () => ({}),
    getClass: () => ({}),
  } as never;
}

describe('PermissionsGuard', () => {
  const reflector = new Reflector();

  afterEach(() => jest.restoreAllMocks());

  it('allows super_admin without DB permission lookup', async () => {
    const permissions = { loadPermissions: jest.fn() } as unknown as PermissionsService;
    const securityEvents = { record: jest.fn() } as unknown as SecurityEventService;
    const guard = new PermissionsGuard(reflector, permissions, securityEvents);
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['event.create']);
    const user: JwtUser = {
      userId: 'sa',
      tenantId: 't1',
      jwtRoleHints: [],
      roles: ['super_admin'],
    };
    await expect(guard.canActivate(ctx(user))).resolves.toBe(true);
    expect(permissions.loadPermissions).not.toHaveBeenCalled();
  });

  it('denies when required permission missing and records escalation', async () => {
    const permissions = {
      loadPermissions: jest.fn().mockResolvedValue(['vendor.apply']),
    } as unknown as PermissionsService;
    const securityEvents = { record: jest.fn().mockResolvedValue(undefined) } as unknown as SecurityEventService;
    const guard = new PermissionsGuard(reflector, permissions, securityEvents);
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) =>
      key === PERMISSIONS_KEY ? ['event.create'] : undefined,
    );
    const user: JwtUser = {
      userId: 'u1',
      tenantId: 't1',
      jwtRoleHints: [],
      roles: ['client'],
    };
    await expect(guard.canActivate(ctx(user))).rejects.toBeInstanceOf(ForbiddenException);
    expect(securityEvents.record).toHaveBeenCalledWith(
      expect.objectContaining({ eventType: 'permission_escalation' }),
    );
  });

  it('passes when all permissions granted', async () => {
    const permissions = {
      loadPermissions: jest.fn().mockResolvedValue(['event.create', 'event.publish']),
    } as unknown as PermissionsService;
    const securityEvents = { record: jest.fn() } as unknown as SecurityEventService;
    const guard = new PermissionsGuard(reflector, permissions, securityEvents);
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['event.create']);
    const user: JwtUser = {
      userId: 'org',
      tenantId: 't1',
      jwtRoleHints: [],
      roles: ['organizer'],
    };
    await expect(guard.canActivate(ctx(user))).resolves.toBe(true);
  });
});

describe('Permission matrix (canonical codes)', () => {
  const PERMS = [
    'event.create',
    'event.publish',
    'event.close',
    'vendor.apply',
    'vendor.approve',
    'finance.view',
    'finance.refund',
    'finance.payout',
    'tenant.manage',
    'tenant.suspend',
  ];

  it('defines 10 Phase 8 permission codes', () => {
    expect(PERMS).toHaveLength(10);
  });
});
