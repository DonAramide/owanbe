import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPlatformApiException implements Exception {
  AdminPlatformApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'AdminPlatformApiException($code): $message';
}

class AdminPlatformApi {
  AdminPlatformApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';
  static const devAdminUserId = '77777777-7777-4777-8777-777777777777';

  String get _base {
    final raw = (dotenv.env['OWANBE_API_BASE'] ?? 'http://localhost:8080/v1').trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String get _tenantId => (dotenv.env['OWANBE_TENANT_ID'] ?? devTenantId).trim();

  Future<Map<String, String>> _headers() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Tenant-Id': _tenantId,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      return headers;
    }
    final devUser = (dotenv.env['OWANBE_ADMIN_USER_ID'] ?? devAdminUserId).trim();
    headers['X-Dev-User-Id'] = devUser;
    headers['X-Dev-User-Email'] = dotenv.env['OWANBE_ADMIN_USER_EMAIL'] ?? 'admin@owanbe.dev';
    return headers;
  }

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw AdminPlatformApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is AdminPlatformApiException) rethrow;
      throw AdminPlatformApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<Map<String, dynamic>> getPlatformDashboard() async {
    final res = await _http.get(_u('admin/platform/dashboard'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listOrganizers({String? q, String? status}) async {
    final res = await _http.get(
      _u('admin/organizers', {
        if (q != null && q.isNotEmpty) 'q': q,
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getOrganizer(String id) async {
    final res = await _http.get(_u('admin/organizers/$id'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> suspendOrganizer(String id) async {
    final res = await _http.post(_u('admin/organizers/$id/suspend'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> reactivateOrganizer(String id) async {
    final res = await _http.post(_u('admin/organizers/$id/reactivate'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }

  Future<List<Map<String, dynamic>>> listEvents({String? q, String? status}) async {
    final res = await _http.get(
      _u('admin/events', {
        if (q != null && q.isNotEmpty) 'q': q,
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    final res = await _http.get(_u('admin/events/$id'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> forceCloseEvent(String id) async {
    final res = await _http.post(_u('admin/events/$id/force-close'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }

  Future<List<Map<String, dynamic>>> listVendors({String? q, String? status}) async {
    final res = await _http.get(
      _u('admin/vendors', {
        if (q != null && q.isNotEmpty) 'q': q,
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getVendor(String id) async {
    final res = await _http.get(_u('admin/vendors/$id'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> approveVendor(String id) async {
    final res = await _http.post(_u('admin/vendors/$id/approve'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> suspendVendor(String id, {String? reason}) async {
    final res = await _http.post(
      _u('admin/vendors/$id/suspend'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason ?? 'Admin suspension'}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<Map<String, dynamic>> getOperationsOverview() async {
    final res = await _http.get(_u('admin/operations/overview'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFinanceSupervision() async {
    final res = await _http.get(_u('admin/finance/supervision'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAuditTimeline({String? category}) async {
    final res = await _http.get(
      _u('admin/audit/timeline', {if (category != null && category != 'all') 'category': category}),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
