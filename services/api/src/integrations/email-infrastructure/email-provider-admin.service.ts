import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { EmailSecretsCrypto } from './email-secrets.crypto';
import { EmailService } from './email.service';
import { providerTypeDefaults } from './email.types';
import type {
  EmailEncryptionMode,
  EmailProviderPublicView,
  EmailProviderRow,
  EmailProviderType,
} from './email.types';

export interface UpsertEmailProviderDto {
  name: string;
  providerType: EmailProviderType;
  smtpHost?: string | null;
  smtpPort?: number | null;
  encryptionMode?: EmailEncryptionMode;
  username?: string | null;
  password?: string | null;
  apiKey?: string | null;
  senderName: string;
  senderEmail: string;
  replyTo?: string | null;
  connectionTimeoutMs?: number;
  retryAttempts?: number;
  retryDelayMs?: number;
  dailySendingLimit?: number | null;
  enabled?: boolean;
  isDefault?: boolean;
  priority?: number;
  metadata?: Record<string, unknown>;
}

@Injectable()
export class EmailProviderAdminService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly crypto: EmailSecretsCrypto,
    private readonly email: EmailService,
  ) {}

  async list(): Promise<EmailProviderPublicView[]> {
    const { rows } = await this.pool.query<EmailProviderRow>(
      `SELECT * FROM email_providers
       WHERE tenant_id IS NULL
       ORDER BY is_default DESC, priority ASC, name ASC`,
    );
    return rows.map((r) => this.email.toPublicView(r));
  }

  async get(id: string): Promise<EmailProviderPublicView> {
    const row = await this.email.getRow(id);
    if (!row) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Provider not found' });
    return this.email.toPublicView(row);
  }

  async create(actorUserId: string, dto: UpsertEmailProviderDto): Promise<EmailProviderPublicView> {
    this.validateDto(dto);
    const defaults = providerTypeDefaults(dto.providerType);
    const passwordCipher = dto.password ? this.crypto.encrypt(dto.password) : null;
    const apiKeyCipher = dto.apiKey ? this.crypto.encrypt(dto.apiKey) : null;

    if (dto.isDefault) {
      await this.clearPlatformDefault();
    }

    const { rows } = await this.pool.query<EmailProviderRow>(
      `INSERT INTO email_providers (
         tenant_id, name, provider_type, smtp_host, smtp_port, encryption_mode,
         username, password_ciphertext, api_key_ciphertext,
         sender_name, sender_email, reply_to,
         connection_timeout_ms, retry_attempts, retry_delay_ms, daily_sending_limit,
         enabled, is_default, priority, metadata, created_by, updated_by
       ) VALUES (
         NULL, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19::jsonb, $20, $20
       ) RETURNING *`,
      [
        dto.name.trim(),
        dto.providerType,
        dto.smtpHost ?? defaults.smtpHost ?? null,
        dto.smtpPort ?? defaults.smtpPort ?? 587,
        dto.encryptionMode ?? defaults.encryptionMode ?? 'starttls',
        dto.username ?? null,
        passwordCipher,
        apiKeyCipher,
        dto.senderName.trim(),
        dto.senderEmail.trim().toLowerCase(),
        dto.replyTo?.trim() || null,
        dto.connectionTimeoutMs ?? 10_000,
        dto.retryAttempts ?? 2,
        dto.retryDelayMs ?? 1_000,
        dto.dailySendingLimit ?? null,
        dto.enabled ?? true,
        dto.isDefault ?? false,
        dto.priority ?? 100,
        JSON.stringify(dto.metadata ?? {}),
        actorUserId,
      ],
    );

    await this.audit(rows[0]!.id, actorUserId, 'created', { name: dto.name, type: dto.providerType });
    return this.email.toPublicView(rows[0]!);
  }

  async update(
    id: string,
    actorUserId: string,
    dto: Partial<UpsertEmailProviderDto>,
  ): Promise<EmailProviderPublicView> {
    const existing = await this.email.getRow(id);
    if (!existing) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Provider not found' });

    if (dto.isDefault === true) {
      await this.clearPlatformDefault();
    }

    const passwordCipher =
      dto.password !== undefined && dto.password !== null && dto.password !== ''
        ? this.crypto.encrypt(dto.password)
        : existing.password_ciphertext;
    const apiKeyCipher =
      dto.apiKey !== undefined && dto.apiKey !== null && dto.apiKey !== ''
        ? this.crypto.encrypt(dto.apiKey)
        : existing.api_key_ciphertext;

    const { rows } = await this.pool.query<EmailProviderRow>(
      `UPDATE email_providers SET
         name = COALESCE($2, name),
         provider_type = COALESCE($3, provider_type),
         smtp_host = COALESCE($4, smtp_host),
         smtp_port = COALESCE($5, smtp_port),
         encryption_mode = COALESCE($6, encryption_mode),
         username = COALESCE($7, username),
         password_ciphertext = $8,
         api_key_ciphertext = $9,
         sender_name = COALESCE($10, sender_name),
         sender_email = COALESCE($11, sender_email),
         reply_to = COALESCE($12, reply_to),
         connection_timeout_ms = COALESCE($13, connection_timeout_ms),
         retry_attempts = COALESCE($14, retry_attempts),
         retry_delay_ms = COALESCE($15, retry_delay_ms),
         daily_sending_limit = COALESCE($16, daily_sending_limit),
         enabled = COALESCE($17, enabled),
         is_default = COALESCE($18, is_default),
         priority = COALESCE($19, priority),
         metadata = COALESCE($20::jsonb, metadata),
         updated_by = $21,
         updated_at = now()
       WHERE id = $1
       RETURNING *`,
      [
        id,
        dto.name?.trim() ?? null,
        dto.providerType ?? null,
        dto.smtpHost !== undefined ? dto.smtpHost : null,
        dto.smtpPort !== undefined ? dto.smtpPort : null,
        dto.encryptionMode ?? null,
        dto.username !== undefined ? dto.username : null,
        passwordCipher,
        apiKeyCipher,
        dto.senderName?.trim() ?? null,
        dto.senderEmail?.trim().toLowerCase() ?? null,
        dto.replyTo !== undefined ? dto.replyTo?.trim() || null : null,
        dto.connectionTimeoutMs ?? null,
        dto.retryAttempts ?? null,
        dto.retryDelayMs ?? null,
        dto.dailySendingLimit !== undefined ? dto.dailySendingLimit : null,
        dto.enabled ?? null,
        dto.isDefault ?? null,
        dto.priority ?? null,
        dto.metadata ? JSON.stringify(dto.metadata) : null,
        actorUserId,
      ],
    );

    await this.audit(id, actorUserId, 'updated', { fields: Object.keys(dto) });
    return this.email.toPublicView(rows[0]!);
  }

  async remove(id: string, actorUserId: string): Promise<{ ok: true }> {
    const existing = await this.email.getRow(id);
    if (!existing) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Provider not found' });
    await this.pool.query(`DELETE FROM email_providers WHERE id = $1`, [id]);
    await this.audit(id, actorUserId, 'deleted', { name: existing.name });
    return { ok: true };
  }

  async setDefault(id: string, actorUserId: string): Promise<EmailProviderPublicView> {
    const existing = await this.email.getRow(id);
    if (!existing) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Provider not found' });
    await this.clearPlatformDefault();
    await this.pool.query(
      `UPDATE email_providers SET is_default = true, enabled = true, updated_by = $2, updated_at = now() WHERE id = $1`,
      [id, actorUserId],
    );
    await this.audit(id, actorUserId, 'set_default', {});
    return this.get(id);
  }

  async recordAudit(
    providerId: string | null,
    actorUserId: string,
    action: string,
    detail: Record<string, unknown>,
  ): Promise<void> {
    await this.audit(providerId, actorUserId, action, detail);
  }

  async listAudit(providerId?: string, limit = 50) {
    const { rows } = providerId
      ? await this.pool.query(
          `SELECT id, provider_id, actor_user_id, action, detail, created_at
           FROM email_provider_audit WHERE provider_id = $1
           ORDER BY created_at DESC LIMIT $2`,
          [providerId, limit],
        )
      : await this.pool.query(
          `SELECT id, provider_id, actor_user_id, action, detail, created_at
           FROM email_provider_audit
           ORDER BY created_at DESC LIMIT $1`,
          [limit],
        );
    return rows;
  }

  private async clearPlatformDefault(): Promise<void> {
    await this.pool.query(
      `UPDATE email_providers SET is_default = false WHERE tenant_id IS NULL AND is_default = true`,
    );
  }

  private validateDto(dto: UpsertEmailProviderDto): void {
    if (!dto.name?.trim()) throw new BadRequestException({ code: 'VALIDATION', message: 'name required' });
    if (!dto.senderEmail?.trim()) {
      throw new BadRequestException({ code: 'VALIDATION', message: 'senderEmail required' });
    }
    if (!dto.senderName?.trim()) {
      throw new BadRequestException({ code: 'VALIDATION', message: 'senderName required' });
    }
  }

  private async audit(
    providerId: string | null,
    actorUserId: string,
    action: string,
    detail: Record<string, unknown>,
  ): Promise<void> {
    await this.pool.query(
      `INSERT INTO email_provider_audit (provider_id, actor_user_id, action, detail)
       VALUES ($1, $2, $3, $4::jsonb)`,
      [providerId, actorUserId, action, JSON.stringify(detail)],
    );
  }
}
