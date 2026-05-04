import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';

export interface QuaserInitiatePaymentInput {
  tenantId: string;
  paymentId: string;
  bookingId: string;
  amountMinor: string;
  currency: string;
  idempotencyKey: string;
  webhookUrl: string;
}

export interface QuaserInitiatePaymentResult {
  quaserReference: string;
  /** Optional redirect / hosted payment URL from router */
  clientActionUrl?: string;
  raw: Record<string, unknown>;
}

export interface QuaserVerifyPaymentInput {
  tenantId: string;
  paymentId: string;
  quaserReference: string;
}

export interface QuaserVerifyPaymentResult {
  ok: boolean;
  amountMinor?: string;
  currency?: string;
  status?: string;
  raw: Record<string, unknown>;
}

/**
 * HTTP client for Quaser payment router (initiate + S2S verify).
 * When QUASER_ROUTER_BASE_URL is unset, returns deterministic dev stubs.
 */
@Injectable()
export class QuaserRouterService {
  private readonly logger = new Logger(QuaserRouterService.name);

  constructor(private readonly config: ConfigService<EnvVars, true>) {}

  private baseUrl() {
    return this.config.get('QUASER_ROUTER_BASE_URL', { infer: true }).trim();
  }

  private apiKey() {
    return this.config.get('QUASER_ROUTER_API_KEY', { infer: true }).trim();
  }

  async initiatePayment(input: QuaserInitiatePaymentInput): Promise<QuaserInitiatePaymentResult> {
    const base = this.baseUrl();
    if (!base) {
      const quaserReference = `OWB-DEV-${input.paymentId.slice(0, 8)}`;
      this.logger.warn('QUASER_ROUTER_BASE_URL empty; using stub initiate response');
      return {
        quaserReference,
        raw: { stub: true, input },
      };
    }

    const url = `${base.replace(/\/$/, '')}/v1/payments`;
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey()}`,
        'Idempotency-Key': input.idempotencyKey,
      },
      body: JSON.stringify({
        tenant_id: input.tenantId,
        payment_id: input.paymentId,
        booking_id: input.bookingId,
        amount_minor: input.amountMinor,
        currency: input.currency,
        webhook_url: input.webhookUrl,
      }),
    });
    const raw = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    if (!res.ok) {
      this.logger.warn({ status: res.status, raw }, 'Quaser initiate failed');
      throw new Error(`Quaser initiate failed: HTTP ${res.status}`);
    }
    const ref =
      (typeof raw.quaser_reference === 'string' && raw.quaser_reference) ||
      (typeof raw.reference === 'string' && raw.reference) ||
      '';
    if (!ref) {
      throw new Error('Quaser initiate response missing reference');
    }
    const clientActionUrl =
      typeof raw.client_action_url === 'string'
        ? raw.client_action_url
        : typeof raw.checkout_url === 'string'
          ? raw.checkout_url
          : undefined;
    return { quaserReference: ref, clientActionUrl, raw };
  }

  /**
   * Mandatory S2S verification for high-value or operational flags.
   */
  async verifyPayment(input: QuaserVerifyPaymentInput): Promise<QuaserVerifyPaymentResult> {
    const base = this.baseUrl();
    if (!base) {
      this.logger.warn('QUASER_ROUTER_BASE_URL empty; verify skipped (dev)');
      return { ok: true, status: 'stubbed', raw: { stub: true } };
    }
    const url = `${base.replace(/\/$/, '')}/v1/payments/${encodeURIComponent(input.paymentId)}/verify`;
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey()}`,
      },
      body: JSON.stringify({
        tenant_id: input.tenantId,
        quaser_reference: input.quaserReference,
      }),
    });
    const raw = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    if (!res.ok) {
      return { ok: false, raw };
    }
    const ok = raw.ok === true || raw.verified === true || res.status === 200;
    const amountMinor =
      typeof raw.amount_minor === 'string'
        ? raw.amount_minor
        : typeof raw.amount_minor === 'number'
          ? String(raw.amount_minor)
          : undefined;
    const currency = typeof raw.currency === 'string' ? raw.currency : undefined;
    const status = typeof raw.status === 'string' ? raw.status : undefined;
    return { ok, amountMinor, currency, status, raw };
  }

  async initiatePayoutTransfer(input: {
    tenantId: string;
    payoutId: string;
    amountMinor: string;
    currency: string;
    vendorId: string;
    idempotencyKey: string;
    webhookUrl: string;
  }): Promise<{ quaserReference: string; raw: Record<string, unknown> }> {
    const base = this.baseUrl();
    if (!base) {
      const quaserReference = `OWB-PAYOUT-DEV-${input.payoutId.slice(0, 8)}`;
      return { quaserReference, raw: { stub: true } };
    }
    const url = `${base.replace(/\/$/, '')}/v1/payouts`;
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey()}`,
        'Idempotency-Key': input.idempotencyKey,
      },
      body: JSON.stringify({
        tenant_id: input.tenantId,
        payout_id: input.payoutId,
        amount_minor: input.amountMinor,
        currency: input.currency,
        vendor_id: input.vendorId,
        webhook_url: input.webhookUrl,
      }),
    });
    const raw = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    if (!res.ok) {
      this.logger.warn({ status: res.status, raw }, 'Quaser payout initiate failed');
      throw new Error(`Quaser payout initiate failed: HTTP ${res.status}`);
    }
    const ref =
      (typeof raw.quaser_reference === 'string' && raw.quaser_reference) ||
      (typeof raw.reference === 'string' && raw.reference) ||
      '';
    if (!ref) {
      throw new Error('Quaser payout response missing reference');
    }
    return { quaserReference: ref, raw };
  }
}
