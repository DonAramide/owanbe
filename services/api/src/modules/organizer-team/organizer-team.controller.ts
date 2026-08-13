import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { OrganizerTeamService } from './organizer-team.service';

@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class OrganizerTeamController {
  constructor(private readonly team: OrganizerTeamService) {}

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('organizers/me/team')
  async list(
    @CommerceActorParam() actor: CommerceActor,
    @Query('q') q?: string,
    @Query('role') role?: string,
    @Query('status') status?: string,
  ) {
    return this.team.listMembers(actor!, { q, role, status });
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('organizers/me/team/activity')
  async activity(
    @CommerceActorParam() actor: CommerceActor,
    @Query('limit') limit?: string,
  ) {
    return this.team.listActivity(actor!, parseInt(limit ?? '50', 10) || 50);
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('organizers/me/membership')
  async membership(@CommerceActorParam() actor: CommerceActor) {
    return this.team.myMembership(actor!);
  }

  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @Post('organizers/me/team/invites')
  async invite(
    @CommerceActorParam() actor: CommerceActor,
    @Body() body: { email?: string; orgRole?: string },
  ) {
    return this.team.invite(actor!, { email: body.email ?? '', orgRole: body.orgRole });
  }

  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @Post('organizers/me/team/invites/accept')
  async accept(
    @CommerceActorParam() actor: CommerceActor,
    @Body() body: { token?: string },
  ) {
    return this.team.acceptInvite(actor!, body.token ?? '');
  }

  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Patch('organizers/me/team/members/:memberId/role')
  async updateRole(
    @CommerceActorParam() actor: CommerceActor,
    @Param('memberId') memberId: string,
    @Body() body: { orgRole?: string },
  ) {
    return this.team.updateRole(actor!, memberId, body.orgRole ?? 'staff');
  }

  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Post('organizers/me/team/members/:memberId/revoke')
  async revoke(
    @CommerceActorParam() actor: CommerceActor,
    @Param('memberId') memberId: string,
  ) {
    return this.team.removeMember(actor!, memberId);
  }
}
