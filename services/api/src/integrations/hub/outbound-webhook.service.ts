import { createHmac, randomBytes, timingSafeEqual } from 'crypto';
import {
  Injectable,
  Inject,
  Logger,
  NotFoundException,
  BadRequestException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { DomainEventsService } from '../../modules/domain-events/domain-events.service';
import type { DomainEvent } from '../../modules/domain-events/domain-event.types';
import { DOMAIN_EVENTS } from '../../modules/domain-events/domain-event.types';
import { EmailSecretsCrypto } from '../email-infrastructure/email-secrets.crypto';
import { MetricsService } from '../observability/metrics.service';

const WEBHOOKABLE_TOPICS = new Set<string>([
  DOMAIN_EVENTS.TICKET_ISSUED,
  DOMAIN_EVENTS.RSVP_CHANGED,
  DOMAIN_EVENTS.VENDOR_STAGE_CHANGED,
  DOMAIN_EVENTS.REFUND_COMPLETED,
  DOMAIN_EVENTS.REPORT_GENERATED,
]);

/**
 * Phase 24/25 — Signed outbound webhook delivery with retry + dead-letter.
 * Secrets encrypted at rest (Phase 25).
 */
@Injectable()
export class OutboundWebhookService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OutboundWebhookService.name);
  private timer: NodeJS.Timeout | null = null;
  private listening = false;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly events: DomainEventsService,
    private readonly crypto: EmailSecretsCrypto,
    private readonly metrics: MetricsService,
  ) {}

  onModuleInit() {
    if (!this.listening) {
      this.events.on('*', (event) => this.enqueueFromDomainEvent(event));
      this.listening = true;
    }
    this.timer = setInterval(() => {
      void this.processDueDeliveries().catch((err) => {
        this.logger.warn(`Webhook sweep failed: ${(err as Error).message}`);
      });
    }, 30_000);
    this.logger.log('Outbound webhook sweeper started (30s)');
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async listEndpoints(params: { tenantId?: string | null; organizerId?: string | null }) {
    const { rows } = await this.pool.query(
      `SELECT id, client_id, target_url, subscribed_topics, is_active, label,
              tenant_id, organizer_id, max_attempts, created_at, updated_at,
              CASE WHEN (secrets_ciphertext IS NOT NULL AND length(secrets_ciphertext) > 0)
                     OR (secret_key IS NOT NULL AND length(secret_key) > 0)
                   THEN true ELSE false END AS has_secret
       FROM platform_webhooks
       WHERE ($1::uuid IS NULL OR tenant_id IS NULL OR tenant_id = $1::uuid)
         AND ($2::uuid IS NULL OR organizer_id IS NULL OR organizer_id = $2::uuid)
       ORDER BY created_at DESC`,
      [params.tenantId ?? null, params.organizerId ?? null],
    );
    return rows.map((r) => ({
      id: r.id,
      clientId: r.client_id,
      targetUrl: r.target_url,
      subscribedTopics: r.subscribed_topics ?? [],
      isActive: r.is_active,
      label: r.label,
      tenantId: r.tenant_id,
      organizerId: r.organizer_id,
      maxAttempts: r.max_attempts,
      hasSecret: r.has_secret,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
  }

  async createEndpoint(input: {
    tenantId?: string | null;
    organizerId?: string | null;
    targetUrl: string;
    label?: string;
    subscribedTopics: string[];
    clientId?: string;
    maxAttempts?: number;
  }) {
    const url = (input.targetUrl ?? '').trim();
    if (!url.startsWith('https://') && !url.startsWith('http://localhost')) {
      throw new BadRequestException('targetUrl must be https:// (or http://localhost for dev)');
    }
    const topics = (input.subscribedTopics ?? []).filter((t) => WEBHOOKABLE_TOPICS.has(t));
    if (!topics.length) {
      throw new BadRequestException(
        `subscribedTopics must include one of: ${[...WEBHOOKABLE_TOPICS].join(', ')}`,
      );
    }
    const secret = `whsec_${randomBytes(24).toString('hex')}`;
    const ciphertext = this.crypto.encrypt(secret);
    const clientId = (input.clientId ?? `org_${(input.organizerId ?? 'platform').slice(0, 8)}`).slice(0, 64);
    const { rows } = await this.pool.query(
      `INSERT INTO platform_webhooks
         (client_id, target_url, secret_key, secrets_ciphertext, subscribed_topics, is_active, label, tenant_id, organizer_id, max_attempts)
       VALUES ($1, $2, '', $3, $4::text[], true, $5, $6::uuid, $7::uuid, $8)
       RETURNING id`,
      [
        clientId,
        url,
        ciphertext,
        topics,
        input.label ?? null,
        input.tenantId ?? null,
        input.organizerId ?? null,
        Math.min(10, Math.max(1, input.maxAttempts ?? 5)),
      ],
    );
    return {
      id: rows[0].id,
      clientId,
      targetUrl: url,
      subscribedTopics: topics,
      secret, // shown once
      maxAttempts: input.maxAttempts ?? 5,
    };
  }

  async setActive(id: string, isActive: boolean, scope?: { tenantId?: string; organizerId?: string }) {
    const { rowCount } = await this.pool.query(
      `UPDATE platform_webhooks
       SET is_active = $2, updated_at = now()
       WHERE id = $1::uuid
         AND ($3::uuid IS NULL OR tenant_id IS NULL OR tenant_id = $3::uuid)
         AND ($4::uuid IS NULL OR organizer_id IS NULL OR organizer_id = $4::uuid)`,
      [id, isActive, scope?.tenantId ?? null, scope?.organizerId ?? null],
    );
    if (!rowCount) throw new NotFoundException('Webhook endpoint not found');
    return { ok: true, id, isActive };
  }

  async rotateSecret(id: string, scope?: { tenantId?: string; organizerId?: string }) {
    const secret = `whsec_${randomBytes(24).toString('hex')}`;
    const ciphertext = this.crypto.encrypt(secret);
    const { rowCount } = await this.pool.query(
      `UPDATE platform_webhooks
       SET secret_key = '', secrets_ciphertext = $2, updated_at = now()
       WHERE id = $1::uuid
         AND ($3::uuid IS NULL OR tenant_id IS NULL OR tenant_id = $3::uuid)
         AND ($4::uuid IS NULL OR organizer_id IS NULL OR organizer_id = $4::uuid)`,
      [id, ciphertext, scope?.tenantId ?? null, scope?.organizerId ?? null],
    );
    if (!rowCount) throw new NotFoundException('Webhook endpoint not found');
    return { id, secret };
  }

  async listDeliveries(params: {
    webhookId?: string;
    tenantId?: string | null;
    organizerId?: string | null;
    limit?: number;
  }) {
    const limit = Math.min(100, Math.max(1, params.limit ?? 50));
    const { rows } = await this.pool.query(
      `SELECT d.id, d.webhook_id, d.topic, d.status, d.attempts, d.max_attempts,
              d.last_status_code, d.last_error, d.next_attempt_at, d.created_at, d.completed_at,
              w.target_url, w.label
       FROM platform_webhook_deliveries d
       INNER JOIN platform_webhooks w ON w.id = d.webhook_id
       WHERE ($1::uuid IS NULL OR d.webhook_id = $1::uuid)
         AND ($2::uuid IS NULL OR d.tenant_id IS NULL OR d.tenant_id = $2::uuid)
         AND ($3::uuid IS NULL OR d.organizer_id IS NULL OR d.organizer_id = $3::uuid)
       ORDER BY d.created_at DESC
       LIMIT $4`,
      [params.webhookId ?? null, params.tenantId ?? null, params.organizerId ?? null, limit],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        webhookId: r.webhook_id,
        topic: r.topic,
        status: r.status,
        attempts: r.attempts,
        maxAttempts: r.max_attempts,
        lastStatusCode: r.last_status_code,
        lastError: r.last_error,
        nextAttemptAt: r.next_attempt_at,
        targetUrl: r.target_url,
        label: r.label,
        createdAt: r.created_at,
        completedAt: r.completed_at,
      })),
    };
  }

  async enqueueFromDomainEvent(event: DomainEvent): Promise<void> {
    const topic = event.name;
    if (!WEBHOOKABLE_TOPICS.has(topic)) return;
    const tenantId = event.payload.tenantId;
    const organizerId = event.payload.organizerId ?? null;

    const { rows: hooks } = await this.pool.query<{
      id: string;
      max_attempts: number;
      subscribed_topics: string[];
    }>(
      `SELECT id, max_attempts, subscribed_topics
       FROM platform_webhooks
       WHERE is_active = true
         AND ($1::uuid IS NULL OR tenant_id IS NULL OR tenant_id = $1::uuid)
         AND ($2::uuid IS NULL OR organizer_id IS NULL OR organizer_id = $2::uuid)
         AND $3 = ANY(subscribed_topics)`,
      [tenantId, organizerId, topic],
    );

    if (!hooks.length) return;

    const payload = {
      topic,
      tenantId,
      organizerId,
      eventId: event.payload.eventId ?? null,
      entityId: event.payload.entityId ?? null,
      occurredAt: event.payload.occurredAt ?? new Date().toISOString(),
      data: event.payload.data ?? {},
    };

    for (const h of hooks) {
      await this.pool.query(
        `INSERT INTO platform_webhook_deliveries
           (webhook_id, tenant_id, organizer_id, topic, payload, status, max_attempts, next_attempt_at)
         VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5::jsonb, 'pending', $6, now())`,
        [h.id, tenantId, organizerId, topic, JSON.stringify(payload), h.max_attempts ?? 5],
      );
    }
  }

  async processDueDeliveries(batch = 20): Promise<{ processed: number }> {
    const client = await this.pool.connect();
    let processed = 0;
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{ id: string }>(
        `SELECT id FROM platform_webhook_deliveries
         WHERE status IN ('pending', 'retry_pending')
           AND next_attempt_at <= now()
         ORDER BY next_attempt_at ASC
         LIMIT $1
         FOR UPDATE SKIP LOCKED`,
        [batch],
      );
      await client.query('COMMIT');
      for (const row of rows) {
        await this.deliverOne(row.id);
        processed += 1;
      }
    } catch (err) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw err;
    } finally {
      client.release();
    }
    return { processed };
  }

  private async deliverOne(deliveryId: string): Promise<void> {
    const { rows } = await this.pool.query<{
      id: string;
      webhook_id: string;
      topic: string;
      payload: Record<string, unknown>;
      attempts: number;
      max_attempts: number;
      target_url: string;
      secret_key: string;
      secrets_ciphertext: string | null;
    }>(
      `SELECT d.id, d.webhook_id, d.topic, d.payload, d.attempts, d.max_attempts,
              w.target_url, w.secret_key, w.secrets_ciphertext
       FROM platform_webhook_deliveries d
       INNER JOIN platform_webhooks w ON w.id = d.webhook_id
       WHERE d.id = $1::uuid`,
      [deliveryId],
    );
    const d = rows[0];
    if (!d) return;

    let signingSecret = '';
    if (d.secrets_ciphertext) {
      try {
        signingSecret = this.crypto.decrypt(d.secrets_ciphertext);
      } catch {
        signingSecret = d.secret_key ?? '';
      }
    } else {
      signingSecret = d.secret_key ?? '';
    }
    if (!signingSecret) {
      await this.pool.query(
        `UPDATE platform_webhook_deliveries
         SET status = 'dead_letter', last_error = 'missing_signing_secret', completed_at = now(), updated_at = now()
         WHERE id = $1::uuid`,
        [deliveryId],
      );
      this.metrics.inc('webhook_deliveries_total', { status: 'dead_letter' });
      return;
    }

    await this.pool.query(
      `UPDATE platform_webhook_deliveries SET status = 'running', updated_at = now() WHERE id = $1::uuid`,
      [deliveryId],
    );

    const body = JSON.stringify(d.payload);
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const signature = createHmac('sha256', signingSecret)
      .update(`${timestamp}.${body}`)
      .digest('hex');

    let statusCode: number | null = null;
    let responseBody: string | null = null;
    let error: string | null = null;
    let ok = false;

    try {
      const res = await fetch(d.target_url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Owambe-Topic': d.topic,
          'X-Owambe-Timestamp': timestamp,
          'X-Owambe-Signature': `v1=${signature}`,
          'User-Agent': 'Owambe-OutboundWebhook/1.0',
        },
        body,
        signal: AbortSignal.timeout(15_000),
      });
      statusCode = res.status;
      responseBody = (await res.text()).slice(0, 2000);
      ok = res.ok;
      if (!ok) error = `HTTP ${res.status}`;
    } catch (err) {
      error = err instanceof Error ? err.message : 'delivery_failed';
    }

    const attempts = d.attempts + 1;

    // Also mirror into legacy platform_webhook_logs for Hub history
    await this.pool.query(
      `INSERT INTO platform_webhook_logs (webhook_id, topic, status, payload_body, response_code, response_body, retry_count)
       VALUES ($1::uuid, $2, $3, $4, $5, $6, $7)`,
      [
        d.webhook_id,
        d.topic,
        ok ? 'success' : attempts >= d.max_attempts ? 'failed' : 'retry_pending',
        body.slice(0, 8000),
        statusCode,
        responseBody,
        attempts,
      ],
    ).catch(() => undefined);

    if (ok) {
      await this.pool.query(
        `UPDATE platform_webhook_deliveries
         SET status = 'success', attempts = $2, last_status_code = $3, response_body = $4,
             last_error = NULL, completed_at = now(), updated_at = now()
         WHERE id = $1::uuid`,
        [deliveryId, attempts, statusCode, responseBody],
      );
      this.metrics.inc('webhook_deliveries_total', { status: 'success' });
      return;
    }

    if (attempts >= d.max_attempts) {
      await this.pool.query(
        `UPDATE platform_webhook_deliveries
         SET status = 'dead_letter', attempts = $2, last_status_code = $3, response_body = $4,
             last_error = $5, completed_at = now(), updated_at = now()
         WHERE id = $1::uuid`,
        [deliveryId, attempts, statusCode, responseBody, error],
      );
      this.logger.warn(`Webhook delivery dead-lettered ${deliveryId}: ${error}`);
      this.metrics.inc('webhook_deliveries_total', { status: 'dead_letter' });
      return;
    }

    const backoffSec = Math.min(3600, Math.pow(2, attempts) * 15);
    await this.pool.query(
      `UPDATE platform_webhook_deliveries
       SET status = 'retry_pending', attempts = $2, last_status_code = $3, response_body = $4,
           last_error = $5, next_attempt_at = now() + make_interval(secs => $6::int), updated_at = now()
       WHERE id = $1::uuid`,
      [deliveryId, attempts, statusCode, responseBody, error, backoffSec],
    );
    this.metrics.inc('webhook_deliveries_total', { status: 'retry_pending' });
  }

  async observabilitySnapshot() {
    const { rows } = await this.pool.query<{ status: string; n: string }>(
      `SELECT status, COUNT(*)::text AS n FROM platform_webhook_deliveries GROUP BY status`,
    );
    const byStatus = Object.fromEntries(rows.map((r) => [r.status, parseInt(r.n, 10)]));
    return {
      generatedAt: new Date().toISOString(),
      byStatus,
      success: byStatus.success ?? 0,
      failed: byStatus.failed ?? 0,
      retrying: byStatus.retry_pending ?? 0,
      deadLetter: byStatus.dead_letter ?? 0,
      pending: (byStatus.pending ?? 0) + (byStatus.running ?? 0),
    };
  }

  /** Verify helper for partners / tests */
  static verifySignature(secret: string, timestamp: string, body: string, header: string): boolean {
    const expected = `v1=${createHmac('sha256', secret).update(`${timestamp}.${body}`).digest('hex')}`;
    const a = Buffer.from(expected);
    const b = Buffer.from(header);
    if (a.length !== b.length) return false;
    return timingSafeEqual(a, b);
  }
}
