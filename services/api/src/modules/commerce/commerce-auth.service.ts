import {
  BadRequestException,
  createParamDecorator,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import type { JwtUser } from '../../common/types/jwt-user';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface CommerceActor {
  userId: string;
  email?: string;
  tenantId: string;
}

@Injectable()
export class CommerceAuthService {
  async resolveActor(req: Request, jwtUser?: JwtUser): Promise<CommerceActor> {
    const tenantHeader = req.headers['x-tenant-id'];
    const tenantId = typeof tenantHeader === 'string' ? tenantHeader.trim() : jwtUser?.tenantId;
    if (!tenantId || !UUID_RE.test(tenantId)) {
      throw new BadRequestException({ code: 'TENANT_REQUIRED', message: 'X-Tenant-Id required' });
    }

    if (!jwtUser?.userId) {
      throw new UnauthorizedException({ code: 'AUTH_REQUIRED', message: 'Sign in required' });
    }

    if (jwtUser.tenantId !== tenantId) {
      throw new UnauthorizedException({ code: 'TENANT_MISMATCH', message: 'Token tenant mismatch' });
    }

    return { userId: jwtUser.userId, email: jwtUser.email, tenantId };
  }
}

export const CommerceActorParam = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): CommerceActor | undefined => {
    const req = ctx.switchToHttp().getRequest<Request & { commerceActor?: CommerceActor }>();
    return req.commerceActor;
  },
);
