import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owanbe_api_auth.dart';

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

  String get _base => OwanbeApiAuth.resolveApiBase();

  String get _tenantId => OwanbeApiAuth.resolveTenantId(devTenantId);

  Future<Map<String, String>> _headers() => OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId);

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
