import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import 'owambe_api_auth.dart';

class IdentityApiException implements Exception {
  IdentityApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() {
    if (code.toUpperCase() == 'INTERNAL' || message.toLowerCase().contains('internal server error')) {
      return 'Internal Server Error';
    }
    return message;
  }
}

class TicketInvitationSummary {
  const TicketInvitationSummary({
    required this.id,
    required this.ticketCode,
    required this.tierName,
    required this.eventId,
    required this.eventTitle,
    required this.eventCity,
    required this.eventVenue,
    required this.startsAt,
    required this.status,
  });

  final String id;
  final String ticketCode;
  final String tierName;
  final String eventId;
  final String eventTitle;
  final String eventCity;
  final String eventVenue;
  final DateTime startsAt;
  final String status;

  factory TicketInvitationSummary.fromJson(Map<String, dynamic> json) {
    return TicketInvitationSummary(
      id: json['id'] as String,
      ticketCode: json['ticketCode'] as String,
      tierName: json['tierName'] as String? ?? 'Ticket',
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String,
      eventCity: json['eventCity'] as String? ?? '',
      eventVenue: json['eventVenue'] as String? ?? '',
      startsAt: DateTime.parse(json['startsAt'] as String),
      status: json['status'] as String? ?? 'issued',
    );
  }
}

class OrganizerProfileView {
  const OrganizerProfileView({
    required this.userId,
    required this.organizerId,
    required this.displayName,
    required this.organizationName,
    required this.phoneE164,
    required this.onboardingStep,
  });

  final String userId;
  final String? organizerId;
  final String displayName;
  final String organizationName;
  final String? phoneE164;
  final String onboardingStep;

  bool get isComplete => onboardingStep == 'complete';

  factory OrganizerProfileView.fromJson(Map<String, dynamic> json) {
    return OrganizerProfileView(
      userId: json['userId'] as String,
      organizerId: json['organizerId'] as String?,
      displayName: json['displayName'] as String? ?? '',
      organizationName: json['organizationName'] as String? ?? '',
      phoneE164: json['phoneE164'] as String?,
      onboardingStep: json['onboardingStep'] as String? ?? 'profile',
    );
  }
}

class IdentityApi {
  IdentityApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId();

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw IdentityApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is IdentityApiException) rethrow;
      throw IdentityApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<List<TicketInvitationSummary>> lookupInvitations({
    String? email,
    String? phone,
  }) async {
    final res = await _http.post(
      _u('public/ticket-invitations/lookup'),
      headers: {
        ...OwambeApiAuth.publicHeaders(tenantId: _tenantId),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => TicketInvitationSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> linkEntitlements({String? email, String? phone}) async {
    final res = await _http.post(
      _u('me/ticket-entitlements/link'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['linkedCount'] as num?)?.toInt() ?? 0;
  }

  Future<OrganizerProfileView> fetchOrganizerProfile(AuthSession session) async {
    final res = await _http.get(
      _u('me/organizer-profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return OrganizerProfileView.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OrganizerProfileView> upsertOrganizerProfile(
    AuthSession session, {
    String? displayName,
    String? organizationName,
    String? phoneE164,
    String? onboardingStep,
    bool markEmailVerified = false,
    bool markPhoneVerified = false,
  }) async {
    final res = await _http.put(
      _u('me/organizer-profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        if (displayName != null) 'displayName': displayName,
        if (organizationName != null) 'organizationName': organizationName,
        if (phoneE164 != null) 'phoneE164': phoneE164,
        if (onboardingStep != null) 'onboardingStep': onboardingStep,
        if (markEmailVerified) 'markEmailVerified': true,
        if (markPhoneVerified) 'markPhoneVerified': true,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return OrganizerProfileView.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<String?> resolveVendorId(AuthSession session) async {
    final res = await _http.get(
      _u('me/vendor-id'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['vendorId'] as String?;
  }
}
