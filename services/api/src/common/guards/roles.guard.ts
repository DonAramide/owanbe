import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';
import type { JwtUser, OwanbeRole } from '../types/jwt-user';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { RolesService } from '../../roles/roles.service';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly rolesService: RolesService,
  ) {}

  private assertAccountAllowsApi(user: JwtUser): void {
    const s = user.userStatus;
    if (s === 'suspended' || s === 'banned' || s === 'deleted') {
      throw new ForbiddenException({
        code: 'ACCOUNT_BLOCKED',
        message: 'Account is not permitted to use the API',
      });
    }
  }

  private async hydrateAndValidateJwtVsDb(user: JwtUser): Promise<void> {
    const principal = await this.rolesService.loadPrincipal(user.tenantId, user.userId);
    if (user.jwtRoleHints.length > 0) {
      for (const hint of user.jwtRoleHints) {
        if (!principal.roles.includes(hint)) {
          throw new ForbiddenException({
            code: 'JWT_ROLE_MISMATCH',
            message: `JWT claims role "${hint}" which is not granted in database`,
          });
        }
      }
    }
    user.roles = principal.roles;
    user.userStatus = principal.userStatus;
    this.assertAccountAllowsApi(user);
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    const req = context.switchToHttp().getRequest<{ user?: JwtUser }>();
    const user = req.user;

    if (isPublic) {
      if (user) {
        await this.hydrateAndValidateJwtVsDb(user);
      }
      return true;
    }

    const required = this.reflector.getAllAndOverride<OwanbeRole[] | undefined>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!required || required.length === 0) {
      if (user) {
        await this.hydrateAndValidateJwtVsDb(user);
      }
      return true;
    }

    if (!user) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Authentication required' });
    }

    await this.hydrateAndValidateJwtVsDb(user);

    const allowed = required.some((r) => user.roles.includes(r));
    if (!allowed) {
      throw new ForbiddenException({
        code: 'FORBIDDEN',
        message: `Requires one of roles: ${required.join(', ')}`,
      });
    }
    return true;
  }
}
