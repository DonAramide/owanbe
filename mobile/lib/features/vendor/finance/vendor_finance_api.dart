import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/owanbe_api_auth.dart';
import 'vendor_finance_models.dart';

class VendorFinanceApi {
  VendorFinanceApi({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base => OwanbeApiAuth.resolveApiBase();

  String get _tenantId => OwanbeApiAuth.resolveTenantId(devTenantId);

  bool get isConfigured => _tenantId.isNotEmpty;

  Future<Map<String, String>> _headers() => OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId);

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throwApi(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final code = (body['code'] ?? 'HTTP_${res.statusCode}').toString();
      final message = (body['message'] ?? 'Request failed').toString();
      final suggestions = (body['suggestionsMinor'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList();
      throw VendorFinanceApiException(code: code, message: message, suggestionsMinor: suggestions);
    } catch (_) {
      throw VendorFinanceApiException(
        code: 'HTTP_${res.statusCode}',
        message: 'Request failed (${res.statusCode})',
      );
    }
  }

  Future<VendorSummaryResponse> getSummary({String? vendorId}) async {
    final res = await _http.get(
      _u('vendor/finance/summary', vendorId == null ? null : {'vendorId': vendorId}),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return VendorSummaryResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorTransactionsResponse> getTransactions({int limit = 100, String? vendorId}) async {
    final query = <String, String>{'limit': '$limit'};
    if (vendorId != null && vendorId.isNotEmpty) query['vendorId'] = vendorId;
    final res = await _http.get(_u('vendor/finance/transactions', query), headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return VendorTransactionsResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorPayoutResult> createPayout({required String amountMinor, String? vendorId}) async {
    final q = <String, String>{'amountMinor': amountMinor};
    if (vendorId != null && vendorId.isNotEmpty) q['vendorId'] = vendorId;
    final res = await _http.post(_u('vendor/finance/payout', q), headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return VendorPayoutResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
