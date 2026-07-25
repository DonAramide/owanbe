import { Body, Controller, GoneException, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { ADMIN_APPROVERS } from '../../common/permission-matrix';
import { AuthSignupService } from './auth-signup.service';
import { WorkspaceService } from './workspace.service';
import { CompleteOnboardingDto } from './dto/auth-signup.dto';
import { EnsureUserDto } from './dto/workspace.dto';

const PORTAL_AUTH_RETIRED = {
  code: 'PORTAL_AUTH_RETIRED',
  message:
    'Portal-first authentication is retired. Use POST /auth/ensure-user and POST /me/roles/activate (Owanbe 2.0 Universal Identity).',
} as const;

@Controller('auth')
export class AuthSignupController {
  constructor(
    private readonly signup: AuthSignupService,
    private readonly workspaces: WorkspaceService,
  ) {}

  @Post('ensure-user')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async ensureUser(@CurrentUser() user: JwtUser, @Body() dto: EnsureUserDto) {
    return this.workspaces.ensureUser(user, dto.displayName);
  }

  @Post('complete-signup')
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  async completeSignup() {
    throw new GoneException(PORTAL_AUTH_RETIRED);
  }

  @Post('validate-portal')
  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  async validatePortal() {
    throw new GoneException(PORTAL_AUTH_RETIRED);
  }

  @Post('complete-onboarding')
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  async completeOnboarding(@CurrentUser() user: JwtUser, @Body() dto: CompleteOnboardingDto) {
    return this.signup.completeOnboarding(user, dto);
  }

  @Public()
  @Post('portal-lookup')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async portalLookup() {
    throw new GoneException(PORTAL_AUTH_RETIRED);
  }
}

@Controller('admin')
export class AdminUserPortalController {
  constructor(private readonly signup: AuthSignupService) {}

  @Roles(...ADMIN_APPROVERS)
  @Post('users/migrate-portal')
  @Throttle({ strict: { limit: 10, ttl: 60_000 } })
  async migratePortal() {
    throw new GoneException(PORTAL_AUTH_RETIRED);
  }
}
