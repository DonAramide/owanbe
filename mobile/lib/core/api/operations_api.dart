import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/operations/models/operations_models.dart';
import 'events_api.dart';
import 'owambe_api_auth.dart';

class OperationsApi {
  OperationsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();

  String get _tenantId => OwambeApiAuth.resolveTenantId(EventsApi.devTenantId);

  Future<Map<String, String>> _headers({bool json = true}) =>
      OwambeApiAuth.authorizedHeaders(tenantId: _tenantId, json: json);

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        final nested = body['message'];
        if (nested is Map<String, dynamic>) {
          throw EventsApiException(
            code: (nested['code'] ?? body['code'] ?? 'HTTP_${res.statusCode}').toString(),
            message: (nested['message'] ?? nested['error'] ?? 'Request failed').toString(),
          );
        }
        throw EventsApiException(
          code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
          message: (body['message'] ?? 'Request failed').toString(),
        );
      }
    } catch (e) {
      if (e is EventsApiException) rethrow;
    }
    throw EventsApiException(code: 'HTTP_${res.statusCode}', message: res.body);
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

  Future<LiveEventKpis> fetchDoorSummary(String eventId, {int openIncidents = 0}) async {
    final res = await _http.get(_u('events/$eventId/door-summary'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return mapDoorSummary(body, openIncidents: openIncidents);
  }

  Future<CheckInResult> checkIn({
    required String eventId,
    String? ticketCode,
    String? entitlementId,
    String source = 'manual',
  }) async {
    final resolvedCode = ticketCode == null ? null : resolveDoorTicketInput(ticketCode);
    final res = await _http.post(
      _u('events/$eventId/check-ins'),
      headers: await _headers(),
      body: jsonEncode({
        if (resolvedCode != null && resolvedCode.isNotEmpty) 'ticketCode': ticketCode,
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
      invitation: body['invitation'] == true,
      doorStatus: (body['doorStatus'] ?? '').toString(),
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

  /// Subscribe to existing `GET events/:id/feed/stream` SSE.
  /// Yields parsed feed events; reconnect is caller's responsibility.
  Stream<OpsFeedEvent> streamFeed(String eventId) async* {
    final headers = await _headers(json: false);
    headers['Accept'] = 'text/event-stream';
    final request = http.Request('GET', _u('events/$eventId/feed/stream'));
    request.headers.addAll(headers);
    final response = await _http.send(request);
    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw EventsApiException(code: 'HTTP_${response.statusCode}', message: body);
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final sep = buffer.indexOf('\n\n');
        if (sep < 0) break;
        final frame = buffer.substring(0, sep);
        buffer = buffer.substring(sep + 2);
        final dataLines = frame
            .split('\n')
            .where((l) => l.startsWith('data:'))
            .map((l) => l.substring(5).trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (dataLines.isEmpty) continue;
        final raw = dataLines.join('\n');
        try {
          final json = jsonDecode(raw);
          if (json is! Map<String, dynamic>) continue;
          final type = (json['type'] ?? '').toString();
          if (type == 'connected' || type == 'ping') continue;
          final feedType = (json['feedType'] ?? json['type'] ?? '').toString();
          if (feedType.isEmpty || feedType == 'feed' || feedType == 'connected') {
            // Nested payload from `{ type: 'feed', feedType, headline, ... }`
          }
          final resolvedType = (json['feedType'] ?? '').toString();
          if (resolvedType.isEmpty) continue;
          yield OpsFeedEvent(
            id: 'sse-${json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}-$resolvedType',
            type: mapFeedType(resolvedType),
            headline: (json['headline'] ?? '').toString(),
            detail: (json['detail'] ?? '').toString(),
            timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ?? DateTime.now(),
          );
        } catch (_) {
          // Ignore malformed SSE frames.
        }
      }
    }
  }

  Future<OpsIncident> updateIncidentStatus(String eventId, String incidentId, IncidentStatus status) async {
    final res = await _http.patch(
      _u('events/$eventId/incidents/$incidentId'),
      headers: await _headers(),
      body: jsonEncode({'status': _incidentStatusApi(status)}),
    );
    if (res.statusCode >= 400) _throw(res);
    return mapOpsIncident(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class CheckInResult {
  const CheckInResult({
    required this.ok,
    this.duplicate = false,
    this.ticketCode,
    this.holderName,
    this.tierName,
    this.invitation = false,
    this.doorStatus = '',
  });

  final bool ok;
  final bool duplicate;
  final String? ticketCode;
  final String? holderName;
  final String? tierName;
  final bool invitation;
  final String doorStatus;
}

OpsGuest mapOpsGuest(Map<String, dynamic> json, {required bool checkedIn}) {
  final tierName = (json['tierName'] ?? 'General').toString();
  final doorRaw = (json['doorStatus'] ?? (checkedIn ? 'inside' : 'registered')).toString();
  final doorStatus = switch (doorRaw) {
    'checked_in' => DoorAttendeeStatus.checkedIn,
    'checkedIn' => DoorAttendeeStatus.checkedIn,
    'inside' => DoorAttendeeStatus.inside,
    'completed' => DoorAttendeeStatus.completed,
    _ => DoorAttendeeStatus.registered,
  };
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
    doorStatus: doorStatus,
    source: json['source']?.toString(),
  );
}

LiveEventKpis mapDoorSummary(Map<String, dynamic> json, {int openIncidents = 0}) {
  final checkedIn = _asInt(json['checkedIn']);
  final remaining = _asInt(json['remaining']);
  final total = _asInt(json['totalActive'], fallback: checkedIn + remaining);
  return LiveEventKpis(
    checkedIn: checkedIn,
    remainingGuests: remaining,
    capacity: _asInt(json['capacity'], fallback: total),
    noShows: _asInt(json['noShows'], fallback: remaining),
    attendancePct: _asDouble(json['attendancePct']),
    capacityPct: _asDouble(json['capacityPct']),
    vendorsActive: 0,
    ordersToday: 0,
    revenueTodayMinor: 0,
    openIncidents: openIncidents,
    totalRegistered: total,
    checkInsLast15m: _asInt(json['checkInsLast15m']),
    checkInsLast60m: _asInt(json['checkInsLast60m']),
    queueState: (json['queueState'] ?? 'quiet').toString(),
    eventStatus: (json['eventStatus'] ?? 'published').toString(),
    recentArrivals: (json['recentArrivals'] as List<dynamic>? ?? [])
        .map((e) {
          final m = e as Map<String, dynamic>;
          return DoorArrival(
            ticketCode: (m['ticketCode'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            tierName: (m['tierName'] ?? '').toString(),
            source: (m['source'] ?? '').toString(),
            checkedInAt: DateTime.tryParse((m['checkedInAt'] ?? '').toString()) ?? DateTime.now(),
          );
        })
        .toList(),
  );
}

int _asInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
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
      'invitation_arrival' => FeedEventType.invitationArrival,
      'check_in_duplicate' => FeedEventType.checkInDuplicate,
      'check_in_invalid' => FeedEventType.checkInInvalid,
      'vendor_joined' => FeedEventType.vendorJoined,
      'order_placed' => FeedEventType.orderPlaced,
      'refund_requested' => FeedEventType.refundRequested,
      'incident_logged' => FeedEventType.incidentLogged,
      'incident_updated' => FeedEventType.incidentUpdated,
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
    };

String _incidentStatusApi(IncidentStatus status) => switch (status) {
      IncidentStatus.open => 'open',
      IncidentStatus.investigating => 'escalated',
      IncidentStatus.resolved => 'resolved',
    };
