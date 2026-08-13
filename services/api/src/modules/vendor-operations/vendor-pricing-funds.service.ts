import { BadRequestException, Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import { LedgerService } from '../payments/ledger.service';
import {
  resolveMarkupFromRules,
  type MarkupResolution,
  type PricingRuleRow,
} from './vendor-pricing.util';

@Injectable()
export class VendorPricingRulesService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Load tenant pricing rules once (safe for batch marketplace pricing).
   * Does not mutate historical vendor_event_requests / funding rows.
   */
  async listRuleRows(tenantId: string): Promise<PricingRuleRow[]> {
    const { rows } = await this.pool.query<PricingRuleRow>(
      `SELECT vendor_id, service_key, markup_bps, is_default
       FROM platform_vendor_pricing_rules
       WHERE tenant_id = $1`,
      [tenantId],
    );
    return rows;
  }

  /**
   * Deterministic hierarchy:
   * vendor+service → vendor → service → default → 4000 bps.
   * Optional vendorId must be vendors.id (never users.id).
   */
  async resolveMarkupDecision(
    tenantId: string,
    serviceKey: string | null,
    vendorId?: string | null,
  ): Promise<MarkupResolution> {
    const rules = await this.listRuleRows(tenantId);
    return resolveMarkupFromRules(rules, serviceKey, vendorId ?? null);
  }

  async resolveMarkupBps(
    tenantId: string,
    serviceKey: string | null,
    vendorId?: string | null,
  ): Promise<number> {
    const decision = await this.resolveMarkupDecision(tenantId, serviceKey, vendorId);
    return decision.markupBps;
  }
}

