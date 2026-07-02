/// Native Event OS finance models (Customer Portal).
class CustomerEventFinanceSummary {
  const CustomerEventFinanceSummary({
    required this.eventId,
    required this.eventTitle,
    required this.organizerId,
    required this.currency,
    required this.ticketRevenueMinor,
    required this.platformFeeMinor,
    required this.grossCollectedMinor,
    required this.netEarningsMinor,
    required this.heldInEscrowMinor,
    required this.availableForPayoutMinor,
    required this.pendingPayoutMinor,
    required this.openRefundRequests,
    required this.fulfilledOrderCount,
    required this.payoutEligible,
    this.payoutEligibilityReason,
  });

  final String eventId;
  final String eventTitle;
  final String organizerId;
  final String currency;
  final String ticketRevenueMinor;
  final String platformFeeMinor;
  final String grossCollectedMinor;
  final String netEarningsMinor;
  final String heldInEscrowMinor;
  final String availableForPayoutMinor;
  final String pendingPayoutMinor;
  final int openRefundRequests;
  final int fulfilledOrderCount;
  final bool payoutEligible;
  final String? payoutEligibilityReason;

  factory CustomerEventFinanceSummary.fromJson(Map<String, dynamic> json) {
    return CustomerEventFinanceSummary(
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String,
      organizerId: json['organizerId'] as String,
      currency: json['currency'] as String? ?? 'NGN',
      ticketRevenueMinor: (json['ticketRevenueMinor'] ?? '0').toString(),
      platformFeeMinor: (json['platformFeeMinor'] ?? '0').toString(),
      grossCollectedMinor: (json['grossCollectedMinor'] ?? '0').toString(),
      netEarningsMinor: (json['netEarningsMinor'] ?? '0').toString(),
      heldInEscrowMinor: (json['heldInEscrowMinor'] ?? '0').toString(),
      availableForPayoutMinor: (json['availableForPayoutMinor'] ?? '0').toString(),
      pendingPayoutMinor: (json['pendingPayoutMinor'] ?? '0').toString(),
      openRefundRequests: (json['openRefundRequests'] as num?)?.toInt() ?? 0,
      fulfilledOrderCount: (json['fulfilledOrderCount'] as num?)?.toInt() ?? 0,
      payoutEligible: json['payoutEligible'] == true,
      payoutEligibilityReason: json['payoutEligibilityReason'] as String?,
    );
  }
}

class CustomerFinanceTransaction {
  const CustomerFinanceTransaction({
    required this.type,
    required this.status,
    required this.amountMinor,
    required this.currency,
    required this.timestampMs,
    this.ticketOrderId,
    this.description,
  });

  final String type;
  final String status;
  final String amountMinor;
  final String currency;
  final int timestampMs;
  final String? ticketOrderId;
  final String? description;

  factory CustomerFinanceTransaction.fromJson(Map<String, dynamic> json) {
    return CustomerFinanceTransaction(
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amountMinor: (json['amountMinor'] ?? '0').toString(),
      currency: (json['currency'] ?? 'NGN').toString(),
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
      ticketOrderId: json['ticketOrderId']?.toString(),
      description: json['description']?.toString(),
    );
  }
}
