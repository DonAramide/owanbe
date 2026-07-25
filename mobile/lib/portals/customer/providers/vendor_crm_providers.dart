import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owambe_api_auth.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../models/vendor_crm_models.dart';
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

  Future<VendorCrmSnapshot> listForVendor(String vendorId) async {
    final res = await _http.get(
      Uri.parse('$_base/vendors/$vendorId/requests'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return VendorCrmSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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

final organizerVendorCrmAlertsProvider =
    FutureProvider.autoDispose<List<OrganizerAttentionItem>>((ref) async {
  ref.watch(vendorCrmRefreshProvider);
  try {
    final events = await ref.watch(customerEventsProvider.future);
    final items = <OrganizerAttentionItem>[];
    for (final e in events) {
      final snap = await ref.read(vendorCrmApiProvider).listForEvent(e.id);
      for (final r in snap.items) {
        if (r.stage == 'negotiating') {
          items.add(OrganizerAttentionItem(
            type: OrganizerAttentionType.lowTicketSales,
            headline: 'Vendor negotiation',
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
  try {
    return await ref.read(vendorCrmApiProvider).fetchCalendar(vendorId, from, to);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return VendorCalendarSnapshot(
      vacationMode: false,
      blocks: [
        VendorCalendarBlock(
          id: 'mock_block_1',
          kind: 'busy',
          startsAt: now.add(const Duration(days: 2)),
          endsAt: now.add(const Duration(days: 2, hours: 4)),
          reason: 'Busy with Jollof Catering Event',
          allDay: false,
        ),
        VendorCalendarBlock(
          id: 'mock_block_2',
          kind: 'busy',
          startsAt: now.add(const Duration(days: 5)),
          endsAt: now.add(const Duration(days: 6)),
          reason: 'Weekend Rest',
          allDay: true,
        ),
      ],
    );
  }
});
