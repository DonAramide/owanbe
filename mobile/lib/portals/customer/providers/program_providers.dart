import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owanbe_api_auth.dart';
import '../models/program_models.dart';

class ProgramApi {
  ProgramApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId();

  Future<ProgramSnapshot> fetch(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/program'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return ProgramSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProgramSnapshot> createItem(String eventId, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/program/items'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return ProgramSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProgramSnapshot> patchItem(String eventId, String itemId, Map<String, dynamic> body) async {
    final res = await _http.patch(
      Uri.parse('$_base/events/$eventId/program/items/$itemId'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return ProgramSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProgramSnapshot> deleteItem(String eventId, String itemId) async {
    final res = await _http.delete(
      Uri.parse('$_base/events/$eventId/program/items/$itemId'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return ProgramSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProgramSnapshot> setStatus(
    String eventId,
    String itemId, {
    required String status,
    int? delayMinutes,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/program/items/$itemId/status'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'status': status,
        if (delayMinutes != null) 'delayMinutes': delayMinutes,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return ProgramSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProgramSnapshot> reorder(String eventId, List<String> itemIds) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/program/reorder'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'itemIds': itemIds}),
    );
    if (res.statusCode >= 400) _throw(res);
    return ProgramSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProgramSnapshot> autoShift(String eventId, String fromItemId, int delayMinutes) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/program/auto-shift'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'fromItemId': fromItemId, 'delayMinutes': delayMinutes}),
    );
    if (res.statusCode >= 400) _throw(res);
    return ProgramSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ProgramSnapshot> applyTemplate(String eventId, String template) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/program/apply-template'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'template': template}),
    );
    if (res.statusCode >= 400) _throw(res);
    return ProgramSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  void _throw(http.Response res) {
    throw Exception('Program API ${res.statusCode}: ${res.body}');
  }
}

final programApiProvider = Provider<ProgramApi>((ref) => ProgramApi());

final programRefreshProvider = StateProvider<int>((ref) => 0);

void refreshProgram(WidgetRef ref) {
  ref.read(programRefreshProvider.notifier).state++;
}

final eventProgramProvider = FutureProvider.autoDispose.family<ProgramSnapshot, String>((ref, eventId) async {
  ref.watch(programRefreshProvider);
  return ref.read(programApiProvider).fetch(eventId);
});
