import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'owanbe_api_auth.dart';

/// Phase 24 — Nest-backed Integration Hub client (replaces mock IntegrationEngine).
class IntegrationsApi {
  IntegrationsApi({String? baseUrl}) : _base = OwambeApiAuth.resolveApiBase();

  final String _base;

  Uri _u(String path) => Uri.parse('$_base$path');

  Future<Map<String, dynamic>> registry() async {
    final res = await http.get(
      _u('/super-admin/integrations/registry'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deliveries({int limit = 50}) async {
    final res = await http.get(
      _u('/super-admin/integrations/deliveries?limit=$limit'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listWebhooks() async {
    final res = await http.get(
      _u('/super-admin/integrations/webhooks'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    final data = jsonDecode(res.body);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

  Future<Map<String, dynamic>> createWebhook({
    required String targetUrl,
    required List<String> subscribedTopics,
    String? label,
  }) async {
    final res = await http.post(
      _u('/super-admin/integrations/webhooks'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: jsonEncode({
        'targetUrl': targetUrl,
        'subscribedTopics': subscribedTopics,
        if (label != null) 'label': label,
      }),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setWebhookActive(String id, bool isActive) async {
    final res = await http.post(
      _u('/super-admin/integrations/webhooks/$id/active'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: jsonEncode({'isActive': isActive}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> webhookDeliveries({int limit = 50}) async {
    final res = await http.get(
      _u('/super-admin/integrations/webhooks/deliveries?limit=$limit'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listMessaging({String? channel}) async {
    final q = channel == null ? '' : '?channel=$channel';
    final res = await http.get(
      _u('/super-admin/integrations/messaging$q'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    final data = jsonDecode(res.body);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

  Future<Map<String, dynamic>> createMessaging(Map<String, dynamic> body) async {
    final res = await http.post(
      _u('/super-admin/integrations/messaging'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: jsonEncode(body),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Integrations API ${res.statusCode}: ${res.body}');
    }
  }
}

final integrationsApiProvider = Provider<IntegrationsApi>((ref) => IntegrationsApi());

final integrationRegistryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(integrationsApiProvider).registry();
});

final integrationDeliveriesProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(integrationsApiProvider).deliveries();
});

final integrationWebhooksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(integrationsApiProvider).listWebhooks();
});

final integrationMessagingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(integrationsApiProvider).listMessaging();
});
