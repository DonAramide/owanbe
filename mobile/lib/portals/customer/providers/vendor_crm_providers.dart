import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owanbe_api_auth.dart';
import '../models/vendor_crm_models.dart';

class VendorCrmApi {
  VendorCrmApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId();

  Future<VendorCrmSnapshot> listForEvent(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/vendor-requests'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> createRequest(String eventId, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/vendor-requests'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> transitionStage(String requestId, String stage, {String? note}) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/stage'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'stage': stage, if (note != null) 'note': note}),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> listForVendor(String vendorId) async {
    final res = await _http.get(
      Uri.parse('$_base/vendors/$vendorId/requests'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCalendarSnapshot> fetchCalendar(String vendorId, DateTime from, DateTime to) async {
    final res = await _http.get(
      Uri.parse(
        '$_base/vendors/$vendorId/calendar?from=${Uri.encodeComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}',
      ),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCalendarSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCalendarSnapshot> patchVacation(String vendorId, {required bool vacationMode, String? vacationUntil}) async {
    final res = await _http.patch(
      Uri.parse('$_base/vendors/$vendorId/calendar/settings'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'vacationMode': vacationMode,
        if (vacationUntil != null) 'vacationUntil': vacationUntil,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCalendarSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> addBlackout(String vendorId, DateTime startsAt, DateTime endsAt, String reason) async {
    final res = await _http.post(
      Uri.parse('$_base/vendors/$vendorId/calendar/blocks'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'kind': 'blackout',
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'reason': reason,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  void _throw(http.Response res) {
    throw Exception('Vendor CRM API ${res.statusCode}: ${res.body}');
  }
}

final vendorCrmApiProvider = Provider<VendorCrmApi>((ref) => VendorCrmApi());

final vendorCrmRefreshProvider = StateProvider<int>((ref) => 0);

void refreshVendorCrm(WidgetRef ref) {
  ref.read(vendorCrmRefreshProvider.notifier).state++;
}

final eventVendorCrmProvider = FutureProvider.autoDispose.family<VendorCrmSnapshot, String>((ref, eventId) async {
  ref.watch(vendorCrmRefreshProvider);
  return ref.read(vendorCrmApiProvider).listForEvent(eventId);
});

final vendorInboxProvider = FutureProvider.autoDispose.family<VendorCrmSnapshot, String>((ref, vendorId) async {
  ref.watch(vendorCrmRefreshProvider);
  return ref.read(vendorCrmApiProvider).listForVendor(vendorId);
});

final vendorCalendarProvider = FutureProvider.autoDispose.family<VendorCalendarSnapshot, String>((ref, vendorId) async {
  ref.watch(vendorCrmRefreshProvider);
  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 7));
  final to = now.add(const Duration(days: 60));
  return ref.read(vendorCrmApiProvider).fetchCalendar(vendorId, from, to);
});
