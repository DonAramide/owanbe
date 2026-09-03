import {
  Inject,
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter } from 'events';
import { randomUUID } from 'crypto';
import type { Pool, PoolClient } from 'pg';
import type { EnvVars } from '../../config/env.schema';
import { PG_POOL } from '../../database/database.tokens';
import { MetricsService } from '../observability/metrics.service';
import {
  crmUserChannel,
  type CrmRealtimeEnvelope,
} from './crm-realtime.types';

const PG_CHANNEL = 'crm_realtime';

type FanoutPayload = CrmRealtimeEnvelope & { _source?: string };

/**
 * Phase 3A CRM realtime fan-out.
 * - Local: EventEmitter (dev / single instance)
 * - Multi-instance: PostgreSQL LISTEN/NOTIFY (no Redis required)
 *
 * Redis is not present in this codebase; PG NOTIFY is the production foundation.
 */
@Injectable()
export class CrmRealtimeBroadcastService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(CrmRealtimeBroadcastService.name);
  private readonly bus = new EventEmitter();
  private readonly instanceId = randomUUID();
  private listenClient: PoolClient | null = null;
  private enabled = false;
  private fanoutMode: 'local' | 'pg_notify' = 'local';

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly metrics: MetricsService,
  ) {
    this.bus.setMaxListeners(200);
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  fanout(): string {
    return this.fanoutMode;
  }

  async onModuleInit(): Promise<void> {
    this.enabled = Boolean(this.config.get('CRM_REALTIME_SSE'));
    const configured = (this.config.get('CRM_REALTIME_FANOUT') ?? 'pg_notify') as string;
    this.fanoutMode =
      configured === 'local' || !this.enabled ? 'local' : 'pg_notify';

    if (!this.enabled) {
      this.logger.log('crm_realtime disabled (CRM_REALTIME_SSE=false)');
      return;
    }

    this.logger.log(
      `crm_realtime enabled fanout=${this.fanoutMode} instance=${this.instanceId.slice(0, 8)}`,
    );

    if (this.fanoutMode === 'pg_notify') {
      await this.startPgListener();
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.listenClient) {
      try {
        await this.listenClient.query(`UNLISTEN ${PG_CHANNEL}`);
      } catch {
        /* ignore */
      }
      this.listenClient.release();
      this.listenClient = null;
    }
  }

  /** Subscribe an SSE connection to the authenticated user's CRM room only. */
  subscribe(
    tenantId: string,
    userId: string,
    listener: (evt: CrmRealtimeEnvelope) => void,
  ): () => void {
    const channel = crmUserChannel(tenantId, userId);
    const wrapped = (evt: CrmRealtimeEnvelope) => {
      if (evt.tenantId !== tenantId) return;
      listener(evt);
    };
    this.bus.on(channel, wrapped);
    return () => this.bus.off(channel, wrapped);
  }

  /**
   * Publish after successful CRM persistence. Never throws to callers —
   * delivery failure must not roll back business state.
   */
  publishToUser(
    recipientUserId: string,
    envelope: Omit<CrmRealtimeEnvelope, 'eventId' | 'occurredAt'> & {
      eventId?: string;
      occurredAt?: string;
    },
  ): void {
    if (!this.enabled) return;
    if (!recipientUserId) return;

    const full: FanoutPayload = {
      eventId: envelope.eventId ?? randomUUID(),
      type: envelope.type,
      tenantId: envelope.tenantId,
      resource: envelope.resource,
      revision: envelope.revision ?? envelope.updatedAt,
      updatedAt: envelope.updatedAt,
      dedupeKey: envelope.dedupeKey,
      occurredAt: envelope.occurredAt ?? new Date().toISOString(),
      meta: envelope.meta,
      _source: this.instanceId,
    };

    this.metrics.inc('crm_realtime_emit', {
      type: String(full.type),
      fanout: this.fanoutMode,
    });
    this.logger.log(
      JSON.stringify({
        metric: 'crm_realtime_emit',
        eventId: full.eventId,
        type: full.type,
        tenantId: full.tenantId,
        requestId: full.resource.id,
        recipientUserId,
        dedupeKey: full.dedupeKey,
      }),
    );

    try {
      this.deliverLocal(recipientUserId, full);
    } catch (err) {
      this.metrics.inc('crm_realtime_deliver_fail', { phase: 'local' });
      this.logger.warn(
        `crm_realtime_deliver_fail local eventId=${full.eventId}: ${(err as Error).message}`,
      );
    }

    if (this.fanoutMode === 'pg_notify') {
      void this.pgNotify(recipientUserId, full);
    }
  }

  private deliverLocal(recipientUserId: string, payload: FanoutPayload): void {
    const { _source: _ignored, ...clientSafe } = payload;
    const channel = crmUserChannel(clientSafe.tenantId, recipientUserId);
    this.bus.emit(channel, clientSafe as CrmRealtimeEnvelope);
    this.metrics.inc('crm_realtime_deliver', { fanout: 'local' });
  }

  private async pgNotify(recipientUserId: string, payload: FanoutPayload): Promise<void> {
    try {
      const wire = JSON.stringify({
        recipientUserId,
        envelope: payload,
      });
      // NOTIFY payload limit ~8KB — envelopes are intentionally small.
      if (wire.length > 7500) {
        this.logger.warn(
          `crm_realtime_deliver_fail payload_too_large eventId=${payload.eventId} len=${wire.length}`,
        );
        this.metrics.inc('crm_realtime_deliver_fail', { phase: 'pg_size' });
        return;
      }
      await this.pool.query(`SELECT pg_notify($1, $2)`, [PG_CHANNEL, wire]);
    } catch (err) {
      this.metrics.inc('crm_realtime_deliver_fail', { phase: 'pg_notify' });
      this.logger.warn(
        `crm_realtime_deliver_fail pg_notify eventId=${payload.eventId}: ${(err as Error).message}`,
      );
    }
  }

  private async startPgListener(): Promise<void> {
    try {
      this.listenClient = await this.pool.connect();
      await this.listenClient.query(`LISTEN ${PG_CHANNEL}`);
      this.listenClient.on('notification', (msg) => {
        if (msg.channel !== PG_CHANNEL || !msg.payload) return;
        try {
          const parsed = JSON.parse(msg.payload) as {
            recipientUserId: string;
            envelope: FanoutPayload;
          };
          const env = parsed.envelope;
          if (!env || !parsed.recipientUserId) return;
          if (env._source === this.instanceId) return; // already delivered locally
          this.deliverLocal(parsed.recipientUserId, env);
        } catch (err) {
          this.metrics.inc('crm_realtime_deliver_fail', { phase: 'pg_listen_parse' });
          this.logger.warn(`crm_realtime_deliver_fail listen_parse: ${(err as Error).message}`);
        }
      });
      this.listenClient.on('error', (err) => {
        this.logger.warn(`crm_realtime listen client error: ${err.message}`);
      });
    } catch (err) {
      this.logger.warn(
        `crm_realtime pg_notify fan-out unavailable; falling back to local-only: ${(err as Error).message}`,
      );
      this.fanoutMode = 'local';
      if (this.listenClient) {
        this.listenClient.release();
        this.listenClient = null;
      }
    }
  }
}
