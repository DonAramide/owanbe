import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from './permissions.decorator';
import type { OwanbePermission } from './permissions.constants';
import { PermissionsService } from './permissions.service';
import type { JwtUser } from '../common/types/jwt-user';
import { SecurityEventService } from '../security/security-event.service';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly permissions: PermissionsService,
    private readonly securityEvents: SecurityEventService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<OwanbePermission[] | undefined>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!required || required.length === 0) return true;

    const req = context.switchToHttp().getRequest<{ user?: JwtUser }>();
    const user = req.user;
    if (!user) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Authentication required' });
    }

    if (user.roles.includes('super_admin')) return true;

    const granted = await this.permissions.loadPermissions(user.tenantId, user.userId);
    user.permissions = granted;

    const missing = required.filter((p) => !granted.includes(p));
    if (missing.length > 0) {
      await this.securityEvents.record({
        eventType: 'permission_escalation',
        severity: 'warning',
        tenantId: user.tenantId,
        actorUserId: user.userId,
        details: { required, granted, missing },
      });
      throw new ForbiddenException({
        code: 'PERMISSION_DENIED',
        message: `Missing permissions: ${missing.join(', ')}`,
      });
    }
    return true;
  }
}
