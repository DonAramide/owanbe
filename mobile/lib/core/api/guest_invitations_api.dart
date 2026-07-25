import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import 'owambe_api_auth.dart';

class GuestInvitationApiException implements Exception {
  GuestInvitationApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => message;
}

class GuestInvitationItem {
  GuestInvitationItem({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.rsvpStatus,
    required this.startsAt,
    this.eventCity = '',
    this.eventVenue = '',
    this.guestName = '',
    this.endsAt,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String rsvpStatus;
  final DateTime startsAt;
  final String eventCity;
  final String eventVenue;
  final String guestName;
  final DateTime? endsAt;

  bool get isPending =>
      rsvpStatus == 'invited' || rsvpStatus == 'pending';

  factory GuestInvitationItem.fromJson(Map<String, dynamic> json) {
    return GuestInvitationItem(
      id: (json['id'] ?? json['guestId'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      eventTitle: (json['eventTitle'] ?? 'Event').toString(),
      rsvpStatus: (json['rsvpStatus'] ?? 'pending').toString(),
      startsAt: DateTime.tryParse((json['startsAt'] ?? '').toString()) ?? DateTime.now(),
      endsAt: DateTime.tryParse((json['endsAt'] ?? '').toString()),
      eventCity: (json['eventCity'] ?? '').toString(),
      eventVenue: (json['eventVenue'] ?? '').toString(),
      guestName: (json['guestName'] ?? '').toString(),
    );
  }
}

class GuestInvitationsApi {
  GuestInvitationsApi({http.Client? client}) : _http = client ?? http.Client();

  static const _timeout = Duration(seconds: 12);
  final http.Client _http;
  static const _devTenant = '11111111-1111-4111-8111-111111111111';

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId(_devTenant);

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw GuestInvitationApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is GuestInvitationApiException) rethrow;
      throw GuestInvitationApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<List<GuestInvitationItem>> fetchMine(AuthSession session) async {
    final res = await _http
        .get(
          _u('me/guest-invitations'),
          headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
        )
        .timeout(_timeout);
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => GuestInvitationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> respond({
    required AuthSession session,
    required String guestId,
    required String status,
  }) async {
    final res = await _http
        .post(
          _u('me/guest-invitations/$guestId/rsvp'),
          headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
          body: jsonEncode({'status': status}),
        )
        .timeout(_timeout);
    if (res.statusCode >= 400) _throw(res);
  }
}
