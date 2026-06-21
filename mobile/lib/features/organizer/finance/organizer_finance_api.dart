import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/owanbe_api_auth.dart';
import '../../../auth/auth_session.dart';

class OrganizerFinanceApiException implements Exception {
  OrganizerFinanceApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'OrganizerFinanceApiException($code): $message';
}

class OrganizerEventFinanceSummary {
  const OrganizerEventFinanceSummary({
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

  factory OrganizerEventFinanceSummary.fromJson(Map<String, dynamic> json) {
    return OrganizerEventFinanceSummary(
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

class OrganizerFinanceTransaction {
  const OrganizerFinanceTransaction({
    required this.type,
    required this.status,
    required this.amountMinor,
    required this.currency,
    required this.timestampMs,
    this.ticketOrderId,
    this.orderReference,
    this.reason,
  });

  final String type;
  final String status;
  final String amountMinor;
  final String currency;
  final int timestampMs;
  final String? ticketOrderId;
  final String? orderReference;
  final String? reason;

  factory OrganizerFinanceTransaction.fromJson(Map<String, dynamic> json) {
    return OrganizerFinanceTransaction(
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amountMinor: (json['amountMinor'] ?? '0').toString(),
      currency: (json['currency'] ?? 'NGN').toString(),
      timestampMs: (json['timestampMs'] as num?)?.toInt() ??
          DateTime.tryParse((json['occurredAt'] ?? '').toString())?.millisecondsSinceEpoch ??
          0,
      ticketOrderId: json['ticketOrderId'] as String?,
      orderReference: json['orderReference'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

class OrganizerFinanceApi {
  OrganizerFinanceApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';
  static const devOrganizerUserId = '22222222-2222-4222-8222-222222222222';

  String get _base => OwanbeApiAuth.resolveApiBase();

  String get _tenantId => OwanbeApiAuth.resolveTenantId(devTenantId);

  Future<Map<String, String>> _headers([AuthSession? session]) =>
      OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId);

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw OrganizerFinanceApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is OrganizerFinanceApiException) rethrow;
      throw OrganizerFinanceApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<OrganizerEventFinanceSummary> fetchEventSummary({
    required String eventId,
    AuthSession? session,
  }) async {
    final res = await _http.get(_u('events/$eventId/finance/summary'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    return OrganizerEventFinanceSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<OrganizerFinanceTransaction>> fetchEventTransactions({
    required String eventId,
    int limit = 50,
    AuthSession? session,
  }) async {
    final res = await _http.get(
      _u('events/$eventId/finance/transactions').replace(queryParameters: {'limit': '$limit'}),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => OrganizerFinanceTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrganizerPayoutResult> createPayout({
    required String organizerId,
    required String amountMinor,
    AuthSession? session,
  }) async {
    final res = await _http.post(
      _u('organizers/$organizerId/payouts').replace(queryParameters: {'amountMinor': amountMinor}),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    return OrganizerPayoutResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class OrganizerPayoutResult {
  const OrganizerPayoutResult({
    required this.ok,
    required this.requestedMinor,
    required this.payouts,
  });

  final bool ok;
  final String requestedMinor;
  final List<OrganizerPayoutLine> payouts;

  factory OrganizerPayoutResult.fromJson(Map<String, dynamic> json) {
    return OrganizerPayoutResult(
      ok: json['ok'] == true,
      requestedMinor: (json['requestedMinor'] ?? '0').toString(),
      payouts: (json['payouts'] as List<dynamic>? ?? [])
          .map((e) => OrganizerPayoutLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrganizerPayoutLine {
  const OrganizerPayoutLine({
    required this.payoutId,
    required this.ticketOrderId,
    required this.amountMinor,
  });

  final String payoutId;
  final String ticketOrderId;
  final String amountMinor;

  factory OrganizerPayoutLine.fromJson(Map<String, dynamic> json) {
    return OrganizerPayoutLine(
      payoutId: (json['payoutId'] ?? '').toString(),
      ticketOrderId: (json['ticketOrderId'] ?? '').toString(),
      amountMinor: (json['amountMinor'] ?? '0').toString(),
    );
  }
}
