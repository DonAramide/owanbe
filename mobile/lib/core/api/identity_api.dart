import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import '../../identity/workspace_models.dart';
import 'owanbe_api_auth.dart';

class IdentityApiException implements Exception {
  IdentityApiException({required this.code, required this.message});
  final String code;
  final String message;

  bool get isRoleMismatch => code.toUpperCase() == 'ROLE_MISMATCH';
  bool get isNotRegistered => code.toUpperCase() == 'NOT_REGISTERED';
  bool get isUserPersistFailed => code.toUpperCase() == 'USER_PERSIST_FAILED';
  bool get isApiUnavailable =>
      code.toUpperCase().startsWith('HTTP_') &&
      (code.contains('502') ||
          code.contains('503') ||
          code.contains('504') ||
          code == 'HTTP_CONNECTION' ||
          code == 'HTTP_TIMEOUT' ||
          message.toLowerCase().contains('connection refused') ||
          message.toLowerCase().contains('failed host lookup'));

  @override
  String toString() {
    if (code.toUpperCase() == 'INTERNAL' || message.toLowerCase().contains('internal server error')) {
      return 'Internal Server Error';
    }
    return message;
  }
}

class PortalLookupResult {
  const PortalLookupResult({
    required this.registered,
    this.portal,
  });

  final bool registered;
  final String? portal;
}

class AuthMeResult {
  const AuthMeResult({
    required this.userId,
    required this.email,
    this.displayName,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.bio,
    this.occupation,
    this.company,
    this.interests = const [],
    this.socialLinks = const {},
    required this.roles,
    this.signupPortal,
    this.onboardingComplete = false,
    this.lastActiveWorkspace,
    this.workspaces = const [],
    this.identityVersion = '2.0',
  });

  final String userId;
  final String email;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? bio;
  final String? occupation;
  final String? company;
  final List<String> interests;
  final Map<String, String> socialLinks;
  final List<String> roles;
  final String? signupPortal;
  final bool onboardingComplete;
  final String? lastActiveWorkspace;
  final List<WorkspaceState> workspaces;
  final String identityVersion;
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

