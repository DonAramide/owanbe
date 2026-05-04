import { ExecutionContext, Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import type { Request } from 'express';
import type { JwtUser } from '../types/jwt-user';

@Injectable()
export class OwanbeThrottlerGuard extends ThrottlerGuard {
  protected override async getTracker(req: Record<string, unknown>): Promise<string> {
    const user = req['user'] as JwtUser | undefined;
    const tenant =
      user?.tenantId ?? (req['catalogTenantId'] as string | undefined) ?? 'anon';
    const r = req as unknown as Request;
    const ip = r.ip ?? r.socket?.remoteAddress ?? 'na';
    return `${tenant}:${ip}`;
  }

  protected override generateKey(
    context: ExecutionContext,
    suffix: string,
    name: string,
  ): string {
    const base = super.generateKey(context, suffix, name);
    const req = context.switchToHttp().getRequest<Record<string, unknown>>();
    const user = req['user'] as JwtUser | undefined;
    const tenant =
      user?.tenantId ?? (req['catalogTenantId'] as string | undefined) ?? 'anon';
    return `${tenant}:${name}:${base}`;
  }
}
