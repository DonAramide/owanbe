import { Injectable, Logger } from '@nestjs/common';
import { EventEmitter } from 'events';
import type { DomainEvent, DomainEventName, DomainEventPayload } from './domain-event.types';

type Handler = (event: DomainEvent) => void | Promise<void>;

/**
 * Thin in-process domain event bus (Phase 23).
 * Additive only — does not replace business workflows.
 */
@Injectable()
export class DomainEventsService {
  private readonly logger = new Logger(DomainEventsService.name);
  private readonly bus = new EventEmitter();

  constructor() {
    this.bus.setMaxListeners(50);
  }

  emit(name: DomainEventName | string, payload: DomainEventPayload): void {
    const event: DomainEvent = {
      name,
      payload: {
        ...payload,
        occurredAt: payload.occurredAt ?? new Date().toISOString(),
      },
    };
    setImmediate(() => {
      try {
        this.bus.emit(name, event);
        this.bus.emit('*', event);
      } catch (err) {
        this.logger.warn(`Domain event emit failed (${name}): ${(err as Error).message}`);
      }
    });
  }

  on(name: DomainEventName | string | '*', handler: Handler): void {
    this.bus.on(name, (event: DomainEvent) => {
      Promise.resolve(handler(event)).catch((err) => {
        this.logger.warn(`Domain event handler failed (${name}): ${(err as Error).message}`);
      });
    });
  }
}
