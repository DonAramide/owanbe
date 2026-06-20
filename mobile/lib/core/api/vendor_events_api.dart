import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/vendor/models/vendor_models.dart';
import 'events_api.dart';

class VendorEventsApi {
  VendorEventsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base {
    final raw = (dotenv.env['OWANBE_API_BASE'] ?? 'http://localhost:8080/v1').trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String get _tenantId => (dotenv.env['OWANBE_TENANT_ID'] ?? EventsApi.devTenantId).trim();

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
    headers['X-Dev-User-Id'] = (dotenv.env['OWANBE_VENDOR_USER_ID'] ?? EventsApi.devVendorUserId).trim();
    headers['X-Dev-User-Email'] = dotenv.env['OWANBE_VENDOR_USER_EMAIL'] ?? 'vendor@owanbe.dev';
    return headers;
  }

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw EventsApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is EventsApiException) rethrow;
      throw EventsApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<List<VendorEventParticipation>> listEvents() async {
    final res = await _http.get(_u('vendor/events'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => mapVendorParticipation(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> apply(String eventId) async {
    final res = await _http.post(_u('vendor/events/$eventId/apply'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> accept(String eventId) async {
    final res = await _http.post(_u('vendor/events/$eventId/accept'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> reject(String eventId) async {
    final res = await _http.post(_u('vendor/events/$eventId/reject'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
  }
}

VendorParticipationStatus mapVendorStatus(String raw) => switch (raw) {
      'invited' => VendorParticipationStatus.invited,
      'applied' => VendorParticipationStatus.pending,
      'pending' => VendorParticipationStatus.pending,
      'approved' => VendorParticipationStatus.confirmed,
      'live' => VendorParticipationStatus.live,
      'completed' => VendorParticipationStatus.completed,
      'rejected' => VendorParticipationStatus.declined,
      _ => VendorParticipationStatus.invited,
    };

VendorEventParticipation mapVendorParticipation(Map<String, dynamic> json) {
  final eventId = (json['eventId'] ?? '').toString();
  final status = mapVendorStatus((json['status'] ?? 'invited').toString());
  return VendorEventParticipation(
    id: (json['id'] ?? '').toString(),
    eventId: eventId,
    eventTitle: (json['eventTitle'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    venue: (json['venue'] ?? '').toString(),
    startsAt: DateTime.parse((json['startsAt'] ?? DateTime.now().toIso8601String()).toString()),
    status: status,
    boothLabel: (json['boothLabel'] ?? 'Vendor village').toString(),
    expectedPayoutMinor: int.tryParse((json['expectedPayoutMinor'] ?? '0').toString()) ?? 0,
  );
}
