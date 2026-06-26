import 'dart:convert';

import 'package:http/http.dart' as http;

import 'events_api.dart';
import 'owanbe_api_auth.dart';

class EventGuestRecord {
  const EventGuestRecord({
    required this.id,
    required this.name,
    this.email,
    this.phoneE164,
    this.groupLabel,
    required this.rsvpStatus,
    this.guestRef,
    required this.source,
  });

  final String id;
  final String name;
  final String? email;
  final String? phoneE164;
  final String? groupLabel;
  final String rsvpStatus;
  final String? guestRef;
  final String source;
}

class InvitationHubStats {
  const InvitationHubStats({
    required this.sent,
    required this.delivered,
    required this.opened,
    required this.rsvp,
  });

  final int sent;
  final int delivered;
  final int opened;
  final int rsvp;
}

class InvitationRecord {
  const InvitationRecord({
    required this.id,
    required this.guestId,
    required this.guestName,
    this.guestEmail,
    required this.channel,
    required this.status,
    required this.deliveryStatus,
  });

  final String id;
  final String guestId;
  final String guestName;
  final String? guestEmail;
  final String channel;
  final String status;
  final String deliveryStatus;
}

class EventGuestsApi {
  EventGuestsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId(EventsApi.devTenantId);

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

  EventGuestRecord _mapGuest(Map<String, dynamic> json) => EventGuestRecord(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        email: json['email']?.toString(),
        phoneE164: json['phoneE164']?.toString(),
        groupLabel: json['groupLabel']?.toString(),
        rsvpStatus: (json['rsvpStatus'] ?? 'pending').toString(),
        guestRef: json['guestRef']?.toString(),
        source: (json['source'] ?? 'manual').toString(),
      );

  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    final res = await _http.get(
      _u('events/$eventId/guests'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => _mapGuest(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventGuestRecord> addGuest(
    String eventId, {
    required String name,
    String? email,
    String? phoneE164,
    String? groupLabel,
  }) async {
    final res = await _http.post(
      _u('events/$eventId/guests'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'name': name,
        if (email != null) 'email': email,
        if (phoneE164 != null) 'phoneE164': phoneE164,
        if (groupLabel != null) 'groupLabel': groupLabel,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return _mapGuest(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<({int sent, List<InvitationRecord> items, InvitationHubStats stats})> fetchInvitationHub(
    String eventId,
  ) async {
    final res = await _http.get(
      _u('events/$eventId/invitations'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final statsJson = body['stats'] as Map<String, dynamic>? ?? {};
    final stats = InvitationHubStats(
      sent: (statsJson['sent'] as num?)?.toInt() ?? 0,
      delivered: (statsJson['delivered'] as num?)?.toInt() ?? 0,
      opened: (statsJson['opened'] as num?)?.toInt() ?? 0,
      rsvp: (statsJson['rsvp'] as num?)?.toInt() ?? 0,
    );
    final items = (body['items'] as List<dynamic>? ?? [])
        .map(
          (e) {
            final m = e as Map<String, dynamic>;
            return InvitationRecord(
              id: (m['id'] ?? '').toString(),
              guestId: (m['guestId'] ?? '').toString(),
              guestName: (m['guestName'] ?? '').toString(),
              guestEmail: m['guestEmail']?.toString(),
              channel: (m['channel'] ?? 'link').toString(),
              status: (m['status'] ?? 'draft').toString(),
              deliveryStatus: (m['deliveryStatus'] ?? 'pending').toString(),
            );
          },
        )
        .toList();
    return (sent: stats.sent, items: items, stats: stats);
  }

  Future<int> sendInvitations(
    String eventId, {
    List<String>? guestIds,
    String channel = 'link',
    String? templateId,
  }) async {
    final res = await _http.post(
      _u('events/$eventId/invitations/send'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        if (guestIds != null) 'guestIds': guestIds,
        'channel': channel,
        if (templateId != null) 'templateId': templateId,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['sent'] as num?)?.toInt() ?? 0;
  }
}
