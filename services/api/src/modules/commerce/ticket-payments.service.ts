import {
  ConflictException,
  Injectable,
  Inject,
  UnprocessableEntityException,
  forwardRef,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { randomUUID } from 'crypto';
import { PG_POOL } from '../../database/database.tokens';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { QuaserRouterService } from '../payments/quaser-router.service';
import { FinanceStateService } from '../payments/finance-state.service';
import { TicketCaptureService } from './ticket-capture.service';
import { IntegrationsModeService } from '../../integrations/integrations-mode.service';
import { QuasarModeService } from '../quasar/quasar-mode.service';
import { QuasarVirtualAccountService } from '../quasar/quasar-virtual-account.service';
import { payerNames, redactQuasarSecrets } from '../quasar/quasar.policy';

export interface CreateTicketPaymentResult {
  payment: {
    id: string;
    ticketOrderId: string;
    status: string;
    currency: string;
    amountExpectedMinor: string;
    quaserReference: string | null;
  };
  quaser: { clientActionUrl?: string };
  quasar?: {
    environment: 'test' | 'live';
    status: 'awaiting_transfer';
    virtualAccount: {
      accountNumber: string;
      bankName: string;
      currency: string;
    };
  };
  capture?: { ok: boolean; reason?: string };
  entitlements?: Array<{
    id: string;
    ticketCode: string;
    qrPayload: string;
    tierName: string;
    eventId: string;
    eventTitle: string;
    eventCity: string;
    eventVenue: string;
    startsAt: string;
    issuedAt: string;
  }>;
}

@Injectable()
export class TicketPaymentsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly quaser: QuaserRouterService,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly financeState: FinanceStateService,
    private readonly capture: TicketCaptureService,
    private readonly integrations: IntegrationsModeService,
    @Inject(forwardRef(() => QuasarModeService))
    private readonly quasarMode: QuasarModeService,
    @Inject(forwardRef(() => QuasarVirtualAccountService))
    private readonly quasarAccounts: QuasarVirtualAccountService,
  ) {}

  private publicWebhookUrl() {
    const base = this.config.get('PUBLIC_API_BASE_URL', { infer: true }).trim();
    return base ? `${base.replace(/\/$/, '')}/webhooks/quaser` : '';
  }

  private isQuaserStub() {
    return this.integrations.allowPaymentStubs();
  }

  async createPayment(
    tenantId: string,
    ticketOrderId: string,
    idempotencyHeader?: string,
  ): Promise<CreateTicketPaymentResult> {
    // Free fulfill short-circuit before payment-rail gates.
    const freeCheck = await this.pool.query<{
      status: string;
      currency: string;
      total_minor: string;
    }>(
      `SELECT status::text, currency, total_minor::text
       FROM ticket_orders WHERE id = $1 AND tenant_id = $2`,
      [ticketOrderId, tenantId],
    );
    const freeOrder = freeCheck.rows[0];
    if (freeOrder?.status === 'fulfilled' && freeOrder.total_minor === '0') {
      const entitlements = await this.loadEntitlements(tenantId, ticketOrderId);
      return {
        payment: {
          id: `free_${ticketOrderId}`,
          ticketOrderId,
          status: 'captured',
          currency: freeOrder.currency,
          amountExpectedMinor: '0',
          quaserReference: null,
        },
        quaser: {},
        capture: { ok: true, reason: 'free_order' },
        entitlements,
      };
    }

    await this.financeState.ensurePaymentsAllowed();

    if (
      !this.quasarMode.isConfigured() &&
      !this.integrations.allowPaymentStubs() &&
      !this.integrations.isQuaserConfigured()
    ) {
      throw new UnprocessableEntityException({
        code: 'PAYMENTS_NOT_CONFIGURED',
        message:
          'Set QUASAR_CLIENT_SECRET for sandbox capture, or PAYMENT_MOCK_MODE=true for an explicit local fake',
      });
    }

    const idem =
      idempotencyHeader && idempotencyHeader.trim().length >= 8 && idempotencyHeader.length <= 128
        ? idempotencyHeader.trim()
        : `tpay_${ticketOrderId}_${randomUUID()}`;

    const client = await this.pool.connect();
    let paymentId: string;
    let currency: string;
    let totalMinor: string;
    try {
      await client.query('BEGIN');

      const existing = await client.query<{
        id: string;
        ticket_order_id: string;
        status: string;
        currency: string;
        quaser_reference: string | null;
      }>(
        `SELECT id, ticket_order_id, status::text, currency, quaser_reference
         FROM ticket_payments WHERE tenant_id = $1 AND idempotency_key = $2`,
        [tenantId, idem],
      );
      if (existing.rows[0]) {
        await client.query('COMMIT');
        return this.buildResult(existing.rows[0].id, tenantId);
      }

      const ord = await client.query<{
        id: string;
        status: string;
        currency: string;
        total_minor: string;
        organizer_id: string;
        event_id: string;
        buyer_user_id: string;
        buyer_email: string;
        buyer_phone: string | null;
        buyer_first_name: string | null;
        buyer_last_name: string | null;
        buyer_display_name: string | null;
      }>(
        `SELECT tord.id, tord.status::text, tord.currency, tord.total_minor::text,
                tord.organizer_id, tord.event_id, tord.buyer_user_id,
                u.email AS buyer_email, u.phone_e164 AS buyer_phone,
                u.first_name AS buyer_first_name, u.last_name AS buyer_last_name,
                u.display_name AS buyer_display_name
         FROM ticket_orders tord
         JOIN users u ON u.id = tord.buyer_user_id
         WHERE tord.id = $1 AND tord.tenant_id = $2
         FOR UPDATE OF tord`,
        [ticketOrderId, tenantId],
      );
      const order = ord.rows[0];
      if (!order) {
        throw new UnprocessableEntityException({ code: 'ORDER_NOT_FOUND', message: 'Ticket order not found' });
      }

      if (order.status === 'fulfilled' && order.total_minor === '0') {
        await client.query('COMMIT');
        const entitlements = await this.loadEntitlements(tenantId, ticketOrderId);
        return {
          payment: {
            id: `free_${ticketOrderId}`,
            ticketOrderId,
            status: 'captured',
            currency: order.currency,
            amountExpectedMinor: '0',
            quaserReference: null,
          },
          quaser: {},
          capture: { ok: true, reason: 'free_order' },
          entitlements,
        };
      }

      if (order.status !== 'pending_payment') {
        throw new UnprocessableEntityException({
          code: 'ORDER_NOT_PAYABLE',
          message: `Order must be pending_payment (got ${order.status})`,
        });
      }

      const ins = await client.query<{ id: string }>(
        `INSERT INTO ticket_payments (
           tenant_id, ticket_order_id, provider, status, currency,
           amount_captured_minor, idempotency_key, metadata
         ) VALUES ($1, $2, 'quaser', 'initiated', $3, 0, $4, $5::jsonb)
         RETURNING id`,
        [
          tenantId,
          ticketOrderId,
          order.currency,
          idem,
          JSON.stringify({ expected_total_minor: order.total_minor }),
        ],
      );
      paymentId = ins.rows[0]!.id;
      currency = order.currency;
      totalMinor = order.total_minor;

      if (this.quasarMode.isConfigured()) {
        const phone = order.buyer_phone?.trim();
        if (!phone) {
          throw new UnprocessableEntityException({
            code: 'PHONE_REQUIRED',
            message: 'A phone number is required before a Quasar virtual account can be issued',
          });
        }
        const names = payerNames({
          firstName: order.buyer_first_name,
          lastName: order.buyer_last_name,
          displayName: order.buyer_display_name,
        });
        const account = await this.quasarAccounts.issueForTicket({
          owanbeTenantId: tenantId,
          organizerId: order.organizer_id,
          payerId: order.buyer_user_id,
          email: order.buyer_email,
          firstName: names.firstName,
          lastName: names.lastName,
          phone,
          currency,
          ticketPaymentId: paymentId,
          eventId: order.event_id,
          ticketOrderId,
          expectedTotalMinor: totalMinor,
        });
        await client.query(
          `UPDATE ticket_payments
           SET metadata = metadata || $2::jsonb,
               updated_at = now()
           WHERE id = $1`,
          [
            paymentId,
            JSON.stringify({
              initiated_at: new Date().toISOString(),
              quasar_virtual_account: {
                environment: account.environment,
                accountNumber: account.accountNumber,
                bankName: account.bankName,
                currency: account.currency,
              },
            }),
          ],
        );
      } else {
        const webhookUrl = this.publicWebhookUrl();
        if (!webhookUrl && !this.isQuaserStub()) {
          throw new UnprocessableEntityException({
            code: 'WEBHOOK_BASE_URL_MISSING',
            message: 'Set PUBLIC_API_BASE_URL for Quaser webhooks',
          });
        }

        const init = await this.quaser.initiatePayment({
          tenantId,
          paymentId,
          bookingId: ticketOrderId,
          amountMinor: totalMinor,
          currency,
          idempotencyKey: idem,
          webhookUrl: webhookUrl || 'http://localhost/dev-stub',
        });

        await client.query(
          `UPDATE ticket_payments
           SET quaser_reference = $2,
               provider_intent_ref = COALESCE(provider_intent_ref, $2),
               metadata = metadata || $3::jsonb,
               updated_at = now()
           WHERE id = $1`,
          [
            paymentId,
            init.quaserReference,
            JSON.stringify({
              quaser_init: init.raw,
              initiated_at: new Date().toISOString(),
              client_action_url: init.clientActionUrl ?? null,
            }),
          ],
        );
      }

      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }

    return this.buildResult(paymentId, tenantId, true);
  }

  private async buildResult(
    paymentId: string,
    tenantId: string,
    autoCaptureIfStub = false,
  ): Promise<CreateTicketPaymentResult> {
    const row = await this.pool.query<{
      id: string;
      ticket_order_id: string;
      status: string;
      currency: string;
      quaser_reference: string | null;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, ticket_order_id, status::text, currency, quaser_reference, metadata
       FROM ticket_payments WHERE id = $1 AND tenant_id = $2`,
      [paymentId, tenantId],
    );
    const p = row.rows[0];
    if (!p) {
      throw new ConflictException({ code: 'PAYMENT_NOT_FOUND', message: 'Payment missing' });
    }
    const meta = (p.metadata ?? {}) as Record<string, unknown>;
    const expected = String(meta.expected_total_minor ?? '0');

    let captureResult: CreateTicketPaymentResult['capture'];
    let entitlements: CreateTicketPaymentResult['entitlements'];

    const quasarAccount = virtualAccountFromMetadata(meta);
    if (autoCaptureIfStub && this.isQuaserStub() && !quasarAccount && p.status !== 'captured') {
      const cap = await this.capture.applyCapture(paymentId, {
        eventType: 'payment.captured',
        amountMinor: expected,
        payload: { stub_auto_capture: true, payment_id: paymentId, ticket_payment: true },
      });
      captureResult = { ok: cap.ok, reason: cap.reason };
      entitlements = await this.loadEntitlements(tenantId, p.ticket_order_id);
    } else if (p.status === 'captured') {
      entitlements = await this.loadEntitlements(tenantId, p.ticket_order_id);
    }

    const clientActionUrl = quasarAccount ? undefined : this.resolveClientActionUrl(meta);

    return redactQuasarSecrets({
      payment: {
        id: p.id,
        ticketOrderId: p.ticket_order_id,
        status: p.status,
        currency: p.currency,
        amountExpectedMinor: expected,
        quaserReference: p.quaser_reference,
      },
      quaser: clientActionUrl ? { clientActionUrl } : {},
      quasar: quasarAccount
        ? {
            environment: quasarAccount.environment,
            status: 'awaiting_transfer' as const,
            virtualAccount: {
              accountNumber: quasarAccount.accountNumber,
              bankName: quasarAccount.bankName,
              currency: quasarAccount.currency,
            },
          }
        : undefined,
      capture: captureResult,
      entitlements,
    });
  }

  private resolveClientActionUrl(meta: Record<string, unknown>): string | undefined {
    if (typeof meta.client_action_url === 'string' && meta.client_action_url.trim()) {
      return meta.client_action_url.trim();
    }
    const init = meta.quaser_init;
    if (init && typeof init === 'object') {
      const raw = init as Record<string, unknown>;
      const nested =
        (typeof raw.client_action_url === 'string' && raw.client_action_url) ||
        (typeof raw.checkout_url === 'string' && raw.checkout_url) ||
        '';
      if (nested.trim()) return nested.trim();
    }
    return undefined;
  }

  private async loadEntitlements(tenantId: string, orderId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      ticket_code: string;
      metadata: { qr_payload?: string; tier_name?: string };
      event_id: string;
      title: string;
      city: string | null;
      venue: string | null;
      starts_at: Date;
      issued_at: Date;
    }>(
      `SELECT te.id, te.ticket_code, te.metadata, te.event_id, te.issued_at,
              e.title, e.metadata->>'city' AS city, e.metadata->>'venue' AS venue, e.starts_at
       FROM ticket_entitlements te
       INNER JOIN events e ON e.id = te.event_id
       WHERE te.tenant_id = $1 AND te.ticket_order_id = $2`,
      [tenantId, orderId],
    );
    return rows.map((r) => ({
      id: r.id,
      ticketCode: r.ticket_code,
      qrPayload: r.metadata?.qr_payload ?? r.ticket_code,
      tierName: r.metadata?.tier_name ?? 'Ticket',
      eventId: r.event_id,
      eventTitle: r.title,
      eventCity: r.city ?? '',
      eventVenue: r.venue ?? '',
      startsAt: r.starts_at.toISOString(),
      issuedAt: r.issued_at.toISOString(),
    }));
  }
}

function virtualAccountFromMetadata(meta: Record<string, unknown>): {
  environment: 'test' | 'live';
  accountNumber: string;
  bankName: string;
  currency: string;
} | null {
  const raw = meta.quasar_virtual_account;
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const account = raw as Record<string, unknown>;
  const accountNumber = typeof account.accountNumber === 'string' ? account.accountNumber : '';
  const bankName = typeof account.bankName === 'string' ? account.bankName : '';
  const currency = typeof account.currency === 'string' ? account.currency : '';
  if (!accountNumber || !bankName || !currency) return null;
  if (accountNumber.startsWith('sk_') || accountNumber.startsWith('qps_') || accountNumber.startsWith('qpc_')) {
    return null;
  }
  return {
    environment: account.environment === 'live' ? 'live' : 'test',
    accountNumber,
    bankName,
    currency,
  };
}
