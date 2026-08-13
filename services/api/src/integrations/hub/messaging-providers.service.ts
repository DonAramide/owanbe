import {
  Injectable,
  Inject,
  Logger,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { EmailSecretsCrypto } from '../email-infrastructure/email-secrets.crypto';

export type MessagingChannel = 'sms' | 'whatsapp';

export type MessagingSecrets = {
  accountSid?: string;
  authToken?: string;
  apiKey?: string;
  apiSecret?: string;
};

/**
 * Phase 24 — SMS / WhatsApp provider config (adapter pattern).
 * Secrets encrypted with EmailSecretsCrypto; NotificationService consumes resolveActive().
 */
@Injectable()
export class MessagingProvidersService {
  private readonly logger = new Logger(MessagingProvidersService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly crypto: EmailSecretsCrypto,
  ) {}

  async list(channel?: MessagingChannel) {
    const { rows } = await this.pool.query(
      `SELECT id, tenant_id, organizer_id, channel, provider_type, name, enabled, is_default,
              from_address, config, last_error, created_at, updated_at,
              CASE WHEN secrets_ciphertext IS NOT NULL THEN true ELSE false END AS has_secrets
       FROM messaging_providers
       WHERE ($1::text IS NULL OR channel = $1)
       ORDER BY channel, is_default DESC, name`,
      [channel ?? null],
    );
    return rows.map((r) => this.mapRow(r));
  }

  async create(input: {
    actorUserId: string;
    channel: MessagingChannel;
    providerType?: string;
    name: string;
    fromAddress?: string;
    tenantId?: string | null;
    organizerId?: string | null;
    secrets?: MessagingSecrets;
    config?: Record<string, unknown>;
    setDefault?: boolean;
  }) {
    if (!['sms', 'whatsapp'].includes(input.channel)) {
      throw new BadRequestException('channel must be sms or whatsapp');
    }
    const ciphertext = input.secrets
      ? this.crypto.encrypt(JSON.stringify(input.secrets))
      : null;

    const { rows } = await this.pool.query(
      `INSERT INTO messaging_providers
         (tenant_id, organizer_id, channel, provider_type, name, enabled, is_default,
          from_address, secrets_ciphertext, config, created_by, updated_by)
       VALUES ($1::uuid, $2::uuid, $3, $4, $5, true, $6, $7, $8, $9::jsonb, $10::uuid, $10::uuid)
       RETURNING id`,
      [
        input.tenantId ?? null,
        input.organizerId ?? null,
        input.channel,
        input.providerType ?? (input.channel === 'whatsapp' ? 'meta' : 'twilio'),
        input.name,
        input.setDefault === true,
        input.fromAddress ?? null,
        ciphertext,
        JSON.stringify(input.config ?? {}),
        input.actorUserId,
      ],
    );
    const id = rows[0].id as string;
    if (input.setDefault) await this.setDefault(id, input.actorUserId);
    await this.audit(id, input.actorUserId, 'create', { channel: input.channel });
    return this.get(id);
  }

  async update(
    id: string,
    actorUserId: string,
    patch: {
      name?: string;
      enabled?: boolean;
      fromAddress?: string;
      secrets?: MessagingSecrets;
      config?: Record<string, unknown>;
    },
  ) {
    const existing = await this.getRaw(id);
    const ciphertext = patch.secrets
      ? this.crypto.encrypt(JSON.stringify(patch.secrets))
      : existing.secrets_ciphertext;

    await this.pool.query(
      `UPDATE messaging_providers
       SET name = COALESCE($2, name),
           enabled = COALESCE($3, enabled),
           from_address = COALESCE($4, from_address),
           secrets_ciphertext = $5,
           config = COALESCE($6::jsonb, config),
           updated_by = $7::uuid,
           updated_at = now(),
           last_error = NULL
       WHERE id = $1::uuid`,
      [
        id,
        patch.name ?? null,
        patch.enabled ?? null,
        patch.fromAddress ?? null,
        ciphertext,
        patch.config ? JSON.stringify(patch.config) : null,
        actorUserId,
      ],
    );
    await this.audit(id, actorUserId, 'update', {});
    return this.get(id);
  }

  async setDefault(id: string, actorUserId: string) {
    const row = await this.getRaw(id);
    await this.pool.query('BEGIN');
    try {
      await this.pool.query(
        `UPDATE messaging_providers SET is_default = false
         WHERE channel = $1 AND COALESCE(tenant_id::text, 'platform') = COALESCE($2::text, 'platform')`,
        [row.channel, row.tenant_id],
      );
      await this.pool.query(
        `UPDATE messaging_providers SET is_default = true, updated_at = now(), updated_by = $2::uuid
         WHERE id = $1::uuid`,
        [id, actorUserId],
      );
      await this.pool.query('COMMIT');
    } catch (e) {
      await this.pool.query('ROLLBACK');
      throw e;
    }
    await this.audit(id, actorUserId, 'set_default', {});
    return this.get(id);
  }

  async get(id: string) {
    return this.mapRow(await this.getRaw(id));
  }

  async resolveActive(
    channel: MessagingChannel,
    tenantId?: string | null,
  ): Promise<{
    id: string;
    providerType: string;
    fromAddress: string | null;
    secrets: MessagingSecrets;
    config: Record<string, unknown>;
  } | null> {
    const { rows } = await this.pool.query(
      `SELECT id, provider_type, from_address, secrets_ciphertext, config
       FROM messaging_providers
       WHERE channel = $1 AND enabled = true AND secrets_ciphertext IS NOT NULL
         AND ($2::uuid IS NULL OR tenant_id IS NULL OR tenant_id = $2::uuid)
       ORDER BY
         CASE WHEN tenant_id = $2::uuid THEN 0 WHEN tenant_id IS NULL THEN 1 ELSE 2 END,
         is_default DESC,
         updated_at DESC
       LIMIT 1`,
      [channel, tenantId ?? null],
    );
    const r = rows[0];
    if (!r?.secrets_ciphertext) return null;
    let secrets: MessagingSecrets = {};
    try {
      secrets = JSON.parse(this.crypto.decrypt(r.secrets_ciphertext)) as MessagingSecrets;
    } catch (err) {
      this.logger.warn(`Failed to decrypt messaging secrets for ${r.id}`);
      return null;
    }
    return {
      id: r.id,
      providerType: r.provider_type,
      fromAddress: r.from_address,
      secrets,
      config: r.config ?? {},
    };
  }

  /** WhatsApp foundation — send abstraction (Meta Cloud API stub when configured). */
  async sendWhatsApp(input: {
    tenantId?: string | null;
    to: string;
    body: string;
  }): Promise<{ ok: boolean; externalId?: string; reason?: string }> {
    const active = await this.resolveActive('whatsapp', input.tenantId);
    if (!active) {
      return { ok: false, reason: 'No WhatsApp provider configured' };
    }
    if (active.providerType === 'log' || !active.secrets.apiKey) {
      this.logger.log({ to: input.to }, 'WhatsApp (foundation log-only)');
      return { ok: true, externalId: 'log-whatsapp' };
    }
    // Meta Cloud API foundation — requires phone_number_id in config
    const phoneNumberId = String(active.config.phoneNumberId ?? '');
    if (!phoneNumberId || !active.secrets.apiKey) {
      return { ok: false, reason: 'WhatsApp config incomplete (phoneNumberId / apiKey)' };
    }
    try {
      const res = await fetch(
        `https://graph.facebook.com/v19.0/${phoneNumberId}/messages`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${active.secrets.apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: input.to.replace(/\D/g, ''),
            type: 'text',
            text: { body: input.body },
          }),
          signal: AbortSignal.timeout(15_000),
        },
      );
      const raw = (await res.json().catch(() => ({}))) as {
        messages?: Array<{ id?: string }>;
        error?: { message?: string };
      };
      if (!res.ok) {
        await this.pool.query(
          `UPDATE messaging_providers SET last_error = $2, updated_at = now() WHERE id = $1::uuid`,
          [active.id, raw.error?.message ?? `HTTP ${res.status}`],
        );
        return { ok: false, reason: raw.error?.message ?? `HTTP ${res.status}` };
      }
      return { ok: true, externalId: raw.messages?.[0]?.id };
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'whatsapp_failed';
      return { ok: false, reason: msg };
    }
  }

  private async getRaw(id: string) {
    const { rows } = await this.pool.query(
      `SELECT * FROM messaging_providers WHERE id = $1::uuid`,
      [id],
    );
    if (!rows[0]) throw new NotFoundException('Messaging provider not found');
    return rows[0];
  }

  private mapRow(r: Record<string, unknown>) {
    return {
      id: r.id,
      tenantId: r.tenant_id,
      organizerId: r.organizer_id,
      channel: r.channel,
      providerType: r.provider_type,
      name: r.name,
      enabled: r.enabled,
      isDefault: r.is_default,
      fromAddress: r.from_address,
      config: r.config ?? {},
      lastError: r.last_error,
      hasSecrets: r.has_secrets ?? !!r.secrets_ciphertext,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }

  private async audit(
    providerId: string,
    actorUserId: string,
    action: string,
    detail: Record<string, unknown>,
  ) {
    await this.pool.query(
      `INSERT INTO messaging_provider_audit (provider_id, actor_user_id, action, detail)
       VALUES ($1::uuid, $2::uuid, $3, $4::jsonb)`,
      [providerId, actorUserId, action, JSON.stringify(detail)],
    );
  }
}
