import {
  ExecutionContext,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerLimitDetail, ThrottlerModuleOptions, ThrottlerStorage } from '@nestjs/throttler';
import type { Request } from 'express';
import type { JwtUser } from '../types/jwt-user';
import { SecurityEventService } from '../../security/security-event.service';

@Injectable()
export class OwanbeThrottlerGuard extends ThrottlerGuard {
  constructor(
    options: ThrottlerModuleOptions,
    storageService: ThrottlerStorage,
    reflector: Reflector,
    private readonly securityEvents: SecurityEventService,
  ) {
    super(options, storageService, reflector);
  }

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

  protected override async throwThrottlingException(
    context: ExecutionContext,
    throttlerLimitDetail: ThrottlerLimitDetail,
  ): Promise<void> {
    const req = context.switchToHttp().getRequest<Record<string, unknown>>();
    const user = req['user'] as JwtUser | undefined;
    const r = req as unknown as Request;
    await this.securityEvents.record({
      eventType: 'rate_limit_violation',
      severity: 'warning',
      tenantId: user?.tenantId,
      actorUserId: user?.userId,
      details: {
        path: r.url,
        ip: r.ip ?? r.socket?.remoteAddress,
        limit: throttlerLimitDetail.limit,
        ttl: throttlerLimitDetail.ttl,
      },
    });
    return super.throwThrottlingException(context, throttlerLimitDetail);
  }
}
