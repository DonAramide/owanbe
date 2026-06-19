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

class AdminFinanceKpiAttention {
  const AdminFinanceKpiAttention({
    required this.level,
    required this.summary,
    this.detail,
  });

  final String level;
  final String summary;
  final String? detail;

  factory AdminFinanceKpiAttention.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AdminFinanceKpiAttention(level: 'none', summary: '');
    }
    return AdminFinanceKpiAttention(
      level: (json['level'] ?? 'none').toString(),
      summary: (json['summary'] ?? '').toString(),
      detail: json['detail']?.toString(),
    );
  }
}

class AdminFinanceSummary {
  const AdminFinanceSummary({
    required this.totalVolumeMinor,
    required this.escrowBalanceMinor,
    required this.pendingPayoutMinor,
    required this.pendingPayoutCount,
    required this.underReviewMinor,
    required this.underReviewCount,
    required this.failedCount,
    required this.failedMinor,
    required this.openReconciliationCount,
    required this.attention,
  });
  final String totalVolumeMinor;
  final String escrowBalanceMinor;
  final String pendingPayoutMinor;
  final String pendingPayoutCount;
  final String underReviewMinor;
  final String underReviewCount;
  final String failedCount;
  final String failedMinor;
  final String openReconciliationCount;
  final AdminFinanceSummaryAttention attention;

  factory AdminFinanceSummary.fromJson(Map<String, dynamic> json) {
    final rawAttention = json['attention'];
    return AdminFinanceSummary(
      totalVolumeMinor: (json['totalVolumeMinor'] ?? '0').toString(),
      escrowBalanceMinor: (json['escrowBalanceMinor'] ?? '0').toString(),
      pendingPayoutMinor: (json['pendingPayoutMinor'] ?? '0').toString(),
      pendingPayoutCount: (json['pendingPayoutCount'] ?? '0').toString(),
      underReviewMinor: (json['underReviewMinor'] ?? '0').toString(),
      underReviewCount: (json['underReviewCount'] ?? '0/0').toString(),
      failedCount: (json['failedCount'] ?? '0').toString(),
      failedMinor: (json['failedMinor'] ?? '0').toString(),
      openReconciliationCount: (json['openReconciliationCount'] ?? '0').toString(),
      attention: AdminFinanceSummaryAttention.fromJson(
        rawAttention is Map<String, dynamic> ? rawAttention : null,
      ),
    );
  }
}

class AdminFinanceSummaryAttention {
  const AdminFinanceSummaryAttention({
    required this.volume,
    required this.escrow,
    required this.pendingPayouts,
    required this.underReview,
    required this.failed,
    required this.reconciliation,
  });

  final AdminFinanceKpiAttention volume;
  final AdminFinanceKpiAttention escrow;
  final AdminFinanceKpiAttention pendingPayouts;
  final AdminFinanceKpiAttention underReview;
  final AdminFinanceKpiAttention failed;
  final AdminFinanceKpiAttention reconciliation;

  factory AdminFinanceSummaryAttention.fromJson(Map<String, dynamic>? json) {
    Map<String, dynamic>? block(String key) {
      final v = json?[key];
      return v is Map<String, dynamic> ? v : null;
    }

    return AdminFinanceSummaryAttention(
      volume: AdminFinanceKpiAttention.fromJson(block('volume')),
      escrow: AdminFinanceKpiAttention.fromJson(block('escrow')),
      pendingPayouts: AdminFinanceKpiAttention.fromJson(block('pendingPayouts')),
      underReview: AdminFinanceKpiAttention.fromJson(block('underReview')),
      failed: AdminFinanceKpiAttention.fromJson(block('failed')),
      reconciliation: AdminFinanceKpiAttention.fromJson(block('reconciliation')),
    );
  }
}

class AdminAlertItem {
  const AdminAlertItem({
    required this.type,
    required this.count,
    required this.severity,
    required this.latestOccurrence,
    required this.headline,
    required this.summary,
    this.suggestedAction,
  });
  final String type;
  final int count;
  final String severity;
  final DateTime latestOccurrence;
  final String headline;
  final String summary;
  final String? suggestedAction;

  factory AdminAlertItem.fromJson(Map<String, dynamic> json) => AdminAlertItem(
        type: (json['type'] ?? '').toString(),
        count: int.tryParse((json['count'] ?? '0').toString()) ?? 0,
        severity: (json['severity'] ?? 'WARNING').toString(),
        latestOccurrence:
            DateTime.tryParse((json['latest_occurrence'] ?? json['latestOccurrence'] ?? '').toString()) ??
                DateTime.now(),
        headline: (json['headline'] ?? json['type'] ?? 'Alert').toString(),
        summary: (json['summary'] ?? '').toString(),
        suggestedAction: json['suggested_action']?.toString() ?? json['suggestedAction']?.toString(),
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
