/**
 * Phase 5 approved finance domain — shared commerce classification.
 * Mirrors infra/db/016_phase5_ticket_commerce_foundation.sql
 */

/** Tags finance objects for unified reporting across ticket vs vendor booking rails. */
export type CommerceKind = 'TICKET' | 'BOOKING' | 'REFUND' | 'PAYOUT' | 'SETTLEMENT';

export const COMMERCE_KIND = {
  TICKET: 'TICKET',
  BOOKING: 'BOOKING',
  REFUND: 'REFUND',
  PAYOUT: 'PAYOUT',
  SETTLEMENT: 'SETTLEMENT',
} as const satisfies Record<string, CommerceKind>;

export type OrganizerStatus = 'draft' | 'active' | 'suspended' | 'closed';

export type EventStatus = 'draft' | 'published' | 'live' | 'completed' | 'cancelled';

export type TicketOrderStatus =
  | 'draft'
  | 'pending_payment'
  | 'confirmed'
  | 'fulfilled'
  | 'cancelled'
  | 'partially_refunded'
  | 'refunded';

export type TicketEntitlementStatus = 'issued' | 'checked_in' | 'voided' | 'refunded';

export type TicketRefundStatus =
  | 'requested'
  | 'under_review'
  | 'approved'
  | 'processing'
  | 'completed'
  | 'rejected';

/** Ledger transaction reasons — ticket rail (Phase 5.1+). */
export type TicketLedgerReason =
  | 'payment_capture_ticket'
  | 'platform_fee_recognition_ticket'
  | 'organizer_share_accrual'
  | 'payment_refund_ticket'
  | 'platform_fee_reversal_ticket'
  | 'payout_organizer_release'
  | 'payout_organizer_transfer';

/** Approved MVP fee defaults (stored in tenant_finance_settings, not hardcoded at runtime). */
export const FINANCE_POLICY_DEFAULTS = {
  ticketPlatformFeeBps: 500,
  vendorPlatformFeeBps: 1000,
  escrowReleaseDelayHours: 48,
} as const;

export interface TenantFinancePolicy {
  tenantId: string;
  ticketPlatformFeeBps: number;
  vendorPlatformFeeBps: number;
  escrowReleaseDelayHours: number;
}

/** Compute platform fee from subtotal using tenant bps (integer math, no floats). */
export function computePlatformFeeMinor(subtotalMinor: number, feeBps: number): number {
  if (subtotalMinor <= 0 || feeBps <= 0) return 0;
  return Math.floor((subtotalMinor * feeBps) / 10_000);
}

/**
 * Proportional platform fee reversal on partial refund (approved policy).
 * full refund → reverse entire platform fee; partial → proportional.
 */
export function computeFeeReversalMinor(
  refundMinor: number,
  capturedMinor: number,
  platformFeeMinor: number,
): number {
  if (refundMinor <= 0 || capturedMinor <= 0 || platformFeeMinor <= 0) return 0;
  if (refundMinor >= capturedMinor) return platformFeeMinor;
  return Math.floor((platformFeeMinor * refundMinor) / capturedMinor);
}

/** Standard ledger account codes for organizer finance. */
export function organizerPayableAccountCode(organizerId: string): string {
  return `organizer_payable_${organizerId}`;
}

export function organizerPayoutClearingAccountCode(currency: string): string {
  return `organizer_payout_clearing_${currency}`;
}
