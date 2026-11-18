import { Inject, Injectable } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { QuasarClientService } from './quasar-client.service';
import { QuasarOnboardingService } from './quasar-onboarding.service';
import { readVirtualAccount } from './quasar.policy';

export interface IssuedVirtualAccount {
  accountNumber: string;
  bankName: string;
  currency: string;
  environment: 'test' | 'live';
}

@Injectable()
export class QuasarVirtualAccountService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly onboarding: QuasarOnboardingService,
    private readonly client: QuasarClientService,
  ) {}

  async issueForTicket(input: {
    owanbeTenantId: string;
    organizerId: string;
    payerId: string;
    email: string;
    firstName: string;
    lastName: string;
    phone: string;
    currency: string;
    ticketPaymentId: string;
    eventId: string;
    ticketOrderId: string;
    expectedTotalMinor: string;
  }): Promise<IssuedVirtualAccount> {
    const merchant = await this.onboarding.ensureOrganizer(input.owanbeTenantId, input.organizerId);
    const currency = input.currency.toUpperCase();
    const existing = await this.pool.query<{ account_number: string; bank_name: string }>(
      `SELECT account_number, bank_name
       FROM quasar_virtual_accounts
       WHERE merchant_account_id = $1 AND payer_id = $2 AND currency = $3`,
      [merchant.id, input.payerId, currency],
    );
    if (existing.rows[0]) {
      await this.pool.query(
        `UPDATE quasar_virtual_accounts
         SET ticket_payment_id = $2,
             metadata = metadata || $3::jsonb,
             updated_at = now()
         WHERE merchant_account_id = $1 AND payer_id = $4 AND currency = $5`,
        [
          merchant.id,
          input.ticketPaymentId,
          JSON.stringify({
            ticketPaymentId: input.ticketPaymentId,
            ticketOrderId: input.ticketOrderId,
            eventId: input.eventId,
            expectedTotalMinor: input.expectedTotalMinor,
          }),
          input.payerId,
          currency,
        ],
      );
      return {
        accountNumber: existing.rows[0].account_number,
        bankName: existing.rows[0].bank_name,
        currency,
        environment: merchant.environment,
      };
    }

    const created = await this.client.createVirtualAccount({
      apiKey: merchant.apiKey,
      payerId: input.payerId,
      idempotencyKey: `owanbe-va-${input.payerId}-${currency}`,
      body: {
        currency,
        email: input.email,
        firstName: input.firstName,
        lastName: input.lastName,
        phone: input.phone,
        merchantWalletOwnerId: merchant.walletOwnerId,
        metadata: {
          eventId: input.eventId,
          ticketId: input.ticketPaymentId,
          ticketPaymentId: input.ticketPaymentId,
          ticketOrderId: input.ticketOrderId,
          payerId: input.payerId,
          expectedTotalMinor: input.expectedTotalMinor,
        },
      },
    });
    const account = readVirtualAccount(created);
    await this.pool.query(
      `INSERT INTO quasar_virtual_accounts (
         owanbe_tenant_id, merchant_account_id, payer_id, currency, account_number, bank_name,
         provider_reference, ticket_payment_id, metadata
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb)
       ON CONFLICT (merchant_account_id, payer_id, currency)
       DO UPDATE SET ticket_payment_id = EXCLUDED.ticket_payment_id,
                     metadata = quasar_virtual_accounts.metadata || EXCLUDED.metadata,
                     updated_at = now()`,
      [
        input.owanbeTenantId,
        merchant.id,
        input.payerId,
        currency,
        account.accountNumber,
        account.bankName,
        account.reference,
        input.ticketPaymentId,
        JSON.stringify({
          ticketPaymentId: input.ticketPaymentId,
          ticketOrderId: input.ticketOrderId,
          eventId: input.eventId,
          expectedTotalMinor: input.expectedTotalMinor,
          payerId: input.payerId,
        }),
      ],
    );
    return {
      accountNumber: account.accountNumber,
      bankName: account.bankName,
      currency,
      environment: merchant.environment,
    };
  }
}
