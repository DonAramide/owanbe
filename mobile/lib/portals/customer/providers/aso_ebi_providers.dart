import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owanbe_api_auth.dart';
import '../models/aso_ebi_models.dart';

class AsoEbiApi {
  AsoEbiApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId();

  Future<AsoEbiPublicSnapshot> fetchPublic(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/aso-ebi'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiPublicSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiManageSnapshot> fetchManage(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/aso-ebi/manage'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiManageSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiFabric> createFabric(String eventId, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/aso-ebi/fabrics'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiFabric.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiFabric> patchFabric(String eventId, String fabricId, Map<String, dynamic> body) async {
    final res = await _http.patch(
      Uri.parse('$_base/events/$eventId/aso-ebi/fabrics/$fabricId'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiFabric.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiFabric> upsertPackages(
    String eventId,
    String fabricId,
    List<Map<String, dynamic>> packages,
  ) async {
    final res = await _http.put(
      Uri.parse('$_base/events/$eventId/aso-ebi/fabrics/$fabricId/packages'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'packages': packages}),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiFabric.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiFabric> upsertInventory(
    String eventId,
    String fabricId,
    List<Map<String, dynamic>> items,
  ) async {
    final res = await _http.put(
      Uri.parse('$_base/events/$eventId/aso-ebi/fabrics/$fabricId/inventory'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'items': items}),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiFabric.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiReservation> reserve({
    required String eventId,
    required String fabricId,
    required String packageType,
    required String size,
    required String guestName,
    String? guestEmail,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/aso-ebi/reservations'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'fabricId': fabricId,
        'packageType': packageType,
        'size': size,
        'guestName': guestName,
        if (guestEmail != null && guestEmail.isNotEmpty) 'guestEmail': guestEmail,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiReservation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiReservation> pay(String eventId, String reservationId) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/aso-ebi/reservations/$reservationId/pay'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiReservation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiReservation> collect(String eventId, String reservationId) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/aso-ebi/reservations/$reservationId/collect'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiReservation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AsoEbiReservation> cancel(String eventId, String reservationId) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/aso-ebi/reservations/$reservationId/cancel'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return AsoEbiReservation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError((body['message'] ?? 'Request failed').toString());
    } catch (_) {
      throw StateError('Aso-Ebi API error (${res.statusCode})');
    }
  }
}

final asoEbiApiProvider = Provider<AsoEbiApi>((ref) => AsoEbiApi());

final asoEbiRefreshProvider = StateProvider<int>((ref) => 0);

void refreshAsoEbi(WidgetRef ref) {
  ref.read(asoEbiRefreshProvider.notifier).state++;
}

final asoEbiPublicProvider =
    FutureProvider.autoDispose.family<AsoEbiPublicSnapshot, String>((ref, eventId) async {
  ref.watch(asoEbiRefreshProvider);
  return ref.read(asoEbiApiProvider).fetchPublic(eventId);
});

final asoEbiManageProvider =
    FutureProvider.autoDispose.family<AsoEbiManageSnapshot, String>((ref, eventId) async {
  ref.watch(asoEbiRefreshProvider);
  return ref.read(asoEbiApiProvider).fetchManage(eventId);
});
