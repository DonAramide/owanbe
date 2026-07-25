import { Global, Module } from '@nestjs/common';
import { EventsModule } from '../modules/events/events.module';
import { CommerceModule } from '../modules/commerce/commerce.module';
import { IntegrationsModeService } from './integrations-mode.service';
import { NotificationService } from './notifications/notification.service';
import { StorageService } from './storage/storage.service';
import { MediaController } from './storage/media.controller';
import { RealtimeBroadcastService } from './realtime/realtime-broadcast.service';
import { EventFeedStreamController } from './realtime/event-feed-sse.controller';
import { MetricsService } from './observability/metrics.service';
import { MetricsController } from './observability/metrics.controller';
import { HealthDetailService } from './observability/health-detail.service';
import { SupabaseAdminService } from './supabase/supabase-admin.service';
import { EmailSecretsCrypto } from './email-infrastructure/email-secrets.crypto';
import { EmailService } from './email-infrastructure/email.service';
import { EmailProviderAdminService } from './email-infrastructure/email-provider-admin.service';
import { SupabaseSmtpSyncService } from './email-infrastructure/supabase-smtp-sync.service';
import { EmailInfrastructureController } from './email-infrastructure/email-infrastructure.controller';

@Global()
@Module({
  imports: [EventsModule, CommerceModule],
  controllers: [
    MediaController,
    EventFeedStreamController,
    MetricsController,
    EmailInfrastructureController,
  ],
  providers: [
    IntegrationsModeService,
    EmailSecretsCrypto,
    EmailService,
    EmailProviderAdminService,
    SupabaseSmtpSyncService,
    NotificationService,
    StorageService,
    RealtimeBroadcastService,
    MetricsService,
    HealthDetailService,
    SupabaseAdminService,
  ],
  exports: [
    IntegrationsModeService,
    EmailService,
    EmailProviderAdminService,
    SupabaseSmtpSyncService,
    NotificationService,
    StorageService,
    RealtimeBroadcastService,
    MetricsService,
    HealthDetailService,
    SupabaseAdminService,
  ],
})
export class IntegrationsModule {}
