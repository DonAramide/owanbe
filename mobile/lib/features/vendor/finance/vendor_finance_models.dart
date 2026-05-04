class VendorSummaryTotals {
  const VendorSummaryTotals({
    required this.availableBalanceMinor,
    required this.pendingEarningsMinor,
    required this.underReviewAmountMinor,
    required this.totalEarningsMinor,
  });

  final String availableBalanceMinor;
  final String pendingEarningsMinor;
  final String underReviewAmountMinor;
  final String totalEarningsMinor;

  factory VendorSummaryTotals.fromJson(Map<String, dynamic> json) {
    return VendorSummaryTotals(
      availableBalanceMinor: (json['available_balance'] ?? json['availableBalanceMinor'] ?? '0').toString(),
      pendingEarningsMinor: (json['pending_earnings'] ?? json['pendingEarningsMinor'] ?? '0').toString(),
      underReviewAmountMinor: (json['under_review_amount'] ?? json['underReviewAmountMinor'] ?? '0').toString(),
      totalEarningsMinor: (json['total_earnings'] ?? json['totalEarningsMinor'] ?? '0').toString(),
    );
  }
}

class VendorSummaryResponse {
  const VendorSummaryResponse({
    required this.totals,
    required this.items,
  });

  final VendorSummaryTotals totals;
  final List<Map<String, dynamic>> items;

  factory VendorSummaryResponse.fromJson(Map<String, dynamic> json) {
    final totalsJson = (json['totals'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    final itemsRaw = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    return VendorSummaryResponse(
      totals: VendorSummaryTotals.fromJson(totalsJson),
      items: itemsRaw,
    );
  }
}

class VendorFinanceTransaction {
  const VendorFinanceTransaction({
    required this.type,
    required this.status,
    required this.amountMinor,
    required this.bookingReference,
    required this.timestampMs,
    this.reason,
  });

  final String type;
  final String status;
  final String amountMinor;
  final String bookingReference;
  final int timestampMs;
  final String? reason;

  factory VendorFinanceTransaction.fromJson(Map<String, dynamic> json) {
    return VendorFinanceTransaction(
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amountMinor: (json['amount'] ?? json['amountMinor'] ?? '0').toString(),
      bookingReference: (json['booking_reference'] ?? json['bookingReference'] ?? '-').toString(),
      timestampMs: (json['timestampMs'] as num?)?.toInt() ??
          DateTime.tryParse((json['occurredAt'] ?? '').toString())?.millisecondsSinceEpoch ??
          0,
      reason: json['reason']?.toString(),
    );
  }
}

class VendorTransactionsResponse {
  const VendorTransactionsResponse({required this.items});
  final List<VendorFinanceTransaction> items;

  factory VendorTransactionsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(VendorFinanceTransaction.fromJson)
        .toList();
    return VendorTransactionsResponse(items: list);
  }
}

class VendorPayoutResult {
  const VendorPayoutResult({
    required this.ok,
    required this.requestedMinor,
    required this.payoutCount,
  });

  final bool ok;
  final String requestedMinor;
  final int payoutCount;

  factory VendorPayoutResult.fromJson(Map<String, dynamic> json) {
    final payouts = (json['payouts'] as List<dynamic>? ?? const <dynamic>[]);
    return VendorPayoutResult(
      ok: json['ok'] == true,
      requestedMinor: (json['requestedMinor'] ?? '0').toString(),
      payoutCount: payouts.length,
    );
  }
}

class VendorFinanceApiException implements Exception {
  VendorFinanceApiException({
    required this.code,
    required this.message,
    this.suggestionsMinor = const [],
  });

  final String code;
  final String message;
  final List<String> suggestionsMinor;

  @override
  String toString() => '$code: $message';
}
