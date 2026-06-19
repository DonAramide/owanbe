import type { PoolClient } from 'pg';

/** Immutable ledger line (ledger_lines table; QFE v1.0 alias: ledger_entries). */
export interface LedgerEntrySnapshot {
  accountId: string;
  direction: 'debit' | 'credit';
  amountMinor: bigint;
  currency: string;
  memo: string;
}

export interface TreasurySettlementInput {
  client: PoolClient;
  tenantId: string;
  payoutId: string;
  bookingId: string;
  paymentId: string;
  vendorId: string;
  currency: string;
  amountMinor: bigint;
  settlementReference: string;
  webhookEventId?: string | null;
}

export interface TreasurySettlementResult {
  skipped: boolean;
  reason?: string;
  settlementReference: string;
  ledgerTransactionId?: string;
  financialTransactionId?: string;
  treasurySettlementId?: string;
  dualWriteEnabled: boolean;
  ledgerEntries?: LedgerEntrySnapshot[];
}

export interface DualWriteTreasuryContext {
  input: TreasurySettlementInput;
  escrowAccountId: string;
  vendorPayableAccountId: string;
}
