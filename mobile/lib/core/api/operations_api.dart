import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/operations/models/operations_models.dart';
import 'events_api.dart';
import 'owanbe_api_auth.dart';

class OperationsApi {
  OperationsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();

  String get _tenantId => OwanbeApiAuth.resolveTenantId(EventsApi.devTenantId);

  Future<Map<String, String>> _headers() => OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId);

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

  Future<List<OpsGuest>> listGuests(String eventId) async {
    final res = await _http.get(_u('events/$eventId/check-ins'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final checked = (body['checkedIn'] as List<dynamic>? ?? [])
        .map((e) => mapOpsGuest(e as Map<String, dynamic>, checkedIn: true))
        .toList();
    final pending = (body['pending'] as List<dynamic>? ?? [])
        .map((e) => mapOpsGuest(e as Map<String, dynamic>, checkedIn: false))
        .toList();
    return [...checked, ...pending];
  }

  Future<CheckInResult> checkIn({
    required String eventId,
    String? ticketCode,
    String? entitlementId,
    String source = 'manual',
  }) async {
    final res = await _http.post(
      _u('events/$eventId/check-ins'),
      headers: await _headers(),
      body: jsonEncode({
        if (ticketCode != null) 'ticketCode': ticketCode,
        if (entitlementId != null) 'entitlementId': entitlementId,
        'source': source,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return CheckInResult(
      ok: body['ok'] == true,
      duplicate: body['duplicate'] == true,
      ticketCode: body['ticketCode'] as String?,
      holderName: body['holderName'] as String?,
      tierName: body['tierName'] as String?,
    );
  }

  Future<List<OpsIncident>> listIncidents(String eventId) async {
    final res = await _http.get(_u('events/$eventId/incidents'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => mapOpsIncident(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createIncident({
    required String eventId,
    required String title,
    IncidentCategory category = IncidentCategory.technical,
    IncidentPriority priority = IncidentPriority.medium,
    String reporter = 'staff',
    String description = '',
  }) async {
    final res = await _http.post(
      _u('events/$eventId/incidents'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'category': _incidentCategoryApi(category),
        'priority': priority.name,
        'reporter': reporter,
        'description': description,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['id'] ?? '').toString();
  }

  Future<List<OpsFeedEvent>> listFeed(String eventId) async {
    final res = await _http.get(_u('events/$eventId/feed'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => mapOpsFeed(e as Map<String, dynamic>))
        .toList();
  }
}

class CheckInResult {
  const CheckInResult({
    required this.ok,
    this.duplicate = false,
    this.ticketCode,
    this.holderName,
    this.tierName,
  });

  final bool ok;
  final bool duplicate;
  final String? ticketCode;
  final String? holderName;
  final String? tierName;
}

OpsGuest mapOpsGuest(Map<String, dynamic> json, {required bool checkedIn}) {
  final tierName = (json['tierName'] ?? 'General').toString();
  return OpsGuest(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    email: checkedIn ? '' : (json['name'] ?? '').toString(),
    ticketId: (json['ticketId'] ?? '').toString(),
    tierName: tierName,
    tier: _guestTierFromName(tierName),
    checkedIn: checkedIn,
    checkedInAt: checkedIn && json['checkedInAt'] != null
        ? DateTime.tryParse(json['checkedInAt'].toString())
        : null,
  );
}

GuestTier _guestTierFromName(String tierName) {
  final lower = tierName.toLowerCase();
  if (lower.contains('vvip')) return GuestTier.vvip;
  if (lower.contains('vip')) return GuestTier.vip;
  return GuestTier.general;
}

IncidentCategory mapIncidentCategory(String raw) => switch (raw) {
      'safety' => IncidentCategory.security,
      'crowd' => IncidentCategory.access,
      'vendor' => IncidentCategory.vendor,
      'technical' => IncidentCategory.technical,
      'medical' => IncidentCategory.medical,
      _ => IncidentCategory.technical,
    };

IncidentStatus mapIncidentStatus(String raw) => switch (raw) {
      'resolved' => IncidentStatus.resolved,
      'escalated' => IncidentStatus.investigating,
      _ => IncidentStatus.open,
    };

OpsIncident mapOpsIncident(Map<String, dynamic> json) {
  final at = DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now();
  return OpsIncident(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    category: mapIncidentCategory((json['category'] ?? 'other').toString()),
    priority: IncidentPriority.values.firstWhere(
      (p) => p.name == (json['priority'] ?? 'medium'),
      orElse: () => IncidentPriority.medium,
    ),
    status: mapIncidentStatus((json['status'] ?? 'open').toString()),
    reporter: (json['reporter'] ?? '').toString(),
    reportedAt: at,
    timeline: [OpsIncidentEvent(label: 'Logged', at: at)],
    description: (json['description'] ?? '').toString(),
  );
}

FeedEventType mapFeedType(String raw) => switch (raw) {
      'guest_checked_in' => FeedEventType.guestCheckedIn,
      'vendor_joined' => FeedEventType.vendorJoined,
      'order_placed' => FeedEventType.orderPlaced,
      'refund_requested' => FeedEventType.refundRequested,
      'incident_logged' => FeedEventType.incidentLogged,
      'wall_post' => FeedEventType.wallPost,
      'wall_pinned' => FeedEventType.wallPinned,
      _ => FeedEventType.guestCheckedIn,
    };

OpsFeedEvent mapOpsFeed(Map<String, dynamic> json) {
  return OpsFeedEvent(
    id: (json['id'] ?? '').toString(),
    type: mapFeedType((json['type'] ?? '').toString()),
    headline: (json['headline'] ?? '').toString(),
    detail: (json['detail'] ?? '').toString(),
    timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ?? DateTime.now(),
  );
}

String _incidentCategoryApi(IncidentCategory category) => switch (category) {
      IncidentCategory.security => 'safety',
      IncidentCategory.access => 'crowd',
      IncidentCategory.vendor => 'vendor',
      IncidentCategory.technical => 'technical',
      IncidentCategory.medical => 'medical',
      _ => 'other',
    };
