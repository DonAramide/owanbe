import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'crypto';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';

/**
 * AES-256-GCM encryption for email provider secrets at rest.
 * EMAIL_SECRETS_ENCRYPTION_KEY is required at process boot (Joi) — no development fallback.
 */
@Injectable()
export class EmailSecretsCrypto {
  constructor(private readonly config: ConfigService<EnvVars, true>) {}

  private keyBytes(): Buffer {
    const raw = (this.config.get('EMAIL_SECRETS_ENCRYPTION_KEY', { infer: true }) ?? '').trim();
    if (!raw || raw.length < 32) {
      throw new Error(
        'EMAIL_SECRETS_ENCRYPTION_KEY is missing or too short. ' +
          'The API cannot encrypt or decrypt email provider secrets. ' +
          'Set a 32+ character secret (or 64-char hex) and restart.',
      );
    }
    if (/^[0-9a-fA-F]{64}$/.test(raw)) {
      return Buffer.from(raw, 'hex');
    }
    return createHash('sha256').update(raw).digest();
  }

  encrypt(plain: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.keyBytes(), iv);
    const enc = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    return `${iv.toString('base64')}.${tag.toString('base64')}.${enc.toString('base64')}`;
  }

  decrypt(payload: string): string {
    const [ivB64, tagB64, dataB64] = payload.split('.');
    if (!ivB64 || !tagB64 || !dataB64) {
      throw new Error('Invalid ciphertext format — secret may be corrupted or encrypted with a different key');
    }
    const decipher = createDecipheriv('aes-256-gcm', this.keyBytes(), Buffer.from(ivB64, 'base64'));
    decipher.setAuthTag(Buffer.from(tagB64, 'base64'));
    const dec = Buffer.concat([
      decipher.update(Buffer.from(dataB64, 'base64')),
      decipher.final(),
    ]);
    return dec.toString('utf8');
  }

  /** Defense-in-depth check used by readiness probes. */
  assertKeyPresent(): void {
    this.keyBytes();
  }
}