@Injectable()
export class EventVendorFundsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly ledger: LedgerService,
  ) {}

  async getSummary(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertEventCapability(
      actor.tenantId,
      actor.userId,
      eventKey,
      'vendors.read',
    );
    const { rows: fundRows } = await this.pool.query<{
      total_funded_minor: string;
      currency: string;
    }>(
      `SELECT total_funded_minor::text, currency FROM event_vendor_funds
       WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );
    const total = BigInt(fundRows[0]?.total_funded_minor ?? '0');
    const { rows: alloc } = await this.pool.query<{
      amount_minor: string;
      status: string;
    }>(
      `SELECT amount_minor::text, status FROM vendor_request_fund_allocations
       WHERE tenant_id = $1 AND event_id = $2 AND status IN ('reserved', 'funded', 'released', 'held')`,
      [actor.tenantId, event.id],
    );
    let reserved = 0n;
    let released = 0n;
    for (const a of alloc) {
      const amt = BigInt(a.amount_minor);
      if (a.status === 'released') released += amt;
      else reserved += amt;
    }
    const remaining = total - reserved - released;
    return {
      eventId: event.id,
      currency: fundRows[0]?.currency ?? 'NGN',
      totalFundedMinor: total.toString(),
      allocatedMinor: (reserved + released).toString(),
      reservedMinor: reserved.toString(),
      releasedMinor: released.toString(),
      remainingMinor: (remaining < 0n ? 0n : remaining).toString(),
    };
  }

  /** Organizer tops up event vendor funds (ledger of record for CRM allocations). */
  async fundEvent(actor: CommerceActor, eventKey: string, amountMinor: number) {
    if (!Number.isFinite(amountMinor) || amountMinor <= 0) {
      throw new BadRequestException({ code: 'AMOUNT_REQUIRED', message: 'amountMinor must be > 0' });
    }
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.pool.query(
      `INSERT INTO event_vendor_funds (tenant_id, event_id, total_funded_minor)
       VALUES ($1, $2, $3::bigint)
       ON CONFLICT (event_id) DO UPDATE
         SET total_funded_minor = event_vendor_funds.total_funded_minor + EXCLUDED.total_funded_minor,
             updated_at = now()`,
      [actor.tenantId, event.id, String(amountMinor)],
    );
    return this.getSummary(actor, event.id);
  }

  async reserveForRequest(actor: CommerceActor, requestId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      organizer_id: string;
      customer_price_minor: string | null;
      funding_status: string;
      stage: string;
    }>(
      `SELECT id, event_id, organizer_id, customer_price_minor::text, funding_status, stage
       FROM vendor_event_requests WHERE tenant_id = $1 AND id = $2`,
      [actor.tenantId, requestId],
    );
    const row = rows[0];
    if (!row) throw new NotFoundException({ code: 'REQUEST_NOT_FOUND' });
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    if (!row.customer_price_minor) {
      throw new BadRequestException({
        code: 'PRICE_REQUIRED',
        message: 'Confirm agreement with a customer price before funding',
      });
    }
    const price = BigInt(row.customer_price_minor);
    const summary = await this.getSummary(actor, row.event_id);
    const remaining = BigInt(summary.remainingMinor);
    if (remaining < price) {
      await this.pool.query(
        `UPDATE vendor_event_requests SET funding_status = 'insufficient', updated_at = now()
         WHERE id = $1`,
        [requestId],
      );
      throw new BadRequestException({
        code: 'INSUFFICIENT_EVENT_FUNDS',
        message: 'Insufficient event funds.',
        remainingMinor: remaining.toString(),
        requiredMinor: price.toString(),
      });
    }
    await this.pool.query(
      `INSERT INTO vendor_request_fund_allocations (tenant_id, event_id, request_id, amount_minor, status)
       VALUES ($1, $2, $3, $4::bigint, 'funded')
       ON CONFLICT (request_id) DO UPDATE
         SET amount_minor = EXCLUDED.amount_minor, status = 'funded', updated_at = now()`,
      [actor.tenantId, row.event_id, requestId, price.toString()],
    );
    await this.pool.query(
      `UPDATE vendor_event_requests SET funding_status = 'funded', updated_at = now() WHERE id = $1`,
      [requestId],
    );
    return {
      requestId,
      fundingStatus: 'funded',
      escrowAmountMinor: price.toString(),
      eventFunds: await this.getSummary(actor, row.event_id),
    };
  }

  async releaseOnCompletion(actor: CommerceActor, requestId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      vendor_id: string;
      vendor_payout_minor: string | null;
      customer_price_minor: string | null;
      platform_margin_minor: string | null;
      funding_status: string;
    }>(
      `SELECT id, event_id, vendor_id, vendor_payout_minor::text, customer_price_minor::text,
              platform_margin_minor::text, funding_status
       FROM vendor_event_requests WHERE tenant_id = $1 AND id = $2`,
      [actor.tenantId, requestId],
    );
    const row = rows[0];
    if (!row) throw new NotFoundException({ code: 'REQUEST_NOT_FOUND' });
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    if (row.funding_status !== 'funded' && row.funding_status !== 'held') {
      throw new BadRequestException({ code: 'NOT_FUNDED', message: 'Booking is not in funded escrow' });
    }
    const payoutMinor = BigInt(row.vendor_payout_minor ?? '0');
    if (payoutMinor <= 0n) {
      throw new BadRequestException({
        code: 'PAYOUT_REQUIRED',
        message: 'Vendor payout amount missing for release',
      });
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `UPDATE vendor_request_fund_allocations SET status = 'released', updated_at = now()
         WHERE tenant_id = $1 AND request_id = $2`,
        [actor.tenantId, requestId],
      );
      await client.query(
        `UPDATE vendor_event_requests
         SET funding_status = 'released', completion_confirmed_at = now(), updated_at = now()
         WHERE id = $1`,
        [requestId],
      );

      // Credit vendor_payable via existing escrow → vendor ledger path (idempotent by request).
      const currency = 'NGN';
      const pools = await this.ledger.ensurePoolLedgerAccounts(client, actor.tenantId, currency);
      const vendorPayableId = await this.ledger.ensureVendorPayableAccount(
        client,
        actor.tenantId,
        row.vendor_id,
        currency,
      );
      const idem = `vendor_commerce_release:${requestId}`;
      const ins = await client.query<{ id: string }>(
        `INSERT INTO ledger_transactions (tenant_id, booking_id, payment_id, idempotency_key, reason)
         VALUES ($1, NULL, NULL, $2, 'vendor_commerce_escrow_release')
         ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
         RETURNING id`,
        [actor.tenantId, idem],
      );
      let txnId = ins.rows[0]?.id;
      if (!txnId) {
        const ex = await client.query<{ id: string }>(
          `SELECT id FROM ledger_transactions WHERE tenant_id = $1 AND idempotency_key = $2`,
          [actor.tenantId, idem],
        );
        txnId = ex.rows[0]?.id;
      }
      if (!txnId) throw new Error('vendor commerce release ledger txn missing');
      const { rows: lineCount } = await client.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM ledger_lines WHERE transaction_id = $1`,
        [txnId],
      );
      if (lineCount[0]?.n === '0') {
        const amt = payoutMinor.toString();
        await client.query(
          `INSERT INTO ledger_lines (transaction_id, account_id, direction, amount_minor, currency, memo)
           VALUES
             ($1, $2, 'debit', $3::bigint, $4, 'vendor commerce escrow release'),
             ($1, $5, 'credit', $3::bigint, $4, 'vendor payable from booking')`,
          [txnId, pools.escrowPoolId, amt, currency, vendorPayableId],
        );
      }
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }

    // Vendor payout amount is recorded on the request; spendable wallet credit
    // is now in vendor_payable via vendor_commerce_escrow_release ledger lines.
    return {
      requestId,
      fundingStatus: 'released',
      vendorPayoutMinor: row.vendor_payout_minor,
      released: true,
    };
  }

  async holdOnIssue(actor: CommerceActor, requestId: string) {
    const { rows } = await this.pool.query<{ event_id: string }>(
      `SELECT event_id FROM vendor_event_requests WHERE tenant_id = $1 AND id = $2`,
      [actor.tenantId, requestId],
    );
    if (!rows[0]) throw new NotFoundException({ code: 'REQUEST_NOT_FOUND' });
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, rows[0].event_id);
    await this.pool.query(
      `UPDATE vendor_request_fund_allocations SET status = 'held', updated_at = now()
       WHERE tenant_id = $1 AND request_id = $2`,
      [actor.tenantId, requestId],
    );
    await this.pool.query(
      `UPDATE vendor_event_requests SET funding_status = 'held', updated_at = now() WHERE id = $1`,
      [requestId],
    );
    return { requestId, fundingStatus: 'held' };
  }
}
