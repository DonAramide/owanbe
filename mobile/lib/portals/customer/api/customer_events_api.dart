import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../auth/auth_session.dart';
import '../../../core/api/owambe_api_auth.dart';
import '../../../core/api/owambe_http_client.dart';
import '../models/customer_event_mapper.dart';
import '../models/customer_event_models.dart';

/// Event OS events API client — maps responses to [CustomerEvent].
class CustomerEventsApi {
  CustomerEventsApi({http.Client? client}) : _http = client ?? createOwambeHttpClient();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base => OwambeApiAuth.resolveApiBase();

  String get _tenantId => OwambeApiAuth.resolveTenantId(devTenantId);

  Future<Map<String, String>> _headers({AuthSession? session}) async =>
      OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Future<List<CustomerEvent>> listEvents({AuthSession? session}) async {
    final res = await _http.get(_u('organizers/me/events'), headers: await _headers(session: session));
    if (res.statusCode >= 400) throw StateError('Failed to list events');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => mapCustomerEvent(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerEvent?> getEvent(String eventId, {AuthSession? session}) async {
    final res = await _http.get(_u('events/$eventId/manage'), headers: await _headers(session: session));
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) throw StateError('Failed to load event');
    return mapCustomerEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CustomerEvent> publishEvent(String eventId, {AuthSession? session}) async {
    final res = await _http.post(_u('events/$eventId/publish'), headers: await _headers(session: session));
    if (res.statusCode >= 400) throw StateError('Failed to publish event');
    return mapCustomerEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CustomerEvent> goLiveEvent(String eventId, {AuthSession? session}) async {
    final res = await _http.post(_u('events/$eventId/go-live'), headers: await _headers(session: session));
    if (res.statusCode >= 400) throw StateError('Failed to go live');
    return mapCustomerEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
