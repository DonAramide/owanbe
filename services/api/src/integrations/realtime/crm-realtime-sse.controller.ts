import {
  Controller,
  Get,
  Logger,
  Res,
  ServiceUnavailableException,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { CommerceAuthGuard } from '../../modules/commerce/commerce-auth.guard';
import {
  CommerceActorParam,
  type CommerceActor,
} from '../../modules/commerce/commerce-auth.service';
import { MetricsService } from '../observability/metrics.service';
import { CrmRealtimeBroadcastService } from './crm-realtime-broadcast.service';
import { crmUserChannel } from './crm-realtime.types';

/**
 * Phase 3A — user-centric CRM SSE.
 * GET /v1/me/crm/stream
 *
 * Auth: commerce JWT via CommerceAuthGuard (same stack as Event Ops SSE).
 * Room: crm:{tenantId}:user:{userId} derived from JWT — client never supplies vendor/organizer ids.
 */
@Controller('me')
export class CrmRealtimeSseController {
  private readonly logger = new Logger(CrmRealtimeSseController.name);

  constructor(
    private readonly broadcast: CrmRealtimeBroadcastService,
    private readonly metrics: MetricsService,
  ) {}

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('crm/stream')
  stream(
    @CommerceActorParam() actor: CommerceActor,
    @Res() res: Response,
  ): void {
    if (!this.broadcast.isEnabled()) {
      this.metrics.inc('crm_sse_subscription_denied', { reason: 'disabled' });
      throw new ServiceUnavailableException({
        code: 'CRM_REALTIME_DISABLED',
        message: 'CRM realtime SSE is disabled',
      });
    }

    if (!actor?.tenantId || !actor?.userId) {
      this.metrics.inc('crm_sse_auth_fail', {});
      this.logger.warn(JSON.stringify({ metric: 'crm_sse_auth_fail' }));
      res.status(401).json({ code: 'UNAUTHORIZED', message: 'Authentication required' });
      return;
    }

    const channel = crmUserChannel(actor.tenantId, actor.userId);
    this.metrics.inc('crm_sse_connect', {});
    this.logger.log(
      JSON.stringify({
        metric: 'crm_sse_connect',
        tenantId: actor.tenantId,
        userId: actor.userId,
        channel,
        fanout: this.broadcast.fanout(),
      }),
    );

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();

    const send = (data: unknown) => {
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };

    send({
      type: 'connected',
      channel,
      timestamp: new Date().toISOString(),
    });

    const unsubscribe = this.broadcast.subscribe(actor.tenantId, actor.userId, (evt) => {
      try {
        send(evt);
        this.metrics.inc('crm_realtime_deliver', { transport: 'sse' });
      } catch (err) {
        this.metrics.inc('crm_realtime_deliver_fail', { transport: 'sse' });
        this.logger.warn(
          `crm_realtime_deliver_fail sse eventId=${evt.eventId}: ${(err as Error).message}`,
        );
      }
    });

    const heartbeat = setInterval(() => {
      res.write(': ping\n\n');
    }, 25_000);

    res.on('close', () => {
      clearInterval(heartbeat);
      unsubscribe();
      this.metrics.inc('crm_sse_disconnect', {});
      this.logger.log(
        JSON.stringify({
          metric: 'crm_sse_disconnect',
          tenantId: actor.tenantId,
          userId: actor.userId,
        }),
      );
    });
  }
}
