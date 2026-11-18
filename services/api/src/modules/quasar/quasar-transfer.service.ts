import { Inject, Injectable, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { QuasarClientService } from './quasar-client.service';
import { QuasarOnboardingService } from './quasar-onboarding.service';
import { majorAmountFromMinor, readTransferStatus } from './quasar.policy';
import type { QuasarBankDestination } from './quasar.types';

@Injectable()
export class QuasarTransferService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly onboarding: QuasarOnboardingService,
    private readonly client: QuasarClientService,
  ) {}

  async createOrganizerWithdrawal(input: {
    owanbeTenantId: string;
    organizerId: string;
    payoutId: string;
    amountMinor: string;
    currency: string;
    destination: QuasarBankDestination;
  }): Promise<{ reference: string; status: string; environment: 'test' }> {
    this.assertDestination(input.destination);
    const merchant = await this.onboarding.ensureOrganizer(input.owanbeTenantId, input.organizerId);
    if (merchant.environment !== 'test') {
      throw new UnprocessableEntityException({
        code: 'QUASAR_LIVE_DISABLED',
        message: 'Live Quasar tenants are disabled',
      });
    }
    const reference = `owanbe_payout_${input.payoutId}`;
    const replay = await this.pool.query<{ response: { reference?: string; status?: string } }>(
      `SELECT response FROM quasar_idempotency_keys
       WHERE merchant_account_id = $1 AND scope = 'transfer' AND idempotency_key = $2`,
      [merchant.id, reference],
    );
    const replayed = replay.rows[0]?.response;
    if (replayed?.reference && replayed.status) {
      return { reference: replayed.reference, status: replayed.status, environment: 'test' };
    }
    const amount = majorAmountFromMinor(input.amountMinor);
    const currency = input.currency.toUpperCase();
    const created = await this.client.createTransfer({
      apiKey: merchant.apiKey,
      idempotencyKey: reference,
      body: {
        amount,
        currency,
        reference,
        destination: {
          account_number: input.destination.accountNumber,
          bank_code: input.destination.bankCode,
          account_name: input.destination.accountName,
        },
        metadata: {
          tenantId: merchant.quasarTenantId,
          schoolId: merchant.walletOwnerId,
        },
      },
    });
    const transfer = readTransferStatus(created, reference);
    await this.pool.query(
      `INSERT INTO quasar_transfers (
         owanbe_tenant_id, merchant_account_id, organizer_payout_id, reference,
         amount_major, currency, quasar_status, destination
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
       ON CONFLICT (merchant_account_id, reference)
       DO UPDATE SET quasar_status = EXCLUDED.quasar_status, updated_at = now()`,
      [
        input.owanbeTenantId,
        merchant.id,
        input.payoutId,
        transfer.reference,
        amount,
        currency,
        transfer.status,
        JSON.stringify({
          account_number: input.destination.accountNumber,
          bank_code: input.destination.bankCode,
          account_name: input.destination.accountName,
        }),
      ],
    );
    await this.pool.query(
      `INSERT INTO quasar_idempotency_keys (merchant_account_id, scope, idempotency_key, response)
       VALUES ($1, 'transfer', $2, $3::jsonb)
       ON CONFLICT (merchant_account_id, scope, idempotency_key) DO NOTHING`,
      [merchant.id, reference, JSON.stringify({ reference: transfer.reference, status: transfer.status })],
    );
    return { reference: transfer.reference, status: transfer.status, environment: 'test' as const };
  }

  private assertDestination(destination: QuasarBankDestination) {
    if (!/^\d{10}$/.test(destination.accountNumber)) {
      throw new UnprocessableEntityException({
        code: 'QUASAR_DESTINATION_REQUIRED',
        message: 'Withdrawal account number must be 10 digits',
      });
    }
    if (!destination.bankCode.trim() || !destination.accountName.trim()) {
      throw new UnprocessableEntityException({
        code: 'QUASAR_DESTINATION_REQUIRED',
        message: 'Withdrawal bank code and account name are required',
      });
    }
  }
}
