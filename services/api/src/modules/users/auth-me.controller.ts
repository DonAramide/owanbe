import { Controller, Get } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { UsersService } from './users.service';

@Controller('auth')
export class AuthMeController {
  constructor(private readonly users: UsersService) {}

  @Throttle({ default: { limit: 120, ttl: 60_000 }, strict: { limit: 40, ttl: 60_000 } })
  @Get('me')
  async me(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
  ): Promise<Awaited<ReturnType<UsersService['getMe']>>> {
    return this.users.getMe(tenantId, user.userId);
  }
}
