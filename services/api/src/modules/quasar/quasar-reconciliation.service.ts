import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';
import { TicketCaptureService } from '../commerce/ticket-capture.service';
import { OrganizerPayoutService } from '../commerce/organizer-payout.service';
import { QuasarAuditService } from './quasar-audit.service';
import { QuasarHttpClient } from './quasar-client.service';
import { QuasarModeService } from './quasar-mode.service';
import { QuasarVaultService } from './quasar-vault.service';
import { isConfirmedInflowStatus, payoutStateFromConfirmedQuasarStatus, ticketStateAfterFunding } from './quasar-state';
import { minorUnitsFromQuasarAmount, pickString } from './quasar.policy';

/**
 * Polls Quasar for confirmed inflows and transfer status.
 * Create-transfer HTTP 201 never marks a payout paid. GET SUCCESS does.
 */
@Injectable()
export class QuasarReconciliationService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(QuasarReconciliationService.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly mode: QuasarModeService,
    private readonly client: QuasarHttpClient,
    private readonly vault: QuasarVaultService,
    private readonly audit: QuasarAuditService,
    @Inject(forwardRef(() => TicketCaptureService))
    private readonly ticketCapture: TicketCaptureService,
    @Inject(forwardRef(() => OrganizerPayoutService))
    private readonly organizerPayout: OrganizerPayoutService,
  ) {}

  onModuleInit() {
    const interval = this.config.get('QUASAR_RECONCILE_MS', { infer: true });
    if (!interval || interval < 10_000) return;
    this.timer = setInterval(() => {
      this.runOnce().catch((error) => this.logger.warn({ message: (error as Error).message }, 'Quasar reconcile failed'));
    }, interval);
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async runOnce(): Promise<{ transfers: number; payments: number }> {
    if (!this.mode.isConfigured()) return { transfers: 0, payments: 0 };
    const transfers = await this.syncTransfers();
    const payments = await this.syncPayments();
    return { transfers, payments };
  }

  private async syncTransfers(): Promise<number> {
    const { rows } = await this.pool.query<{
      reference: string;
      organizer_payout_id: string;
      quasar_tenant_id: string;
      owanbe_tenant_id: string;
    }>(
      `SELECT t.reference, t.organizer_payout_id, m.quasar_tenant_id, t.owanbe_tenant_id
       FROM quasar_transfers t
       JOIN quasar_merchant_accounts m ON m.id = t.merchant_account_id
       JOIN organizer_payouts p ON p.id = t.organizer_payout_id
       WHERE p.status::text IN ('pending', 'processing')
         AND t.organizer_payout_id IS NOT NULL
       LIMIT 50`,
    );
    let changed = 0;
    for (const row of rows) {
      const merchant = await this.vault.findByQuasarTenantId(row.quasar_tenant_id);
      if (!merchant) continue;
      const remote = await this.client.getTransfer(merchant.apiKey, row.reference);
      const status = (pickString(remote, ['status']) ?? 'AWAITING_APPROVAL').toUpperCase();
      const next = payoutStateFromConfirmedQuasarStatus(status);
      await this.pool.query(
        `UPDATE quasar_transfers SET quasar_status = $2, updated_at = now()
         WHERE reference = $1 AND merchant_account_id = $3`,
        [row.reference, status, merchant.id],
      );
      if (next === 'paid') {
        await this.organizerPayout.completePayout(row.organizer_payout_id, {
          source: 'quasar_reconcile',
          quasarStatus: status,
        });
        changed += 1;
      } else if (next === 'failed' || next === 'rejected') {
        await this.organizerPayout.markTransferFailed(
          row.organizer_payout_id,
          { source: 'quasar_reconcile', quasarStatus: status },
          next === 'rejected' ? 'QUASAR_TRANSFER_REJECTED' : 'QUASAR_TRANSFER_FAILED',
        );
        changed += 1;
      }
      await this.audit.record({
        owanbeTenantId: row.owanbe_tenant_id,
        action: 'transfer.sync',
        outcome: next,
        reference: row.reference,
        detail: { quasarStatus: status },
      });
    }
    return changed;
  }

  private async syncPayments(): Promise<number> {
    const { rows } = await this.pool.query<{
      ticket_payment_id: string;
      payer_id: string;
      expected_minor: string;
      quasar_tenant_id: string;
      owanbe_tenant_id: string;
    }>(
      `SELECT tp.id AS ticket_payment_id, va.payer_id,
              COALESCE(tp.metadata->>'expected_total_minor', '0') AS expected_minor,
              m.quasar_tenant_id, tp.tenant_id AS owanbe_tenant_id
       FROM ticket_payments tp
       JOIN quasar_virtual_accounts va ON va.ticket_payment_id = tp.id
       JOIN quasar_merchant_accounts m ON m.id = va.merchant_account_id
       WHERE tp.status::text = 'initiated'
       LIMIT 50`,
    );
    let changed = 0;
    for (const row of rows) {
      const merchant = await this.vault.findByQuasarTenantId(row.quasar_tenant_id);
      if (!merchant) continue;
      const remote = await this.client.listPayerPayments(merchant.apiKey, row.payer_id);
      const matched = inflowMatches(remote, row.expected_minor);
      const next = ticketStateAfterFunding(matched);
      await this.audit.record({
        owanbeTenantId: row.owanbe_tenant_id,
        action: 'payment.reconcile',
        outcome: next,
        reference: row.ticket_payment_id,
        detail: { amountMatches: matched },
      });
      if (next !== 'paid') continue;
      await this.ticketCapture.applyCapture(row.ticket_payment_id, {
        eventType: 'quasar.inflow.confirmed',
        amountMinor: row.expected_minor,
        payload: { source: 'quasar_reconcile' },
      });
      changed += 1;
    }
    return changed;
  }
}

function inflowMatches(data: Record<string, unknown>, expectedMinor: string): boolean {
  const items = Array.isArray(data.items) ? data.items : Array.isArray(data.payments) ? data.payments : [];
  return items.some((item) => {
    if (!item || typeof item !== 'object') return false;
    const row = item as Record<string, unknown>;
    const status = pickString(row, ['status']) ?? '';
    if (!isConfirmedInflowStatus(status)) return false;
    return minorUnitsFromQuasarAmount(row) === expectedMinor;
  });
}
