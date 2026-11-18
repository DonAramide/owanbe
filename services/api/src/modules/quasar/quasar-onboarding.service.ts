import { Inject, Injectable, Logger, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { QuasarClientService } from './quasar-client.service';
import { QuasarModeService } from './quasar-mode.service';
import { QuasarVaultService } from './quasar-vault.service';
import {
  apiKeyHint,
  assertTenantApiKey,
  isUuid,
  pickString,
  quasarTenantSlug,
  readSecretKey,
} from './quasar.policy';
import type { QuasarMerchantCredentials, QuasarPublicAccount } from './quasar.types';

@Injectable()
export class QuasarOnboardingService {
  private readonly logger = new Logger(QuasarOnboardingService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly mode: QuasarModeService,
    private readonly client: QuasarClientService,
    private readonly vault: QuasarVaultService,
  ) {}

  toPublic(merchant: QuasarMerchantCredentials): QuasarPublicAccount {
    return {
      environment: merchant.environment,
      quasarTenantId: merchant.quasarTenantId,
      slug: merchant.slug,
      code: merchant.code,
      vertical: merchant.vertical,
      webhookRegistered: merchant.webhookRegistered,
    };
  }

  async activateOrganizer(owanbeTenantId: string, organizerId: string): Promise<QuasarPublicAccount> {
    const merchant = await this.ensureOrganizer(owanbeTenantId, organizerId);
    return this.toPublic(merchant);
  }

  async describeOrganizer(owanbeTenantId: string, organizerId: string): Promise<QuasarPublicAccount | null> {
    if (!this.mode.isConfigured()) return null;
    const existing = await this.vault.find(
      owanbeTenantId,
      'organizer',
      organizerId,
      this.mode.keyEnvironment(),
    );
    return existing ? this.toPublic(existing) : null;
  }

  async ensureOrganizer(owanbeTenantId: string, organizerId: string): Promise<QuasarMerchantCredentials> {
    if (!this.mode.isConfigured()) {
      throw new UnprocessableEntityException({
        code: 'QUASAR_NOT_CONFIGURED',
        message: 'Set QUASAR_CLIENT_SECRET to enable the Quasar sandbox',
      });
    }
    const organizer = await this.pool.query<{ display_name: string; slug: string; status: string }>(
      `SELECT display_name, slug, status::text
       FROM organizers
       WHERE id = $1 AND tenant_id = $2`,
      [organizerId, owanbeTenantId],
    );
    const row = organizer.rows[0];
    if (!row || row.status !== 'active') {
      throw new UnprocessableEntityException({
        code: 'ORGANIZER_NOT_ACTIVE',
        message: 'An active organizer is required before creating a Quasar tenant',
      });
    }
    return this.ensureMerchant({
      owanbeTenantId,
      ownerKind: 'organizer',
      ownerId: organizerId,
      name: row.display_name,
      slug: row.slug,
    });
  }

  async ensureMerchant(input: {
    owanbeTenantId: string;
    ownerKind: 'organizer' | 'vendor';
    ownerId: string;
    name: string;
    slug: string;
  }): Promise<QuasarMerchantCredentials> {
    const environment = this.mode.keyEnvironment();
    const lockClient = await this.pool.connect();
    const lockKey = `${input.owanbeTenantId}:${input.ownerKind}:${input.ownerId}:${environment}`;
    try {
      await lockClient.query('SELECT pg_advisory_lock(hashtext($1))', [lockKey]);
      const existing = await this.vault.find(input.owanbeTenantId, input.ownerKind, input.ownerId, environment);
      if (existing) {
        assertTenantApiKey(existing.apiKey);
        if (!existing.webhookRegistered) {
          await this.registerWebhook(existing);
          const refreshed = await this.vault.find(input.owanbeTenantId, input.ownerKind, input.ownerId, environment);
          return refreshed ?? existing;
        }
        return existing;
      }

      const slug = quasarTenantSlug(input.ownerKind, input.slug, input.ownerId);
      const created = await this.client.createTenant({
        name: input.name,
        slug,
        idempotencyKey: `owanbe-tenant-${input.ownerKind}-${input.ownerId}`,
      });
      const quasarTenantId = pickString(created, ['id']);
      if (!quasarTenantId || !isUuid(quasarTenantId)) {
        throw new Error('Quasar tenant response did not include an id');
      }
      const keyResult = await this.client.createTenantApiKey({
        quasarTenantId,
        name: `Owanbe — ${input.name}`.slice(0, 80),
        idempotencyKey: `owanbe-key-${quasarTenantId}-${environment}`,
      });
      const secretKey = readSecretKey(keyResult.data);
      assertTenantApiKey(secretKey);

      const merchant = await this.vault.insert({
        owanbeTenantId: input.owanbeTenantId,
        ownerKind: input.ownerKind,
        ownerId: input.ownerId,
        quasarTenantId,
        slug: pickString(created, ['slug']) ?? slug,
        code: pickString(created, ['code']),
        vertical: pickString(created, ['vertical']) ?? 'owanbe',
        environment: keyResult.environment,
        apiKey: secretKey,
        apiKeyHint: apiKeyHint(secretKey),
        walletOwnerId: input.ownerId,
      });
      await this.registerWebhook(merchant);
      const refreshed = await this.vault.find(input.owanbeTenantId, input.ownerKind, input.ownerId, environment);
      return refreshed ?? merchant;
    } finally {
      await lockClient.query('SELECT pg_advisory_unlock(hashtext($1))', [lockKey]).catch(() => undefined);
      lockClient.release();
    }
  }

  private async registerWebhook(merchant: QuasarMerchantCredentials): Promise<void> {
    const url = this.mode.webhookUrlFor(merchant.quasarTenantId);
    if (!url) {
      this.logger.warn({ quasarTenantId: merchant.quasarTenantId }, 'PUBLIC_API_BASE_URL unset; Quasar webhook not registered');
      return;
    }
    try {
      const registered = await this.client.registerWebhook({
        apiKey: merchant.apiKey,
        url,
        idempotencyKey: `owanbe-webhook-${merchant.quasarTenantId}`,
      });
      const signingSecret =
        pickString(registered, ['signingSecret', 'signing_secret']) ??
        (registered.data && typeof registered.data === 'object' && !Array.isArray(registered.data)
          ? pickString(registered.data as Record<string, unknown>, ['signingSecret', 'signing_secret'])
          : null);
      if (!signingSecret) {
        this.logger.warn({ quasarTenantId: merchant.quasarTenantId }, 'Quasar webhook response missing signing secret');
        return;
      }
      await this.vault.saveWebhook(merchant.id, url, signingSecret);
    } catch (error) {
      this.logger.warn(
        { quasarTenantId: merchant.quasarTenantId, error: (error as Error).message },
        'Quasar webhook registration failed',
      );
    }
  }
}
