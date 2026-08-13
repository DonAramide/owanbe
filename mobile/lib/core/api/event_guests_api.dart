import 'dart:convert';

import 'package:http/http.dart' as http;

import 'events_api.dart';
import 'owambe_api_auth.dart';

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
    this.pending = 0,
    this.declined = 0,
    this.ticketsIssued = 0,
    this.totalInvited = 0,
  });

  final int sent;
  final int delivered;
  final int opened;
  final int rsvp;
  final int pending;
  final int declined;
  final int ticketsIssued;
  final int totalInvited;
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
    this.rsvpStatus,
    this.ticketIssued = false,
    this.sentAt,
    this.respondedAt,
  });

  final String id;
  final String guestId;
  final String guestName;
  final String? guestEmail;
  final String channel;
  final String status;
  final String deliveryStatus;
  final String? rsvpStatus;
  final bool ticketIssued;
  final String? sentAt;
  final String? respondedAt;

  bool get hasBeenSent => id.isNotEmpty && status != 'not_sent';
}

class InvitationHubGuest {
  const InvitationHubGuest({
    required this.id,
    required this.name,
    this.email,
    required this.rsvpStatus,
    this.ticketIssued = false,
    this.invitedAt,
    this.respondedAt,
  });

  final String id;
  final String name;
  final String? email;
  final String rsvpStatus;
  final bool ticketIssued;
  final String? invitedAt;
  final String? respondedAt;
}

class InvitationHubPayload {
  const InvitationHubPayload({
    required this.stats,
    required this.items,
    required this.guests,
  });

  final InvitationHubStats stats;
  final List<InvitationRecord> items;
  final List<InvitationHubGuest> guests;
}

class EventGuestsApi {
  EventGuestsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId(EventsApi.devTenantId);

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
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
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
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
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

  Future<InvitationHubPayload> fetchInvitationHub(String eventId) async {
    final res = await _http.get(
      _u('events/$eventId/invitations'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final statsJson = body['stats'] as Map<String, dynamic>? ?? {};
    final stats = InvitationHubStats(
      sent: (statsJson['sent'] as num?)?.toInt() ?? 0,
      delivered: (statsJson['delivered'] as num?)?.toInt() ?? 0,
      opened: (statsJson['opened'] as num?)?.toInt() ?? 0,
      rsvp: (statsJson['rsvp'] as num?)?.toInt() ?? 0,
      pending: (statsJson['pending'] as num?)?.toInt() ?? 0,
      declined: (statsJson['declined'] as num?)?.toInt() ?? 0,
      ticketsIssued: (statsJson['ticketsIssued'] as num?)?.toInt() ?? 0,
      totalInvited: (statsJson['totalInvited'] as num?)?.toInt() ?? 0,
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
              deliveryStatus: (m['deliveryStatus'] ?? m['status'] ?? 'pending').toString(),
              rsvpStatus: m['rsvpStatus']?.toString(),
              ticketIssued: m['ticketIssued'] == true,
              sentAt: m['sentAt']?.toString(),
              respondedAt: m['respondedAt']?.toString(),
            );
          },
        )
        .toList();
    final guests = (body['guests'] as List<dynamic>? ?? [])
        .map(
          (e) {
            final m = e as Map<String, dynamic>;
            return InvitationHubGuest(
              id: (m['id'] ?? '').toString(),
              name: (m['name'] ?? '').toString(),
              email: m['email']?.toString(),
              rsvpStatus: (m['rsvpStatus'] ?? 'pending').toString(),
              ticketIssued: m['ticketIssued'] == true,
              invitedAt: m['invitedAt']?.toString(),
              respondedAt: m['respondedAt']?.toString(),
            );
          },
        )
        .toList();
    return InvitationHubPayload(stats: stats, items: items, guests: guests);
  }

  Future<int> sendInvitations(
    String eventId, {
    List<String>? guestIds,
    String channel = 'email',
    String? templateId,
  }) async {
    final res = await _http.post(
      _u('events/$eventId/invitations/send'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
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

  Future<String?> createInviteLink(String eventId, String guestId) async {
    final res = await _http.post(
      _u('events/$eventId/guests/$guestId/invite-link'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({}),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['inviteUrl']?.toString();
  }

  Future<void> resendInvitation(String eventId, String invitationId) async {
    final res = await _http.post(
      _u('events/$eventId/invitations/$invitationId/resend'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> cancelInvitation(String eventId, String invitationId) async {
    final res = await _http.post(
      _u('events/$eventId/invitations/$invitationId/cancel'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> inviteUser(String eventId, {required String userId, String channel = 'email'}) async {
    final res = await _http.post(
      _u('events/$eventId/guests/invite-user'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'userId': userId, 'channel': channel}),
    );
    if (res.statusCode >= 400) _throw(res);
  }
}
