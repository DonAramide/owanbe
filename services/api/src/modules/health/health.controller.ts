import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
import { HealthDetailService } from '../../integrations/observability/health-detail.service';

@Controller()
export class HealthController {
  constructor(private readonly healthDetail: HealthDetailService) {}

  @Public()
  @SkipThrottle()
  @SkipTenant()
  @Get('health')
  async health() {
    return this.healthDetail.getDetailedHealth();
  }
}
