import { Injectable } from '@nestjs/common';
import { EventEmitter } from 'events';

export interface FeedBroadcastEvent {
  tenantId: string;
  eventId: string;
  feedType: string;
  headline: string;
  detail: string;
  timestamp: string;
}

@Injectable()
export class RealtimeBroadcastService {
  private readonly bus = new EventEmitter();
  private readonly channelPrefix = 'event-feed:';

  subscribe(tenantId: string, eventDbId: string, listener: (evt: FeedBroadcastEvent) => void): () => void {
    const channel = this.channel(tenantId, eventDbId);
    const handler = (payload: FeedBroadcastEvent) => listener(payload);
    this.bus.on(channel, handler);
    return () => this.bus.off(channel, handler);
  }

  publish(payload: FeedBroadcastEvent): void {
    this.bus.emit(this.channel(payload.tenantId, payload.eventId), payload);
  }

  private channel(tenantId: string, eventDbId: string): string {
    return `${this.channelPrefix}${tenantId}:${eventDbId}`;
  }
}
