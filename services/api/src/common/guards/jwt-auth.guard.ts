import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { DevAdminAuthService } from '../../auth/dev-admin-auth.service';
import { DevSuperAdminAuthService } from '../../auth/dev-super-admin-auth.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('supabase-jwt') {
  constructor(
    private readonly reflector: Reflector,
    private readonly devSuperAdminAuth: DevSuperAdminAuthService,
    private readonly devAdminAuth: DevAdminAuthService,
  ) {
    super();
  }

  override async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    const req = context.switchToHttp().getRequest<{ headers?: { authorization?: string }; user?: unknown }>();
    const auth = req.headers?.authorization;
    const hasBearer = typeof auth === 'string' && auth.toLowerCase().startsWith('bearer ');

    if (isPublic && !hasBearer) {
      return true;
    }

    if (hasBearer) {
      try {
        const ok = (await super.canActivate(context)) as boolean;
        if (ok) return true;
      } catch {
        // Fall through to dev admin auth.
      }
    }

    const devSuper = await this.devSuperAdminAuth.tryResolve(context);
    if (devSuper) {
      req.user = devSuper;
      return true;
    }

    const devUser = await this.devAdminAuth.tryResolve(context);
    if (devUser) {
      req.user = devUser;
      return true;
    }

    if (hasBearer) {
      return (await super.canActivate(context)) as boolean;
    }

    throw new UnauthorizedException({ code: 'AUTH_REQUIRED', message: 'Sign in required' });
  }
}
