import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owambe_api_auth.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../models/vendor_crm_models.dart';
import '../models/vendor_change_request_models.dart';
import '../providers/customer_event_providers.dart';

class VendorCrmApi {
  VendorCrmApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId();

  Future<VendorCrmSnapshot> listForEvent(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/vendor-requests'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> createRequest(String eventId, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/vendor-requests'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> createVendorBuyerRequest(String eventId, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/vendor-requests/vendor-buyer'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> listOutgoingForVendor(String vendorId) async {
    final res = await _http.get(
      Uri.parse('$_base/vendors/$vendorId/outgoing-vendor-requests'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> transitionStage(String requestId, String stage, {String? note}) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/stage'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'stage': stage, if (note != null) 'note': note}),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> counterOffer(
    String requestId, {
    required int amountMinor,
    String? message,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/counter'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'amountMinor': amountMinor,
        if (message != null) 'message': message,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> postMessage(String requestId, {required String message}) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/messages'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'message': message}),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> confirmAgreement(String requestId) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/confirm-agreement'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> fundRequest(String requestId) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/fund'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fundEventPool(String eventId, {required int amountMinor}) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/vendor-funds'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'amountMinor': amountMinor}),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEventFunds(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/vendor-funds'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<VendorCrmSnapshot> markComplete(String requestId) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/mark-complete'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> confirmCompletion(String requestId) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/confirm-completion'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> reportIssue(String requestId, {String? note}) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/report-issue'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'note': note ?? 'Issue reported'}),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCrmSnapshot> listForVendor(String vendorId) async {
    final res = await _http.get(
      Uri.parse('$_base/vendors/$vendorId/requests'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<VendorChangeRequest>> listChangeRequests(String requestId) async {
    final res = await _http.get(
      Uri.parse('$_base/vendor-requests/$requestId/change-requests'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map((e) => VendorChangeRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<VendorChangeRequest> createChangeRequest(
    String requestId,
    Map<String, dynamic> body,
  ) async {
    final res = await _http.post(
      Uri.parse('$_base/vendor-requests/$requestId/change-requests'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorChangeRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorChangeRequest> acceptChangeRequest(String changeId) async {
    final res = await _http.post(
      Uri.parse('$_base/change-requests/$changeId/accept'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorChangeRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorChangeRequest> declineChangeRequest(String changeId, {String? note}) async {
    final res = await _http.post(
      Uri.parse('$_base/change-requests/$changeId/decline'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({if (note != null) 'note': note}),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorChangeRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorChangeRequest> cancelChangeRequest(String changeId) async {
    final res = await _http.post(
      Uri.parse('$_base/change-requests/$changeId/cancel'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorChangeRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorRequestTimeline> fetchTimeline(String requestId) async {
    final res = await _http.get(
      Uri.parse('$_base/vendor-requests/$requestId/timeline'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorRequestTimeline.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCalendarSnapshot> fetchCalendar(String vendorId, DateTime from, DateTime to) async {
    final res = await _http.get(
      Uri.parse(
        '$_base/vendors/$vendorId/calendar?from=${Uri.encodeComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}',
      ),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCalendarSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCalendarSnapshot> patchVacation(String vendorId, {required bool vacationMode, String? vacationUntil}) async {
    final res = await _http.patch(
      Uri.parse('$_base/vendors/$vendorId/calendar/settings'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
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
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'kind': 'blackout',
        'allDay': true,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'reason': reason,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> updateBlock(
    String vendorId,
    String blockId, {
    required DateTime startsAt,
    required DateTime endsAt,
    required String reason,
    bool allDay = true,
  }) async {
    final res = await _http.patch(
      Uri.parse('$_base/vendors/$vendorId/calendar/blocks/$blockId'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'reason': reason,
        'allDay': allDay,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> deleteBlock(String vendorId, String blockId) async {
    final res = await _http.delete(
      Uri.parse('$_base/vendors/$vendorId/calendar/blocks/$blockId'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  void _throw(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        final code = decoded['code']?.toString();
        final message = decoded['message']?.toString();
        if (code != null && code.isNotEmpty) {
          throw Exception(message != null && message.isNotEmpty ? '$code: $message' : code);
        }
        if (message != null && message.isNotEmpty) {
          throw Exception(message);
        }
      }
    } catch (e) {
      if (e is Exception && e.toString() != 'Exception') rethrow;
    }
    throw Exception('Vendor CRM API ${res.statusCode}: ${res.body}');
  }
}

final vendorCrmApiProvider = Provider<VendorCrmApi>((ref) => VendorCrmApi());

final vendorCrmRefreshProvider = StateProvider<int>((ref) => 0);

/// Soft poll tick — same pattern as Live Ops feed (cross-party sync without hot restart).
final vendorCrmLiveTickProvider = StreamProvider.autoDispose<int>((ref) async* {
  yield 0;
  var n = 0;
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 5));
    n += 1;
    yield n;
  }
});

void refreshVendorCrm(dynamic ref) {
  ref.read(vendorCrmRefreshProvider.notifier).state++;
}

final eventVendorCrmProvider = FutureProvider.autoDispose.family<VendorCrmSnapshot, String>((ref, eventId) async {
  ref.watch(vendorCrmRefreshProvider);
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  try {
    return await ref.read(vendorCrmApiProvider).listForEvent(eventId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return const VendorCrmSnapshot(
      items: [],
      stats: VendorPipelineStats(),
    );
  }
});

final vendorInboxProvider = FutureProvider.autoDispose.family<VendorCrmSnapshot, String>((ref, vendorId) async {
  ref.watch(vendorCrmRefreshProvider);
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  try {
    return await ref.read(vendorCrmApiProvider).listForVendor(vendorId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return const VendorCrmSnapshot(
      items: [],
      stats: VendorPipelineStats(),
    );
  }
});

final vendorOutgoingCrmProvider = FutureProvider.autoDispose.family<VendorCrmSnapshot, String>((ref, vendorId) async {
  ref.watch(vendorCrmRefreshProvider);
  try {
    return await ref.read(vendorCrmApiProvider).listOutgoingForVendor(vendorId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return const VendorCrmSnapshot(items: [], stats: VendorPipelineStats());
  }
});

final vendorRequestTimelineProvider =
    FutureProvider.autoDispose.family<VendorRequestTimeline, String>((ref, requestId) async {
  ref.watch(vendorCrmRefreshProvider);
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  return ref.read(vendorCrmApiProvider).fetchTimeline(requestId);
});

/// Phase 3D — change requests for a parent vendor_event_request (REST + SSE refresh).
final vendorChangeRequestsProvider =
    FutureProvider.autoDispose.family<List<VendorChangeRequest>, String>((ref, requestId) async {
  ref.watch(vendorCrmRefreshProvider);
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  return ref.read(vendorCrmApiProvider).listChangeRequests(requestId);
});

final eventVendorFundsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, eventId) async {
  ref.watch(vendorCrmRefreshProvider);
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  return ref.read(vendorCrmApiProvider).getEventFunds(eventId);
});

final organizerVendorCrmAlertsProvider =
    FutureProvider.autoDispose<List<OrganizerAttentionItem>>((ref) async {
  ref.watch(vendorCrmRefreshProvider);
  // Do not watch vendorCrmLiveTickProvider here. Hub stays mounted under
  // Marketplace (context.push), so a 5s tick would globally refetch every
  // event's CRM and hitch/reset the UI. Live request/message polling remains
  // on eventVendorCrmProvider / vendorInboxProvider / timeline.
  try {
    final events = await ref.watch(customerEventsProvider.future);
    final items = <OrganizerAttentionItem>[];
    for (final e in events) {
      final snap = await ref.read(vendorCrmApiProvider).listForEvent(e.id);
      for (final r in snap.items) {
        if (r.stage == 'negotiating') {
          items.add(OrganizerAttentionItem(
            type: OrganizerAttentionType.lowTicketSales,
            headline: 'Pending vendor response',
            message: '${r.vendorName ?? 'Vendor'} · ${r.eventTitle ?? e.title}',
            eventId: e.id,
            severity: 'INFO',
          ));
        } else if (r.stage == 'accepted') {
          items.add(OrganizerAttentionItem(
            type: OrganizerAttentionType.unpublishedDraft,
            headline: 'Vendor accepted',
            message: '${r.vendorName ?? 'Vendor'} accepted ${r.eventTitle ?? e.title}',
            eventId: e.id,
            severity: 'INFO',
          ));
        } else if (r.stage == 'declined') {
          items.add(OrganizerAttentionItem(
            type: OrganizerAttentionType.lowTicketSales,
            headline: 'Vendor declined',
            message: '${r.vendorName ?? 'Vendor'} declined ${r.eventTitle ?? e.title}',
            eventId: e.id,
            severity: 'WARNING',
          ));
        }
      }
    }
    return items;
  } catch (_) {
    return const [];
  }
});

final vendorCalendarProvider = FutureProvider.autoDispose.family<VendorCalendarSnapshot, String>((ref, vendorId) async {
  ref.watch(vendorCrmRefreshProvider);
  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 7));
  final to = now.add(const Duration(days: 60));
  return ref.read(vendorCrmApiProvider).fetchCalendar(vendorId, from, to);
});
