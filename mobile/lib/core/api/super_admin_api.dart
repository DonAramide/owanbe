import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owanbe_api_auth.dart';

class SuperAdminApiException implements Exception {
  SuperAdminApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'SuperAdminApiException($code): $message';
}

class SuperAdminApi {
  SuperAdminApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const devSuperAdminUserId = '88888888-8888-4888-8888-888888888888';

  String get _base => OwanbeApiAuth.resolveApiBase();

  Future<Map<String, String>> _headers() => OwanbeApiAuth.authorizedHeaders(json: true);

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw SuperAdminApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is SuperAdminApiException) rethrow;
      throw SuperAdminApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<Map<String, dynamic>> getPlatformOverview() async {
    final res = await _http.get(_u('super-admin/platform/overview'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listTenants({String? q}) async {
    final res = await _http.get(_u('super-admin/tenants', {if (q != null && q.isNotEmpty) 'q': q}), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return ((jsonDecode(res.body) as Map<String, dynamic>)['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getTenant(String id) async {
    final res = await _http.get(_u('super-admin/tenants/$id'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTenant({required String slug, required String name}) async {
    final res = await _http.post(_u('super-admin/tenants'), headers: await _headers(), body: jsonEncode({'slug': slug, 'name': name}));
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> suspendTenant(String id) async {
    final res = await _http.post(_u('super-admin/tenants/$id/suspend'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> reactivateTenant(String id) async {
    final res = await _http.post(_u('super-admin/tenants/$id/reactivate'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }

  Future<Map<String, dynamic>> getPlatformFinance({String? drill, String? drillId}) async {
    final res = await _http.get(_u('super-admin/finance/platform', {
      if (drill != null) 'drill': drill,
      if (drillId != null) 'drillId': drillId,
    }), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSystemHealth() async {
    final res = await _http.get(_u('super-admin/system/health'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFeatureFlags(String tenantId) async {
    final res = await _http.get(_u('super-admin/feature-flags/$tenantId'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> setFeatureFlag(String tenantId, String flagKey, bool enabled) async {
    final res = await _http.post(_u('super-admin/feature-flags/$tenantId'), headers: await _headers(), body: jsonEncode({'flagKey': flagKey, 'enabled': enabled}));
    if (res.statusCode >= 400) _throw(res);
  }

  Future<List<Map<String, dynamic>>> getAuditTimeline({String? category}) async {
    final res = await _http.get(_u('super-admin/audit/timeline', {if (category != null && category != 'all') 'category': category}), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return ((jsonDecode(res.body) as Map<String, dynamic>)['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getAnalytics({String range = '30d'}) async {
    final res = await _http.get(_u('super-admin/analytics/platform', {'range': range}), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSecurityCenter() async {
    final res = await _http.get(_u('super-admin/security/center'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
