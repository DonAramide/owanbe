import { BadRequestException, Controller, Post, Req } from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
import { QuaserWebhookService } from './quaser-webhook.service';

@Controller('webhooks')
export class QuaserWebhookController {
  constructor(private readonly handler: QuaserWebhookService) {}

  @Public()
  @SkipTenant()
  @Throttle({ public: { limit: 2000, ttl: 60_000 } })
  @Post('quaser')
  async handleQuaser(@Req() req: RawBodyRequest<Request>) {
    const raw = req.rawBody;
    if (!raw || !Buffer.isBuffer(raw)) {
      throw new BadRequestException({
        code: 'RAW_BODY_REQUIRED',
        message: 'Server must be started with rawBody enabled for webhook verification',
      });
    }
    const sig = req.headers['x-quaser-signature'];
    const signature = typeof sig === 'string' ? sig : Array.isArray(sig) ? sig[0] : undefined;
    return this.handler.handleSignedWebhook(raw, signature);
  }
}
