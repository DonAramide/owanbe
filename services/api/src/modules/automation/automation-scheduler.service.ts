import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { DomainEventsService } from '../domain-events/domain-events.service';
import { DOMAIN_EVENTS } from '../domain-events/domain-event.types';
import { AutomationEngineService } from './automation-engine.service';

/**
 * Durable due-job sweeper (Phase 23).
 * Emits schedule.tick periodically — no Bull/Redis.
 */
@Injectable()
export class AutomationSchedulerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AutomationSchedulerService.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly events: DomainEventsService,
    private readonly engine: AutomationEngineService,
  ) {}

  onModuleInit() {
    this.engine.startListening();
    // Every 60s — process due automation_jobs
    this.timer = setInterval(() => {
      this.events.emit(DOMAIN_EVENTS.SCHEDULE_TICK, {
        tenantId: '00000000-0000-4000-8000-000000000000',
        data: { source: 'automation_scheduler' },
      });
      void this.engine.processDueJobs().catch((err) => {
        this.logger.warn(`Due-job sweep failed: ${(err as Error).message}`);
      });
    }, 60_000);
    this.logger.log('Automation due-job sweeper started (60s)');
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }
}
