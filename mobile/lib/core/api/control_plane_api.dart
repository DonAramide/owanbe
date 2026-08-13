import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'owanbe_api_auth.dart';

class ControlPlaneApiException implements Exception {
  ControlPlaneApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// Phase 28 — Nest `/control-plane/*` client.
class ControlPlaneApi {
  ControlPlaneApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();

  Future<Map<String, String>> _headers() => OwambeApiAuth.authorizedHeaders(json: true);

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ControlPlaneApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is ControlPlaneApiException) rethrow;
      throw ControlPlaneApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<Map<String, dynamic>> dashboard() async {
    final res = await _http.get(_u('control-plane/dashboard'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listTenants({String? q, String? status}) async {
    final res = await _http.get(
      _u('control-plane/tenants', {
        if (q != null && q.isNotEmpty) 'q': q,
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getTenant(String tenantId) async {
    final res = await _http.get(_u('control-plane/tenants/$tenantId'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTenantConfig(
    String tenantId,
    Map<String, dynamic> metadata,
  ) async {
    final res = await _http.patch(
      _u('control-plane/tenants/$tenantId/configuration'),
      headers: await _headers(),
      body: jsonEncode({'metadata': metadata}),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> suspendTenant(String tenantId) async {
    final res = await _http.post(
      _u('control-plane/tenants/$tenantId/suspend'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> reactivateTenant(String tenantId) async {
    final res = await _http.post(
      _u('control-plane/tenants/$tenantId/reactivate'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<List<Map<String, dynamic>>> listVendors({
    String? q,
    String? status,
    String? tenantId,
  }) async {
    final res = await _http.get(
      _u('control-plane/vendors', {
        if (q != null && q.isNotEmpty) 'q': q,
        if (status != null && status.isNotEmpty) 'status': status,
        if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
      }),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getVendor(String tenantId, String vendorId) async {
    final res = await _http.get(
      _u('control-plane/vendors/$tenantId/$vendorId'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transitionVendor({
    required String tenantId,
    required String vendorId,
    required String action,
    String? reason,
  }) async {
    final res = await _http.post(
      _u('control-plane/vendors/$tenantId/$vendorId/transition'),
      headers: await _headers(),
      body: jsonEncode({'action': action, if (reason != null) 'reason': reason}),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> mdmDomains() async {
    final res = await _http.get(_u('control-plane/mdm/domains'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> mdmEntities(
    String domainKey, {
    String? parentId,
    String? q,
  }) async {
    final res = await _http.get(
      _u('control-plane/mdm/domains/$domainKey/entities', {
        if (parentId != null) 'parentId': parentId,
        if (q != null && q.isNotEmpty) 'q': q,
      }),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createMdmEntity(
    String domainKey,
    Map<String, dynamic> body,
  ) async {
    final res = await _http.post(
      _u('control-plane/mdm/domains/$domainKey/entities'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMdmEntity(
    String entityId,
    Map<String, dynamic> body,
  ) async {
    final res = await _http.patch(
      _u('control-plane/mdm/entities/$entityId'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> devices() async {
    final res = await _http.get(_u('control-plane/devices'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> activity({int limit = 40}) async {
    final res = await _http.get(
      _u('control-plane/activity', {'limit': '$limit'}),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }
}

final controlPlaneApiProvider = Provider<ControlPlaneApi>((ref) => ControlPlaneApi());

final controlPlaneDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(controlPlaneApiProvider).dashboard();
});

final controlPlaneVendorsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) async {
  return ref.read(controlPlaneApiProvider).listVendors(q: query.isEmpty ? null : query);
});

final controlPlaneMdmDomainsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(controlPlaneApiProvider).mdmDomains();
});

final controlPlaneActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(controlPlaneApiProvider).activity();
});

final controlPlaneDevicesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(controlPlaneApiProvider).devices();
});
