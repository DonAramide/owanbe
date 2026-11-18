import { BadRequestException, Controller, Param, Post, Req } from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
import { QuasarWebhookService } from './quasar-webhook.service';

@Controller('webhooks/quasar')
export class QuasarWebhookController {
  constructor(private readonly handler: QuasarWebhookService) {}

  @Public()
  @SkipTenant()
  @Throttle({ public: { limit: 2000, ttl: 60_000 } })
  @Post(':quasarTenantId')
  async handle(
    @Param('quasarTenantId') quasarTenantId: string,
    @Req() req: RawBodyRequest<Request>,
  ) {
    const raw = req.rawBody;
    if (!raw || !Buffer.isBuffer(raw)) {
      throw new BadRequestException({
        code: 'RAW_BODY_REQUIRED',
        message: 'Server must be started with rawBody enabled for webhook verification',
      });
    }
    const sig = req.headers['x-quasar-signature'];
    const signature = typeof sig === 'string' ? sig : Array.isArray(sig) ? sig[0] : undefined;
    return this.handler.handleSignedWebhook(quasarTenantId, raw, signature);
  }
}
