import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owanbe_api_auth.dart';

class ComplianceApiException implements Exception {
  ComplianceApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// Phase 27 — Nest `/compliance/*` client (admin / tenant.manage).
class ComplianceApi {
  ComplianceApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const _devTenant = '11111111-1111-4111-8111-111111111111';

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId(_devTenant);

  Future<Map<String, String>> _headers() => OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ComplianceApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is ComplianceApiException) rethrow;
      throw ComplianceApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<Map<String, dynamic>> dashboard() async {
    final res = await _http.get(_u('compliance/dashboard'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> retention() async {
    final res = await _http.get(_u('compliance/retention'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRetention(Map<String, dynamic> body) async {
    final res = await _http.patch(
      _u('compliance/retention'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listExports() async {
    final res = await _http.get(_u('compliance/exports'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createExport({
    String exportKind = 'audit_bundle',
    String? subjectUserId,
  }) async {
    final res = await _http.post(
      _u('compliance/exports'),
      headers: await _headers(),
      body: jsonEncode({
        'exportKind': exportKind,
        if (subjectUserId != null && subjectUserId.isNotEmpty) 'subjectUserId': subjectUserId,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> downloadExport(String id) async {
    final res = await _http.get(_u('compliance/exports/$id/download'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listDeletions() async {
    final res = await _http.get(_u('compliance/deletion-requests'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> requestDeletion({
    required String subjectUserId,
    String? reason,
  }) async {
    final res = await _http.post(
      _u('compliance/deletion-requests'),
      headers: await _headers(),
      body: jsonEncode({
        'subjectUserId': subjectUserId,
        if (reason != null) 'reason': reason,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transitionDeletion({
    required String id,
    required String action,
    String? reason,
  }) async {
    final res = await _http.post(
      _u('compliance/deletion-requests/$id/transition'),
      headers: await _headers(),
      body: jsonEncode({
        'action': action,
        if (reason != null) 'reason': reason,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> activity({int limit = 40}) async {
    final res = await _http.get(
      _u('compliance/activity', {'limit': '$limit'}),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<String> governanceReportCsv() async {
    final res = await _http.get(
      _u('compliance/reports/governance.csv'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    return res.body;
  }
}
