import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { CommerceAuthGuard } from '../../modules/commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../../modules/commerce/commerce-auth.service';
import { EventsAccessService } from '../../modules/events/events-access.service';
import { OutboundWebhookService } from './outbound-webhook.service';
import { IntegrationRegistryService } from './integration-registry.service';

/**
 * Organizer-scoped integration settings (outbound webhooks + connection status).
 */
@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class OrganizerIntegrationsController {
  constructor(
    private readonly webhooks: OutboundWebhookService,
    private readonly registry: IntegrationRegistryService,
    private readonly access: EventsAccessService,
  ) {}

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/integrations/status')
  async status(@CommerceActorParam() actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(
      actor!.tenantId,
      actor!.userId,
      organizerId,
      'integrations.manage',
    );
    const hub = await this.registry.listRegistry();
    const endpoints = await this.webhooks.listEndpoints({
      tenantId: actor!.tenantId,
      organizerId,
    });
    return {
      organizerId,
      providers: hub.items.filter((i) =>
        ['enterprise_email', 'twilio_sms', 'whatsapp_business', 'outbound_webhooks', 'quaser'].includes(
          i.key,
        ),
      ),
      webhooks: endpoints,
      mode: hub.mode,
    };
  }

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/integrations/webhooks')
  async listWebhooks(@CommerceActorParam() actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(
      actor!.tenantId,
      actor!.userId,
      organizerId,
      'integrations.manage',
    );
    return {
      organizerId,
      items: await this.webhooks.listEndpoints({
        tenantId: actor!.tenantId,
        organizerId,
      }),
    };
  }

  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('organizers/me/integrations/webhooks')
  async createWebhook(
    @CommerceActorParam() actor: CommerceActor,
    @Body()
    body: {
      targetUrl?: string;
      label?: string;
      subscribedTopics?: string[];
      maxAttempts?: number;
    },
  ) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(
      actor!.tenantId,
      actor!.userId,
      organizerId,
      'integrations.manage',
    );
    return this.webhooks.createEndpoint({
      tenantId: actor!.tenantId,
      organizerId,
      targetUrl: body.targetUrl ?? '',
      label: body.label,
      subscribedTopics: body.subscribedTopics ?? [],
      maxAttempts: body.maxAttempts,
    });
  }

  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Post('organizers/me/integrations/webhooks/:id/active')
  async setActive(
    @CommerceActorParam() actor: CommerceActor,
    @Param('id') id: string,
    @Body() body: { isActive?: boolean },
  ) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(
      actor!.tenantId,
      actor!.userId,
      organizerId,
      'integrations.manage',
    );
    return this.webhooks.setActive(id, body.isActive !== false, {
      tenantId: actor!.tenantId,
      organizerId,
    });
  }

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/integrations/webhooks/deliveries')
  async deliveries(
    @CommerceActorParam() actor: CommerceActor,
    @Query('limit') limit?: string,
  ) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(
      actor!.tenantId,
      actor!.userId,
      organizerId,
      'integrations.manage',
    );
    return this.webhooks.listDeliveries({
      tenantId: actor!.tenantId,
      organizerId,
      limit: parseInt(limit ?? '50', 10) || 50,
    });
  }
}
