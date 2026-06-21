import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { SecurityEventService } from '../../security/security-event.service';

@Injectable()
export class JwtAuthGuard extends AuthGuard('supabase-jwt') {
  constructor(
    private readonly reflector: Reflector,
    private readonly securityEvents: SecurityEventService,
  ) {
    super();
  }

  override async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    const req = context.switchToHttp().getRequest<{
      headers?: { authorization?: string; 'x-tenant-id'?: string };
      user?: unknown;
    }>();
    const auth = req.headers?.authorization;
    const hasBearer = typeof auth === 'string' && auth.toLowerCase().startsWith('bearer ');

    if (isPublic && !hasBearer) {
      return true;
    }

    if (!hasBearer) {
      throw new UnauthorizedException({ code: 'AUTH_REQUIRED', message: 'Bearer token required' });
    }

    try {
      return (await super.canActivate(context)) as boolean;
    } catch (err) {
      await this.securityEvents.record({
        eventType: 'failed_login',
        severity: 'warning',
        details: {
          reason: err instanceof Error ? err.message : 'invalid_token',
          path: context.switchToHttp().getRequest<{ url?: string }>().url,
        },
      });
      throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'Invalid or expired token' });
    }
  }
}
