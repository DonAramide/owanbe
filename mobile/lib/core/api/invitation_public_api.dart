import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owambe_api_auth.dart';

class InvitationPublicApiException implements Exception {
  InvitationPublicApiException({required this.code, required this.message, this.reason});
  final String code;
  final String message;
  final String? reason;

  @override
  String toString() => message;
}

class InvitationValidateResult {
  InvitationValidateResult({
    required this.valid,
    required this.eventId,
    required this.eventTitle,
    required this.guestId,
    required this.guestName,
    required this.rsvpStatus,
    this.expiresAt,
    this.usedAt,
    this.startsAt,
    this.venue,
    this.city,
    this.reason,
  });

  final bool valid;
  final String eventId;
  final String eventTitle;
  final String guestId;
  final String guestName;
  final String rsvpStatus;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final DateTime? startsAt;
  final String? venue;
  final String? city;
  final String? reason;

  factory InvitationValidateResult.fromJson(Map<String, dynamic> json) {
    return InvitationValidateResult(
      valid: json['valid'] != false,
      eventId: (json['eventId'] ?? '').toString(),
      eventTitle: (json['eventTitle'] ?? 'Event').toString(),
      guestId: (json['guestId'] ?? '').toString(),
      guestName: (json['guestName'] ?? 'Guest').toString(),
      rsvpStatus: (json['rsvpStatus'] ?? 'pending').toString(),
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()),
      usedAt: DateTime.tryParse((json['usedAt'] ?? '').toString()),
      startsAt: DateTime.tryParse((json['startsAt'] ?? '').toString()),
      venue: json['venue']?.toString(),
      city: json['city']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}

class InvitationRsvpResult {
  InvitationRsvpResult({
    required this.rsvpStatus,
    this.entitlementId,
    this.ticketCode,
  });

  final String rsvpStatus;
  final String? entitlementId;
  final String? ticketCode;
}

/// Public invitation validate / RSVP (token deep-link).
class InvitationPublicApi {
  InvitationPublicApi({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const _devTenant = '11111111-1111-4111-8111-111111111111';
  static const _timeout = Duration(seconds: 15);

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId(_devTenant);

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw InvitationPublicApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
        reason: body['reason']?.toString(),
      );
    } catch (e) {
      if (e is InvitationPublicApiException) rethrow;
      throw InvitationPublicApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<InvitationValidateResult> validate(String token) async {
    final res = await _http
        .get(
          _u('invitations/validate', {'token': token}),
          headers: OwambeApiAuth.publicHeaders(tenantId: _tenantId),
        )
        .timeout(_timeout);
    if (res.statusCode >= 400) {
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        // Soft-parse expired/cancelled payloads that include event fields.
        if (body['eventId'] != null) {
          return InvitationValidateResult(
            valid: false,
            eventId: (body['eventId'] ?? '').toString(),
            eventTitle: (body['eventTitle'] ?? 'Event').toString(),
            guestId: (body['guestId'] ?? '').toString(),
            guestName: (body['guestName'] ?? 'Guest').toString(),
            rsvpStatus: (body['rsvpStatus'] ?? 'pending').toString(),
            expiresAt: DateTime.tryParse((body['expiresAt'] ?? '').toString()),
            reason: (body['reason'] ?? body['code'] ?? 'invalid').toString().toLowerCase(),
          );
        }
      } catch (_) {}
      _throw(res);
    }
    return InvitationValidateResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<InvitationRsvpResult> rsvp({
    required String token,
    required String status,
  }) async {
    final res = await _http
        .post(
          _u('invitations/rsvp'),
          headers: {
            ...OwambeApiAuth.publicHeaders(tenantId: _tenantId),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'token': token, 'status': status}),
        )
        .timeout(_timeout);
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return InvitationRsvpResult(
      rsvpStatus: (body['rsvpStatus'] ?? status).toString(),
      entitlementId: body['entitlementId']?.toString(),
      ticketCode: body['ticketCode']?.toString(),
    );
  }
}
