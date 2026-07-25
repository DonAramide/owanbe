import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { WorkspaceService } from './workspace.service';
import { UsersService } from './users.service';
import {
  ActivateWorkspaceDto,
  EnsureUserDto,
  SaveWorkspaceOnboardingDto,
  SetActiveWorkspaceDto,
} from './dto/workspace.dto';
import { UpdateGlobalProfileDto } from './dto/update-global-profile.dto';
import type { WorkspaceCode } from './workspace.util';

@Controller('me')
export class WorkspaceController {
  constructor(
    private readonly workspaces: WorkspaceService,
    private readonly users: UsersService,
  ) {}

  @Post('ensure-user')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async ensureUser(@CurrentUser() user: JwtUser, @Body() dto: EnsureUserDto) {
    return this.workspaces.ensureUser(user, dto.displayName);
  }

  @Get('workspaces')
  async listWorkspaces(@CurrentUser() user: JwtUser) {
    await this.workspaces.ensureUser(user);
    return this.workspaces.listWorkspaces(user.tenantId, user.userId);
  }

  @Post('roles/activate')
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  async activateRole(@CurrentUser() user: JwtUser, @Body() dto: ActivateWorkspaceDto) {
    return this.workspaces.activateWorkspace(user, dto.workspace, dto.draft);
  }

  @Patch('roles/:workspace/onboarding')
  async saveOnboarding(
    @CurrentUser() user: JwtUser,
    @Param('workspace') workspace: WorkspaceCode,
    @Body() dto: SaveWorkspaceOnboardingDto,
  ) {
    return this.workspaces.saveOnboardingDraft(
      user,
      workspace,
      dto.draft ?? {},
      dto.step,
      dto.completionPct,
    );
  }

  @Post('active-workspace')
  async setActiveWorkspace(@CurrentUser() user: JwtUser, @Body() dto: SetActiveWorkspaceDto) {
    await this.workspaces.setActiveWorkspace(user, dto.workspace);
    return { workspace: dto.workspace };
  }

  /** Hub global profile — additive; does not touch workspace profile tables. */
  @Patch('profile')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async updateGlobalProfile(@CurrentUser() user: JwtUser, @Body() dto: UpdateGlobalProfileDto) {
    return this.users.updateGlobalProfile(user.tenantId, user.userId, dto);
  }
}
