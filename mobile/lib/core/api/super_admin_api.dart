import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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

  String get _base {
    final raw = (dotenv.env['OWANBE_API_BASE'] ?? 'http://localhost:8080/v1').trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  Future<Map<String, String>> _headers() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      return headers;
    }
    final devUser = (dotenv.env['OWANBE_SUPER_ADMIN_USER_ID'] ?? devSuperAdminUserId).trim();
    headers['X-Dev-User-Id'] = devUser;
    headers['X-Dev-User-Email'] = dotenv.env['OWANBE_SUPER_ADMIN_USER_EMAIL'] ?? 'superadmin@owanbe.dev';
    return headers;
  }

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
