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

@Global()
@Module({
  imports: [EventsModule, CommerceModule],
  controllers: [MediaController, EventFeedStreamController, MetricsController],
  providers: [
    IntegrationsModeService,
    NotificationService,
    StorageService,
    RealtimeBroadcastService,
    MetricsService,
    HealthDetailService,
  ],
  exports: [
    IntegrationsModeService,
    NotificationService,
    StorageService,
    RealtimeBroadcastService,
    MetricsService,
    HealthDetailService,
  ],
})
export class IntegrationsModule {}
