import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../auth/auth_session.dart';
import '../../../core/api/owambe_api_auth.dart';
import '../models/customer_finance_models.dart';

class CustomerFinanceApiException implements Exception {
  CustomerFinanceApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'CustomerFinanceApiException($code): $message';
}

/// Event OS finance API client (Customer Portal).
class CustomerFinanceApi {
  CustomerFinanceApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base => OwambeApiAuth.resolveApiBase();

  String get _tenantId => OwambeApiAuth.resolveTenantId(devTenantId);

  Future<Map<String, String>> _headers([AuthSession? session]) =>
      OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw CustomerFinanceApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is CustomerFinanceApiException) rethrow;
      throw CustomerFinanceApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<CustomerEventFinanceSummary> fetchEventSummary({
    required String eventId,
    AuthSession? session,
  }) async {
    final res = await _http.get(_u('events/$eventId/finance/summary'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    return CustomerEventFinanceSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<CustomerFinanceTransaction>> fetchEventTransactions({
    required String eventId,
    int limit = 50,
    AuthSession? session,
  }) async {
    final res = await _http.get(
      _u('events/$eventId/finance/transactions', {'limit': '$limit'}),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => CustomerFinanceTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
