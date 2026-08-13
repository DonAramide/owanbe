import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../auth/auth_notifier.dart';
import '../../../auth/auth_session.dart';
import '../../../core/api/owambe_api_auth.dart';

class OrganizerTeamApiException implements Exception {
  OrganizerTeamApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'OrganizerTeamApiException($code): $message';
}

class OrganizerMember {
  const OrganizerMember({
    required this.id,
    required this.organizerId,
    required this.email,
    required this.orgRole,
    required this.status,
    required this.isOwner,
    required this.capabilities,
    this.userId,
    this.displayName,
    this.invitedAt,
    this.acceptedAt,
    this.inviteToken,
  });

  final String id;
  final String organizerId;
  final String? userId;
  final String email;
  final String? displayName;
  final String orgRole;
  final String status;
  final bool isOwner;
  final List<String> capabilities;
  final String? invitedAt;
  final String? acceptedAt;
  final String? inviteToken;

  factory OrganizerMember.fromJson(Map<String, dynamic> json) => OrganizerMember(
        id: (json['id'] ?? '').toString(),
        organizerId: (json['organizerId'] ?? '').toString(),
        userId: json['userId']?.toString(),
        email: (json['email'] ?? '').toString(),
        displayName: json['displayName']?.toString(),
        orgRole: (json['orgRole'] ?? 'staff').toString(),
        status: (json['status'] ?? '').toString(),
        isOwner: json['isOwner'] == true,
        capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        invitedAt: json['invitedAt']?.toString(),
        acceptedAt: json['acceptedAt']?.toString(),
        inviteToken: json['inviteToken']?.toString(),
      );
}

class OrganizerTeamActivityItem {
  const OrganizerTeamActivityItem({
    required this.id,
    required this.action,
    required this.label,
    required this.createdAt,
    this.actorEmail,
  });

  final String id;
  final String action;
  final String label;
  final String createdAt;
  final String? actorEmail;

  factory OrganizerTeamActivityItem.fromJson(Map<String, dynamic> json) => OrganizerTeamActivityItem(
        id: (json['id'] ?? '').toString(),
        action: (json['action'] ?? '').toString(),
        label: (json['label'] ?? json['action'] ?? '').toString(),
        createdAt: (json['createdAt'] ?? '').toString(),
        actorEmail: json['actorEmail']?.toString(),
      );
}

class OrganizerTeamDirectory {
  const OrganizerTeamDirectory({
    required this.items,
    required this.organizerId,
    required this.organizationName,
  });

  final List<OrganizerMember> items;
  final String organizerId;
  final String organizationName;
}

class OrganizerTeamApi {
  OrganizerTeamApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId();

  Future<Map<String, String>> _headers([AuthSession? session]) =>
      OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);

  Uri _u(String path, [Map<String, String>? q]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: q);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        final nested = body['message'];
        if (nested is Map<String, dynamic>) {
          throw OrganizerTeamApiException(
            code: (nested['code'] ?? body['code'] ?? 'HTTP_${res.statusCode}').toString(),
            message: (nested['message'] ?? 'Request failed').toString(),
          );
        }
        throw OrganizerTeamApiException(
          code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
          message: (body['message'] ?? 'Request failed').toString(),
        );
      }
    } catch (e) {
      if (e is OrganizerTeamApiException) rethrow;
    }
    throw OrganizerTeamApiException(code: 'HTTP_${res.statusCode}', message: res.body);
  }

  Future<OrganizerTeamDirectory> listMembers({
    String? q,
    String? role,
    String? status,
    AuthSession? session,
  }) async {
    final query = <String, String>{};
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (role != null && role.isNotEmpty) query['role'] = role;
    if (status != null && status.isNotEmpty) query['status'] = status;
    final res = await _http.get(_u('organizers/me/team', query.isEmpty ? null : query), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return OrganizerTeamDirectory(
      items: (body['items'] as List<dynamic>? ?? [])
          .map((e) => OrganizerMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      organizerId: (body['organizerId'] ?? '').toString(),
      organizationName: (body['organizationName'] ?? '').toString(),
    );
  }

  Future<List<OrganizerTeamActivityItem>> listActivity({AuthSession? session}) async {
    final res = await _http.get(_u('organizers/me/team/activity'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => OrganizerTeamActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrganizerMember> invite({
    required String email,
    String orgRole = 'staff',
    AuthSession? session,
  }) async {
    final res = await _http.post(
      _u('organizers/me/team/invites'),
      headers: await _headers(session),
      body: jsonEncode({'email': email, 'orgRole': orgRole}),
    );
    if (res.statusCode >= 400) _throw(res);
    return OrganizerMember.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OrganizerMember> acceptInvite({required String token, AuthSession? session}) async {
    final res = await _http.post(
      _u('organizers/me/team/invites/accept'),
      headers: await _headers(session),
      body: jsonEncode({'token': token}),
    );
    if (res.statusCode >= 400) _throw(res);
    return OrganizerMember.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OrganizerMember> updateRole({
    required String memberId,
    required String orgRole,
    AuthSession? session,
  }) async {
    final res = await _http.patch(
      _u('organizers/me/team/members/$memberId/role'),
      headers: await _headers(session),
      body: jsonEncode({'orgRole': orgRole}),
    );
    if (res.statusCode >= 400) _throw(res);
    return OrganizerMember.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> revoke({required String memberId, AuthSession? session}) async {
    final res = await _http.post(
      _u('organizers/me/team/members/$memberId/revoke'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<Map<String, dynamic>> myMembership({AuthSession? session}) async {
    final res = await _http.get(_u('organizers/me/membership'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

final organizerTeamApiProvider = Provider<OrganizerTeamApi>((ref) => OrganizerTeamApi());

final organizerTeamDirectoryProvider = FutureProvider.autoDispose<OrganizerTeamDirectory>((ref) async {
  final session = ref.watch(authSessionProvider);
  return ref.read(organizerTeamApiProvider).listMembers(session: session);
});

final organizerTeamActivityProvider =
    FutureProvider.autoDispose<List<OrganizerTeamActivityItem>>((ref) async {
  final session = ref.watch(authSessionProvider);
  return ref.read(organizerTeamApiProvider).listActivity(session: session);
});
