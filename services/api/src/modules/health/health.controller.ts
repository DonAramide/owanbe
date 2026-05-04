import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';

@Controller()
export class HealthController {
  @Public()
  @SkipThrottle()
  @SkipTenant()
  @Get('health')
  health() {
    return { status: 'ok' };
  }
}
