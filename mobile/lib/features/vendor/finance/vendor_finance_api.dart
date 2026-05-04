import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vendor_finance_models.dart';

class VendorFinanceApi {
  VendorFinanceApi({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  String get _base {
    final raw = (dotenv.env['OWANBE_API_BASE'] ?? 'http://localhost:8080/v1').trim();
    if (raw.endsWith('/')) return raw.substring(0, raw.length - 1);
    return raw;
  }

  String get _tenantId => (dotenv.env['OWANBE_TENANT_ID'] ?? '').trim();

  Future<Map<String, String>> _headers() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    if (token.isEmpty || _tenantId.isEmpty) {
      throw VendorFinanceApiException(
        code: 'AUTH_MISSING',
        message: 'Missing auth token or OWANBE_TENANT_ID in env',
      );
    }
    return <String, String>{
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