  static const _timeout = Duration(seconds: 12);
  final http.Client _http;

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) =>
      _request(() => _http.get(uri, headers: headers));

  Future<http.Response> _post(Uri uri, {Map<String, String>? headers, Object? body}) =>
      _request(() => _http.post(uri, headers: headers, body: body));

  Future<http.Response> _put(Uri uri, {Map<String, String>? headers, Object? body}) =>
      _request(() => _http.put(uri, headers: headers, body: body));

  Future<http.Response> _patch(Uri uri, {Map<String, String>? headers, Object? body}) =>
      _request(() => _http.patch(uri, headers: headers, body: body));

  Future<http.Response> _request(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on SocketException catch (e) {
      throw IdentityApiException(
        code: 'HTTP_CONNECTION',
        message: e.message.isNotEmpty ? e.message : 'Connection refused',
      );
    } on TimeoutException {
      throw IdentityApiException(code: 'HTTP_TIMEOUT', message: 'Request timed out');
    }
  }

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
    final res = await _post(
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
    final res = await _post(
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
    final res = await _get(
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
    final res = await _put(
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

  /// Organizer workspace profile — `organizer_profiles` only (not `users`).
  Future<Map<String, dynamic>> fetchOrganizerWorkspaceProfileRaw() async {
    final res = await _get(
      _u('me/organizer-profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateOrganizerWorkspaceProfileRaw(
    Map<String, dynamic> body,
  ) async {
    final res = await _patch(
      _u('me/organizer-profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Attendee workspace profile — `attendee_profiles` only (not `users`).
  Future<Map<String, dynamic>> fetchAttendeeProfileRaw() async {
    final res = await _get(
      _u('me/attendee-profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAttendeeProfileRaw(Map<String, dynamic> body) async {
    final res = await _put(
      _u('me/attendee-profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Vendor workspace profile — `vendor_profiles` only (not `users`).
  Future<Map<String, dynamic>> fetchVendorWorkspaceProfileRaw() async {
    final res = await _get(
      _u('me/vendor-profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateVendorWorkspaceProfileRaw(
    Map<String, dynamic> body,
  ) async {
    final res = await _patch(
      _u('me/vendor-profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String?> resolveVendorId(AuthSession session) async {
    final res = await _get(
      _u('me/vendor-id'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['vendorId'] as String?;
  }

  Future<PortalLookupResult> lookupPortal({required String email}) async {
    final res = await _post(
      _u('auth/portal-lookup'),
      headers: {
        ...OwambeApiAuth.publicHeaders(tenantId: _tenantId),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email.trim()}),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return PortalLookupResult(
      registered: body['registered'] as bool? ?? false,
      portal: body['portal'] as String?,
    );
  }

  Future<Map<String, dynamic>> completeSignup({required String portal}) async {
    final uri = _u('auth/complete-signup');
    debugPrint('IdentityApi POST $uri');
    final res = await _post(
      uri,
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'portal': portal}),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validatePortal({required String portal}) async {
    final uri = _u('auth/validate-portal');
    debugPrint('IdentityApi POST $uri');
    final res = await _post(
      uri,
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'portal': portal}),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<AuthMeResult> fetchMe() async {
    final res = await _get(
      _u('auth/me'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return _parseAuthMe(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Hub global profile update (`PATCH /me/profile`). Does not touch workspace profiles.
  Future<AuthMeResult> updateGlobalProfile({
    String? firstName,
    String? lastName,
    String? displayName,
    String? bio,
    String? occupation,
    String? company,
    List<String>? interests,
    Map<String, String>? socialLinks,
    String? avatarUrl,
    bool clearAvatar = false,
    bool updateAvatar = false,
  }) async {
    final body = <String, dynamic>{
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (occupation != null) 'occupation': occupation,
      if (company != null) 'company': company,
      if (interests != null) 'interests': interests,
      if (socialLinks != null) 'socialLinks': socialLinks,
      if (updateAvatar) 'avatarUrl': clearAvatar ? null : avatarUrl,
    };
    final res = await _patch(
      _u('me/profile'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return _parseAuthMe(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> fetchAttendeeProfileCard({String? userId}) async {
    final path = (userId == null || userId.isEmpty)
        ? 'me/attendee-profile-card'
        : 'users/$userId/attendee-profile-card';
    final res = await _get(
      _u(path),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  AuthMeResult _parseAuthMe(Map<String, dynamic> body) {
    final workspacesRaw = body['workspaces'] as List<dynamic>? ?? const [];
    final interestsRaw = body['interests'] as List<dynamic>? ?? const [];
    final socialRaw = body['socialLinks'];
    final socialLinks = <String, String>{};
    if (socialRaw is Map) {
      for (final e in socialRaw.entries) {
        final v = e.value?.toString().trim() ?? '';
        if (v.isNotEmpty) socialLinks[e.key.toString()] = v;
      }
    }
    return AuthMeResult(
      userId: body['userId'] as String,
      email: body['email'] as String? ?? '',
      displayName: body['displayName'] as String?,
      firstName: body['firstName'] as String?,
      lastName: body['lastName'] as String?,
      avatarUrl: body['avatarUrl'] as String?,
      bio: body['bio'] as String?,
      occupation: body['occupation'] as String?,
      company: body['company'] as String?,
      interests: interestsRaw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
      socialLinks: socialLinks,
      roles: (body['roles'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      signupPortal: body['signupPortal'] as String?,
      onboardingComplete: body['onboardingComplete'] as bool? ?? false,
      lastActiveWorkspace: body['lastActiveWorkspace'] as String?,
      workspaces: workspacesRaw
          .map((e) => WorkspaceState.fromJson(e as Map<String, dynamic>))
          .toList(),
      identityVersion: body['identityVersion'] as String? ?? '2.0',
    );
  }

  Future<void> ensureUser({String? displayName}) async {
    final res = await _post(
      _u('auth/ensure-user'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<List<WorkspaceState>> fetchWorkspaces() async {
    final res = await _get(
      _u('me/workspaces'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as List<dynamic>;
    return body.map((e) => WorkspaceState.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> activateWorkspace({
    required String workspace,
    Map<String, dynamic>? draft,
  }) async {
    final res = await _post(
      _u('me/roles/activate'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'workspace': workspace,
        if (draft != null) 'draft': draft,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> setActiveWorkspace(String workspace) async {
    final res = await _post(
      _u('me/active-workspace'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'workspace': workspace}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> completeOnboarding({
    String? displayName,
    String? phoneE164,
    String? workspace,
  }) async {
    final res = await _post(
      _u('auth/complete-onboarding'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
        if (phoneE164 != null && phoneE164.trim().isNotEmpty) 'phoneE164': phoneE164.trim(),
        if (workspace != null && workspace.trim().isNotEmpty) 'workspace': workspace.trim(),
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }
}
