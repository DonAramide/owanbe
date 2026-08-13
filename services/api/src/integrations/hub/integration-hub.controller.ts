import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { SUPER_ADMIN_ROLES } from '../../common/permission-matrix';
import { IntegrationRegistryService } from './integration-registry.service';
import { OutboundWebhookService } from './outbound-webhook.service';
import { MessagingProvidersService } from './messaging-providers.service';
import { NotificationService } from '../notifications/notification.service';

@Controller('super-admin/integrations')
@SkipTenant()
@Roles(...SUPER_ADMIN_ROLES)
export class IntegrationHubController {
  constructor(
    private readonly registry: IntegrationRegistryService,
    private readonly webhooks: OutboundWebhookService,
    private readonly messaging: MessagingProvidersService,
    private readonly notifications: NotificationService,
  ) {}

  @Get('registry')
  listRegistry() {
    return this.registry.listRegistry();
  }

  @Get('observability')
  async observability() {
    const [webhooks, notifications] = await Promise.all([
      this.webhooks.observabilitySnapshot(),
      this.notifications.deliveryObservability(30),
    ]);
    return { webhooks, notifications };
  }

  @Get('deliveries')
  listDeliveries(@Query('limit') limit?: string) {
    return this.registry.listRecentDeliveries(parseInt(limit ?? '50', 10) || 50);
  }

  @Get('webhooks')
  listWebhooks() {
    return this.webhooks.listEndpoints({});
  }

  @Post('webhooks')
  createWebhook(
    @Body()
    body: {
      targetUrl?: string;
      label?: string;
      subscribedTopics?: string[];
      clientId?: string;
      maxAttempts?: number;
      tenantId?: string;
      organizerId?: string;
    },
  ) {
    return this.webhooks.createEndpoint({
      targetUrl: body.targetUrl ?? '',
      label: body.label,
      subscribedTopics: body.subscribedTopics ?? [],
      clientId: body.clientId,
      maxAttempts: body.maxAttempts,
      tenantId: body.tenantId,
      organizerId: body.organizerId,
    });
  }

  @Post('webhooks/:id/active')
  setWebhookActive(@Param('id') id: string, @Body() body: { isActive?: boolean }) {
    return this.webhooks.setActive(id, body.isActive !== false);
  }

  @Post('webhooks/:id/rotate-secret')
  rotateSecret(@Param('id') id: string) {
    return this.webhooks.rotateSecret(id);
  }

  @Get('webhooks/deliveries')
  webhookDeliveries(
    @Query('webhookId') webhookId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.webhooks.listDeliveries({
      webhookId,
      limit: parseInt(limit ?? '50', 10) || 50,
    });
  }

  @Post('webhooks/process-due')
  processDue() {
    return this.webhooks.processDueDeliveries(50);
  }

  @Get('messaging')
  listMessaging(@Query('channel') channel?: 'sms' | 'whatsapp') {
    return this.messaging.list(channel);
  }

  @Post('messaging')
  createMessaging(
    @CurrentUser() user: JwtUser,
    @Body()
    body: {
      channel: 'sms' | 'whatsapp';
      providerType?: string;
      name: string;
      fromAddress?: string;
      tenantId?: string;
      secrets?: {
        accountSid?: string;
        authToken?: string;
        apiKey?: string;
        apiSecret?: string;
      };
      config?: Record<string, unknown>;
      setDefault?: boolean;
    },
  ) {
    return this.messaging.create({
      actorUserId: user.userId,
      channel: body.channel,
      providerType: body.providerType,
      name: body.name,
      fromAddress: body.fromAddress,
      tenantId: body.tenantId,
      secrets: body.secrets,
      config: body.config,
      setDefault: body.setDefault,
    });
  }

  @Patch('messaging/:id')
  updateMessaging(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Body()
    body: {
      name?: string;
      enabled?: boolean;
      fromAddress?: string;
      secrets?: {
        accountSid?: string;
        authToken?: string;
        apiKey?: string;
        apiSecret?: string;
      };
      config?: Record<string, unknown>;
    },
  ) {
    return this.messaging.update(id, user.userId, body);
  }

  @Post('messaging/:id/set-default')
  setDefaultMessaging(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    return this.messaging.setDefault(id, user.userId);
  }
}
