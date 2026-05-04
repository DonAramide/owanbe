class AdminFinanceApiException implements Exception {
  AdminFinanceApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.total,
    required this.totalPages,
    required this.page,
    required this.limit,
  });
  final List<T> items;
  final int total;
  final int totalPages;
  final int page;
  final int limit;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final raw = (json['items'] as List<dynamic>? ?? const []);
    return PaginatedResponse<T>(
      items: raw.whereType<Map<String, dynamic>>().map(fromItem).toList(),
      total: int.tryParse((json['total'] ?? '0').toString()) ?? 0,
      page: int.tryParse((json['page'] ?? '1').toString()) ?? 1,
      totalPages: int.tryParse((json['totalPages'] ?? '1').toString()) ?? 1,
      limit: int.tryParse((json['limit'] ?? '20').toString()) ?? 20,
    );
  }
}
typedef AdminPage<T> = PaginatedResponse<T>;

class AdminFinanceSummary {
  const AdminFinanceSummary({
    required this.totalVolumeMinor,
    required this.escrowBalanceMinor,
    required this.pendingPayoutMinor,
    required this.underReviewMinor,
    required this.failedCount,
    required this.failedMinor,
  });
  final String totalVolumeMinor;
  final String escrowBalanceMinor;
  final String pendingPayoutMinor;
  final String underReviewMinor;
  final String failedCount;
  final String failedMinor;

  factory AdminFinanceSummary.fromJson(Map<String, dynamic> json) => AdminFinanceSummary(
        totalVolumeMinor: (json['totalVolumeMinor'] ?? '0').toString(),
        escrowBalanceMinor: (json['escrowBalanceMinor'] ?? '0').toString(),
        pendingPayoutMinor: (json['pendingPayoutMinor'] ?? '0').toString(),
        underReviewMinor: (json['underReviewMinor'] ?? '0').toString(),
        failedCount: (json['failedCount'] ?? '0').toString(),
        failedMinor: (json['failedMinor'] ?? '0').toString(),
      );
}

class AdminAlertItem {
  const AdminAlertItem({
    required this.type,
    required this.count,
    required this.severity,
    required this.latestOccurrence,
  });
  final String type;
  final int count;
  final String severity;
  final DateTime latestOccurrence;

  factory AdminAlertItem.fromJson(Map<String, dynamic> json) => AdminAlertItem(
        type: (json['type'] ?? '').toString(),
        count: int.tryParse((json['count'] ?? '0').toString()) ?? 0,
        severity: (json['severity'] ?? 'WARNING').toString(),
        latestOccurrence:
            DateTime.tryParse((json['latest_occurrence'] ?? '').toString()) ?? DateTime.now(),
      );
}

class AdminTxItem {
  const AdminTxItem({
    required this.id,
    required this.user,
    required this.amount,
    required this.amountMinor,
    required this.type,
    required this.status,
    required this.sourceType,
    required this.createdAt,
    this.bookingId,
    this.bookingReference,
  });
  final String id;
  final String user;
  final int amount;
  final String amountMinor;
  final String type;
  final String status;
  final String sourceType;
  final DateTime createdAt;
  final String? bookingId;
  final String? bookingReference;

  factory AdminTxItem.fromJson(Map<String, dynamic> json) => AdminTxItem(
        id: (json['transaction_id'] ?? '').toString(),
        user: (json['user_label'] ?? '-').toString(),
        amount: int.tryParse((json['amount'] ?? json['amount_minor'] ?? '0').toString()) ?? 0,
        amountMinor: (json['amount_minor'] ?? '0').toString(),
        type: (json['type'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        sourceType: (json['source_type'] ?? json['type'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
        bookingId: json['booking_id']?.toString(),
        bookingReference: json['booking_reference']?.toString(),
      );
}

class AdminPayoutItem {
  const AdminPayoutItem({
    required this.id,
    required this.vendorId,
    required this.amountMinor,
    required this.status,
    required this.createdAt,
    this.bookingId,
    this.paymentId,
    this.currency,
    this.failureCode,
    this.failureMessage,
    this.underReview = false,
  });
  final String id;
  final String vendorId;
  final String amountMinor;
  final String status;
  final DateTime createdAt;
  final String? bookingId;
  final String? paymentId;
  final String? currency;
  final String? failureCode;
  final String? failureMessage;
  final bool underReview;

  factory AdminPayoutItem.fromJson(Map<String, dynamic> json) => AdminPayoutItem(
        id: (json['id'] ?? '').toString(),
        vendorId: (json['vendor_id'] ?? '-').toString(),
        amountMinor: (json['amount_minor'] ?? '0').toString(),
        status: (json['status'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
        bookingId: json['booking_id']?.toString(),
        paymentId: json['payment_id']?.toString(),
        currency: json['currency']?.toString(),
        failureCode: json['failure_code']?.toString(),
        failureMessage: json['failure_message']?.toString(),
        underReview: json['under_review'] == true,
      );
}

class AdminReviewItem {
  const AdminReviewItem({
    required this.paymentId,
    required this.amountMinor,
    required this.reason,
    required this.bookingId,
  });
  final String paymentId;
  final String amountMinor;
  final String reason;
  final String bookingId;

  factory AdminReviewItem.fromJson(Map<String, dynamic> json) => AdminReviewItem(
        paymentId: (json['payment_id'] ?? '').toString(),
        amountMinor: (json['amount_minor'] ?? '0').toString(),
        reason: (json['reason'] ?? 'manual_review').toString(),
        bookingId: (json['booking_id'] ?? '-').toString(),
      );
}

class AdminReconItem {
  const AdminReconItem({
    required this.reportId,
    required this.issueKind,
    required this.expectedAmount,
    required this.actualAmount,
    required this.difference,
    required this.status,
    required this.severity,
    required this.createdAt,
    this.paymentId,
    this.bookingId,
  });
  final String reportId;
  final String issueKind;
  final String expectedAmount;
  final String actualAmount;
  final String difference;
  final String status;
  final String severity;
  final DateTime createdAt;
  final String? paymentId;
  final String? bookingId;

  factory AdminReconItem.fromJson(Map<String, dynamic> json) => AdminReconItem(
        reportId: (json['report_id'] ?? json['id'] ?? '').toString(),
        issueKind: (json['issue_kind'] ?? '').toString(),
        expectedAmount: (json['expected_amount'] ?? '0').toString(),
        actualAmount: (json['actual_amount'] ?? '0').toString(),
        difference: (json['difference'] ?? '0').toString(),
        status: (json['status'] ?? '').toString(),
        severity: (json['severity'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
        paymentId: json['payment_id']?.toString(),
        bookingId: json['booking_id']?.toString(),
      );
}
