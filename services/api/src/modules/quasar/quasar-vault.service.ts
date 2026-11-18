import { Inject, Injectable } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { QuasarSecretsCrypto } from './quasar-secrets.crypto';
import type { QuasarMerchantCredentials, QuasarMerchantRecord } from './quasar.types';

interface MerchantRow {
  id: string;
  owanbe_tenant_id: string;
  owner_kind: 'organizer' | 'vendor';
  owner_id: string;
  quasar_tenant_id: string;
  slug: string;
  code: string | null;
  vertical: string;
  environment: 'test' | 'live';
  api_key_ciphertext: string;
  api_key_hint: string;
  wallet_owner_id: string;
  webhook_signing_secret_ciphertext: string | null;
}

@Injectable()
export class QuasarVaultService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly crypto: QuasarSecretsCrypto,
  ) {}

  async find(
    owanbeTenantId: string,
    ownerKind: 'organizer' | 'vendor',
    ownerId: string,
    environment: 'test' | 'live',
  ): Promise<QuasarMerchantCredentials | null> {
    const { rows } = await this.pool.query<MerchantRow>(
      `SELECT id, owanbe_tenant_id, owner_kind, owner_id, quasar_tenant_id, slug, code, vertical,
              environment, api_key_ciphertext, api_key_hint, wallet_owner_id,
              webhook_signing_secret_ciphertext
       FROM quasar_merchant_accounts
       WHERE owanbe_tenant_id = $1 AND owner_kind = $2 AND owner_id = $3 AND environment = $4`,
      [owanbeTenantId, ownerKind, ownerId, environment],
    );
    const row = rows[0];
    return row ? this.toCredentials(row) : null;
  }

  async findByQuasarTenantId(quasarTenantId: string): Promise<QuasarMerchantCredentials | null> {
    const { rows } = await this.pool.query<MerchantRow>(
      `SELECT id, owanbe_tenant_id, owner_kind, owner_id, quasar_tenant_id, slug, code, vertical,
              environment, api_key_ciphertext, api_key_hint, wallet_owner_id,
              webhook_signing_secret_ciphertext
       FROM quasar_merchant_accounts
       WHERE quasar_tenant_id = $1`,
      [quasarTenantId],
    );
    const row = rows[0];
    return row ? this.toCredentials(row) : null;
  }

  async insert(input: {
    owanbeTenantId: string;
    ownerKind: 'organizer' | 'vendor';
    ownerId: string;
    quasarTenantId: string;
    slug: string;
    code: string | null;
    vertical: string;
    environment: 'test' | 'live';
    apiKey: string;
    apiKeyHint: string;
    walletOwnerId: string;
  }): Promise<QuasarMerchantCredentials> {
    const { rows } = await this.pool.query<MerchantRow>(
      `INSERT INTO quasar_merchant_accounts (
         owanbe_tenant_id, owner_kind, owner_id, quasar_tenant_id, slug, code, vertical,
         environment, api_key_ciphertext, api_key_hint, wallet_owner_id
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING id, owanbe_tenant_id, owner_kind, owner_id, quasar_tenant_id, slug, code, vertical,
                 environment, api_key_ciphertext, api_key_hint, wallet_owner_id,
                 webhook_signing_secret_ciphertext`,
      [
        input.owanbeTenantId,
        input.ownerKind,
        input.ownerId,
        input.quasarTenantId,
        input.slug,
        input.code,
        input.vertical,
        input.environment,
        this.crypto.encrypt(input.apiKey),
        input.apiKeyHint,
        input.walletOwnerId,
      ],
    );
    return this.toCredentials(rows[0]!);
  }

  async saveWebhook(merchantId: string, url: string, signingSecret: string): Promise<void> {
    await this.pool.query(
      `UPDATE quasar_merchant_accounts
       SET webhook_url = $2,
           webhook_signing_secret_ciphertext = $3,
           updated_at = now()
       WHERE id = $1`,
      [merchantId, url, this.crypto.encrypt(signingSecret)],
    );
  }

  async signingSecretFor(quasarTenantId: string): Promise<{ merchant: QuasarMerchantRecord; secret: string } | null> {
    const merchant = await this.findByQuasarTenantId(quasarTenantId);
    if (!merchant) return null;
    const { rows } = await this.pool.query<{ webhook_signing_secret_ciphertext: string | null }>(
      `SELECT webhook_signing_secret_ciphertext FROM quasar_merchant_accounts WHERE id = $1`,
      [merchant.id],
    );
    const ciphertext = rows[0]?.webhook_signing_secret_ciphertext;
    if (!ciphertext) return null;
    return { merchant: this.publicRecord(merchant), secret: this.crypto.decrypt(ciphertext) };
  }

  private toCredentials(row: MerchantRow): QuasarMerchantCredentials {
    return {
      ...this.rowToRecord(row),
      apiKey: this.crypto.decrypt(row.api_key_ciphertext),
    };
  }

  private rowToRecord(row: MerchantRow): QuasarMerchantRecord {
    return {
      id: row.id,
      owanbeTenantId: row.owanbe_tenant_id,
      ownerKind: row.owner_kind,
      ownerId: row.owner_id,
      quasarTenantId: row.quasar_tenant_id,
      slug: row.slug,
      code: row.code,
      vertical: row.vertical,
      environment: row.environment,
      apiKeyHint: row.api_key_hint,
      walletOwnerId: row.wallet_owner_id,
      webhookRegistered: Boolean(row.webhook_signing_secret_ciphertext),
    };
  }

  private publicRecord(merchant: QuasarMerchantCredentials): QuasarMerchantRecord {
    return {
      id: merchant.id,
      owanbeTenantId: merchant.owanbeTenantId,
      ownerKind: merchant.ownerKind,
      ownerId: merchant.ownerId,
      quasarTenantId: merchant.quasarTenantId,
      slug: merchant.slug,
      code: merchant.code,
      vertical: merchant.vertical,
      environment: merchant.environment,
      apiKeyHint: merchant.apiKeyHint,
      walletOwnerId: merchant.walletOwnerId,
      webhookRegistered: merchant.webhookRegistered,
    };
  }
}
