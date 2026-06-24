import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owanbe_api_auth.dart';
import '../models/seating_models.dart';

class SeatingApi {
  SeatingApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId();

  Future<SeatingLayout> fetchManage(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/seating/manage'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return SeatingLayout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SeatingLayout> createTable(String eventId, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/seating/tables'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return SeatingLayout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SeatingLayout> patchTable(String eventId, String tableId, Map<String, dynamic> body) async {
    final res = await _http.patch(
      Uri.parse('$_base/events/$eventId/seating/tables/$tableId'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return SeatingLayout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SeatingLayout> deleteTable(String eventId, String tableId) async {
    final res = await _http.delete(
      Uri.parse('$_base/events/$eventId/seating/tables/$tableId'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return SeatingLayout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SeatingLayout> syncPositions(
    String eventId,
    List<Map<String, dynamic>> tables,
  ) async {
    final res = await _http.put(
      Uri.parse('$_base/events/$eventId/seating/tables/positions'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'tables': tables}),
    );
    if (res.statusCode >= 400) _throw(res);
    return SeatingLayout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SeatingLayout> assignGuest({
    required String eventId,
    required String tableId,
    required String guestRef,
    required String guestName,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/seating/assignments'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'tableId': tableId,
        'guestRef': guestRef,
        'guestName': guestName,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return SeatingLayout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SeatingLayout> unassignGuest(String eventId, String assignmentId) async {
    final res = await _http.delete(
      Uri.parse('$_base/events/$eventId/seating/assignments/$assignmentId'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return SeatingLayout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SeatingLayout> initialize(String eventId, {required int guestCount, int vipTableCount = 1}) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/seating/initialize'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'guestCount': guestCount, 'vipTableCount': vipTableCount}),
    );
    if (res.statusCode >= 400) _throw(res);
    return SeatingLayout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  void _throw(http.Response res) {
    throw Exception('Seating API ${res.statusCode}: ${res.body}');
  }
}

final seatingApiProvider = Provider<SeatingApi>((ref) => SeatingApi());

final seatingRefreshProvider = StateProvider<int>((ref) => 0);

void refreshSeating(WidgetRef ref) {
  ref.read(seatingRefreshProvider.notifier).state++;
}

final eventSeatingProvider = FutureProvider.autoDispose.family<SeatingLayout, String>((ref, eventId) async {
  ref.watch(seatingRefreshProvider);
  return ref.read(seatingApiProvider).fetchManage(eventId);
});
