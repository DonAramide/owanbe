import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/finance/admin_finance_models.dart';

class AdminFinanceApi {
  AdminFinanceApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base {
    final raw = (dotenv.env['OWANBE_API_BASE'] ?? 'http://localhost:8080/v1')
        .trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String get _tenantId => (dotenv.env['OWANBE_TENANT_ID'] ?? '').trim();

  Future<Map<String, String>> _headers() async {
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    if (token.isEmpty || _tenantId.isEmpty) {
      throw AdminFinanceApiException(
        code: 'AUTH_MISSING',
        message: 'Missing token or tenant id',
      );
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Tenant-Id': _tenantId,
    };
  }

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throwApi(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw AdminFinanceApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (_) {
      throw AdminFinanceApiException(
        code: 'HTTP_${res.statusCode}',
        message: 'Request failed',
      );
    }
  }

  Future<AdminFinanceSummary> getSummary() async {
    final res = await _http.get(
      _u('admin/finance/summary'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return AdminFinanceSummary.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  AdminPage<T> _asPage<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
  ) => PaginatedResponse<T>.fromJson(body, parse);

  Future<AdminPage<AdminAlertItem>> getAlerts({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _http.get(
      _u('admin/finance/alerts', {'page': '$page', 'limit': '$limit'}),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _asPage(body, AdminAlertItem.fromJson);
  }

  Future<AdminPage<AdminTxItem>> getTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? status,
    String sortBy = 'created_at',
    String sortDir = 'desc',
    String? fromDate,
    String? toDate,
  }) async {
    final query = {
      'page': '$page',
      'limit': '$limit',
      'sortBy': sortBy,
      'sortDir': sortDir,
      if (type != null && type.isNotEmpty) 'type': type,
      if (status != null && status.isNotEmpty) 'status': status,
      if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
    };
    final res = await _http.get(
      _u('admin/finance/transactions', query),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _asPage(body, AdminTxItem.fromJson);
  }

  Future<AdminPage<AdminPayoutItem>> getPayouts({
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    final res = await _http.get(
      _u('admin/finance/payouts', {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _asPage(body, AdminPayoutItem.fromJson);
  }

  Future<void> processPayoutBatch({int limit = 20}) async {
    final res = await _http.post(
      _u('admin/finance/payouts/process-batch', {'limit': '$limit'}),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }

  Future<void> retryPayout(String payoutId) async {
    final res = await _http.post(
      _u('admin/finance/payouts/$payoutId/retry'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }

  Future<AdminPage<AdminReviewItem>> getReviews({
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _http.get(
      _u('admin/finance/reviews', {'page': '$page', 'limit': '$limit'}),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _asPage(body, AdminReviewItem.fromJson);
  }

  Future<void> reviewAction(String paymentId, String action) async {
    final res = await _http.post(
      _u('admin/finance/reviews/$paymentId/$action'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }

  Future<AdminPage<AdminReconItem>> getReconciliation({
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    final res = await _http.get(
      _u('admin/finance/reconciliation', {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _asPage(body, AdminReconItem.fromJson);
  }

  Future<void> recoverReconciliation(String paymentId) async {
    final res = await _http.post(
      _u('admin/finance/reconciliation/recover', {'paymentId': paymentId}),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }

  Future<String> getFinanceState() async {
    final res = await _http.get(
      _u('admin/finance/state'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['state'] ?? 'normal').toString();
  }

  Future<void> setFinanceState(String state, {String? reason}) async {
    final res = await _http.post(
      _u('admin/finance/state', {
        'state': state,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }
}
