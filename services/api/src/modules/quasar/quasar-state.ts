export type TicketReadState = 'initiated' | 'awaiting_transfer' | 'paid';

export type PayoutReadState =
  | 'pending'
  | 'awaiting_approval'
  | 'processing'
  | 'paid'
  | 'failed'
  | 'rejected';

/**
 * The create-transfer HTTP response is not confirmation.
 * A body status of SUCCESS still stays unpaid until a webhook or a later GET.
 */
export function payoutStateFromCreateResponse(quasarStatus: string): PayoutReadState {
  const status = quasarStatus.toUpperCase();
  if (status === 'FAILED') return 'failed';
  if (status === 'REJECTED') return 'rejected';
  if (status === 'PROCESSING' || status === 'PENDING') return 'processing';
  return 'awaiting_approval';
}

/** Used only for transfer.success and for GET /transfers after the create call. */
export function payoutStateFromConfirmedQuasarStatus(quasarStatus: string): PayoutReadState {
  const status = quasarStatus.toUpperCase();
  if (status === 'SUCCESS') return 'paid';
  if (status === 'FAILED') return 'failed';
  if (status === 'REJECTED') return 'rejected';
  if (status === 'PROCESSING' || status === 'PENDING') return 'processing';
  return 'awaiting_approval';
}

export function ticketStateAfterFunding(amountMatches: boolean): TicketReadState {
  return amountMatches ? 'paid' : 'awaiting_transfer';
}

export function isConfirmedInflowStatus(status: string): boolean {
  const value = status.toUpperCase();
  return value === 'SUCCESS' || value === 'CONFIRMED' || value === 'SUCCESSFUL';
}
