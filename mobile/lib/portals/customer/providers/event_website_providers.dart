import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owanbe_api_auth.dart';
import '../models/event_website_models.dart';

class EventWebsiteApi {
  EventWebsiteApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId();

  Future<EventWebsiteConfig> fetch(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/website'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return EventWebsiteConfig.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<EventWebsiteConfig> patch(String eventId, Map<String, dynamic> body) async {
    final res = await _http.patch(
      Uri.parse('$_base/events/$eventId/website'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return EventWebsiteConfig.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<EventWebsiteConfig> publish(String eventId) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/website/publish'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return EventWebsiteConfig.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<EventWebsiteConfig> unpublish(String eventId) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/website/unpublish'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return EventWebsiteConfig.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError((body['message'] ?? 'Request failed').toString());
    } catch (_) {
      throw StateError('Website API error (${res.statusCode})');
    }
  }
}

final eventWebsiteApiProvider = Provider<EventWebsiteApi>((ref) => EventWebsiteApi());

final eventWebsiteRefreshProvider = StateProvider<int>((ref) => 0);

void refreshEventWebsite(WidgetRef ref) {
  ref.read(eventWebsiteRefreshProvider.notifier).state++;
}

final eventWebsiteProvider =
    FutureProvider.autoDispose.family<EventWebsiteConfig, String>((ref, eventId) async {
  ref.watch(eventWebsiteRefreshProvider);
  return ref.read(eventWebsiteApiProvider).fetch(eventId);
});
