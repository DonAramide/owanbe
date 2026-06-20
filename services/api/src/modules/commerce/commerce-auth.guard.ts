import {
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';
import type { Request } from 'express';
import { CommerceAuthService } from './commerce-auth.service';
import type { JwtUser } from '../../common/types/jwt-user';

@Injectable()
export class CommerceAuthGuard implements CanActivate {
  constructor(private readonly auth: CommerceAuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request & { user?: JwtUser; commerceActor?: unknown }>();
    req.commerceActor = await this.auth.resolveActor(req, req.user);
    return true;
  }
}
