import { ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('supabase-jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  override async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      const req = context.switchToHttp().getRequest<{ headers?: { authorization?: string } }>();
      const auth = req.headers?.authorization;
      if (typeof auth === 'string' && auth.toLowerCase().startsWith('bearer ')) {
        return (await super.canActivate(context)) as boolean;
      }
      return true;
    }
    return (await super.canActivate(context)) as boolean;
  }
}
