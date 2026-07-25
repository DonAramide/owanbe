import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owanbe_api_auth.dart';

/// Super Admin — Enterprise Email Infrastructure client.
class EnterpriseEmailApi {
  EnterpriseEmailApi({String? baseUrl})
      : _base = OwambeApiAuth.resolveApiBase();

  final String _base;

  Uri _u(String path) => Uri.parse('$_base$path');

  Future<List<Map<String, dynamic>>> listProviders() async {
    final res = await http.get(
      _u('/super-admin/email-infrastructure/providers'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  Future<Map<String, dynamic>> readiness() async {
    final res = await http.get(
      _u('/super-admin/email-infrastructure/readiness'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createProvider(Map<String, dynamic> body) async {
    final res = await http.post(
      _u('/super-admin/email-infrastructure/providers'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: jsonEncode(body),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProvider(String id, Map<String, dynamic> body) async {
    final res = await http.patch(
      _u('/super-admin/email-infrastructure/providers/$id'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: jsonEncode(body),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteProvider(String id) async {
    final res = await http.delete(
      _u('/super-admin/email-infrastructure/providers/$id'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
  }

  Future<Map<String, dynamic>> setDefault(String id) async {
    final res = await http.post(
      _u('/super-admin/email-infrastructure/providers/$id/set-default'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> testConnection(String id) async {
    final res = await http.post(
      _u('/super-admin/email-infrastructure/providers/$id/test-connection'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendTestEmail(String id, String to) async {
    final res = await http.post(
      _u('/super-admin/email-infrastructure/providers/$id/test-email'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: jsonEncode({'to': to}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> supabaseSyncStatus() async {
    final res = await http.get(
      _u('/super-admin/email-infrastructure/supabase-sync/status'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncToSupabase({String? providerId}) async {
    final res = await http.post(
      _u('/super-admin/email-infrastructure/supabase-sync'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: jsonEncode({if (providerId != null) 'providerId': providerId}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listAudit({String? providerId}) async {
    final q = providerId != null ? '?providerId=$providerId' : '';
    final res = await http.get(
      _u('/super-admin/email-infrastructure/audit$q'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    final data = jsonDecode(res.body);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Enterprise Email API ${res.statusCode}: ${res.body}');
    }
  }
}
