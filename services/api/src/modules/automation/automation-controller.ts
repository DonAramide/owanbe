import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import { AutomationEngineService } from './automation-engine.service';

@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class AutomationController {
  constructor(
    private readonly engine: AutomationEngineService,
    private readonly access: EventsAccessService,
  ) {}

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('organizers/me/automations')
  async list(@CommerceActorParam() actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(actor!.tenantId, actor!.userId, organizerId, 'automations.read');
    const items = await this.engine.listDefinitions(organizerId, actor!.tenantId);
    return { organizerId, items };
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('organizers/me/automations/runs')
  async runs(
    @CommerceActorParam() actor: CommerceActor,
    @Query('limit') limit?: string,
  ) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(actor!.tenantId, actor!.userId, organizerId, 'automations.read');
    return this.engine.listRuns(actor!.tenantId, organizerId, parseInt(limit ?? '50', 10) || 50);
  }

  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Post('organizers/me/automations/:workflowKey/enabled')
  async setEnabled(
    @CommerceActorParam() actor: CommerceActor,
    @Param('workflowKey') workflowKey: string,
    @Body() body: { enabled?: boolean },
  ) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(actor!.tenantId, actor!.userId, organizerId, 'automations.read');
    return this.engine.setOverride(
      actor!.tenantId,
      organizerId,
      workflowKey,
      body.enabled !== false,
    );
  }

  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('organizers/me/automations/jobs')
  async enqueue(
    @CommerceActorParam() actor: CommerceActor,
    @Body()
    body: {
      workflowKey?: string;
      runAt?: string;
      payload?: Record<string, unknown>;
      dedupeKey?: string;
    },
  ) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(actor!.tenantId, actor!.userId, organizerId, 'automations.read');
    const runAt = body.runAt ? new Date(body.runAt) : new Date(Date.now() + 60_000);
    await this.engine.enqueueJob({
      tenantId: actor!.tenantId,
      organizerId,
      workflowKey: body.workflowKey ?? 'notify_on_ticket_issued',
      runAt,
      payload: body.payload,
      dedupeKey: body.dedupeKey,
    });
    return { ok: true, runAt: runAt.toISOString() };
  }

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/automations/observability')
  async observability(@CommerceActorParam() actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(actor!.tenantId, actor!.userId, organizerId, 'automations.read');
    return this.engine.observabilitySnapshot(actor!.tenantId, organizerId);
  }
}
