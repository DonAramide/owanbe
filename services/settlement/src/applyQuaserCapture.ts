import type { PoolClient } from 'pg';

export type ApplyCaptureParams = {
  paymentId: string;
  tenantId: string;
  /** maps to payment_provider enum */
  provider: 'paystack' | 'flutterwave' | 'internal';
  routerEventId: string;
  eventType: string;
  payload: Record<string, unknown>;
  pspClearingAccountId: string;
  escrowAccountId: string;
  platformFeesAccountId: string;
  grossMinor: string | number;
  feeMinor: string | number;
};

export type ApplyCaptureResult =
  | { skipped: true; reason: string; status?: string }
  | { skipped: false; reason: string; ledger_transaction_id: string; payment_id: string }
  | { skipped: false; error: string };

/**
 * Calls DB function owanbe_apply_quaser_payment_capture inside an optional outer transaction.
 * Caller should BEGIN and pass client for webhook handler atomicity with other writes.
 */
export async function applyQuaserPaymentCapture(
  client: PoolClient,
  p: ApplyCaptureParams
): Promise<ApplyCaptureResult> {
  const { rows } = await client.query(
    `SELECT owanbe_apply_quaser_payment_capture(
       $1::uuid, $2::uuid, $3::payment_provider, $4::text, $5::text, $6::jsonb,
       $7::uuid, $8::uuid, $9::uuid, $10::bigint, $11::bigint
     ) AS result`,
    [
      p.paymentId,
      p.tenantId,
      p.provider,
      p.routerEventId,
      p.eventType,
      JSON.stringify(p.payload),
      p.pspClearingAccountId,
      p.escrowAccountId,
      p.platformFeesAccountId,
      BigInt(p.grossMinor),
      BigInt(p.feeMinor),
    ]
  );
  const result = rows[0]?.result as ApplyCaptureResult;
  return result;
}

/** Structured logs for services / log aggregation */
export function logSettlement(result: ApplyCaptureResult, reference: string): void {
  if ('error' in result && result.error) {
    console.log(JSON.stringify({ level: 'error', msg: 'ledger_error', reference, ...result }));
    return;
  }
  if (result.skipped) {
    console.log(
      JSON.stringify({
        level: 'info',
        msg: 'ledger_skip',
        reference,
        reason: result.reason,
        skipped: true,
      })
    );
    return;
  }
  console.log(
    JSON.stringify({
      level: 'info',
      msg: 'ledger_write',
      reference,
      status: 'succeeded',
      ledger_transaction_id: 'ledger_transaction_id' in result ? result.ledger_transaction_id : undefined,
    })
  );
}
