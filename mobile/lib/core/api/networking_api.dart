import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import 'owambe_api_auth.dart';

class NetworkingApiException implements Exception {
  NetworkingApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => message;
}

enum NetworkingConnectionStatus {
  none,
  pendingOutgoing,
  pendingIncoming,
  connected,
  declined,
}

NetworkingConnectionStatus parseConnectionStatus(String? raw) {
  switch ((raw ?? 'none').toLowerCase()) {
    case 'pending_outgoing':
      return NetworkingConnectionStatus.pendingOutgoing;
    case 'pending_incoming':
      return NetworkingConnectionStatus.pendingIncoming;
    case 'connected':
      return NetworkingConnectionStatus.connected;
    case 'declined':
      return NetworkingConnectionStatus.declined;
    default:
      return NetworkingConnectionStatus.none;
  }
}

class DirectoryPerson {
  DirectoryPerson({
    required this.userId,
    required this.displayName,
    required this.connectionStatus,
    required this.isSelf,
    this.avatarUrl,
    this.company,
    this.occupation,
    this.interests = const [],
    this.mutualInterests = const [],
    this.ticketTierName,
    this.connectionId,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? company;
  final String? occupation;
  final List<String> interests;
  final List<String> mutualInterests;
  final String? ticketTierName;
  final NetworkingConnectionStatus connectionStatus;
  final String? connectionId;
  final bool isSelf;

  factory DirectoryPerson.fromJson(Map<String, dynamic> json) {
    final cid = json['connectionId']?.toString();
    return DirectoryPerson(
      userId: (json['userId'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Attendee').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      company: json['company']?.toString(),
      occupation: json['occupation']?.toString(),
      interests: _strings(json['interests']),
      mutualInterests: _strings(json['mutualInterests']),
      ticketTierName: json['ticketTierName']?.toString(),
      connectionStatus: parseConnectionStatus(json['connectionStatus']?.toString()),
      connectionId: (cid == null || cid.isEmpty) ? null : cid,
      isSelf: json['isSelf'] == true,
    );
  }
}

class NetworkingConnection {
  NetworkingConnection({
    required this.id,
    required this.otherUserId,
    required this.displayName,
    required this.connectionStatus,
    required this.status,
    this.avatarUrl,
    this.company,
    this.createdAt,
  });

  final String id;
  final String otherUserId;
  final String displayName;
  final String? avatarUrl;
  final String? company;
  final NetworkingConnectionStatus connectionStatus;
  final String status;
  final DateTime? createdAt;

  factory NetworkingConnection.fromJson(Map<String, dynamic> json) {
    return NetworkingConnection(
      id: (json['id'] ?? '').toString(),
      otherUserId: (json['otherUserId'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Attendee').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      company: json['company']?.toString(),
      connectionStatus: parseConnectionStatus(json['connectionStatus']?.toString()),
      status: (json['status'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class BusinessCard {
  BusinessCard({
    required this.userId,
    required this.displayName,
    required this.qrPayload,
    required this.shareText,
    this.avatarUrl,
    this.bio,
    this.company,
    this.occupation,
    this.email,
    this.phone,
    this.socialLinks = const {},
    this.interests = const [],
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? company;
  final String? occupation;
  final String? email;
  final String? phone;
  final Map<String, String> socialLinks;
  final List<String> interests;
  final String qrPayload;
  final String shareText;

  factory BusinessCard.fromJson(Map<String, dynamic> json) {
    final social = <String, String>{};
    final raw = json['socialLinks'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = e.value?.toString().trim() ?? '';
        if (v.isNotEmpty) social[e.key.toString()] = v;
      }
    }
    return BusinessCard(
      userId: (json['userId'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Attendee').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      bio: json['bio']?.toString(),
      company: json['company']?.toString(),
      occupation: json['occupation']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      socialLinks: social,
      interests: _strings(json['interests']),
      qrPayload: (json['qrPayload'] ?? '').toString(),
      shareText: (json['shareText'] ?? '').toString(),
    );
  }
}

class NetworkingNotification {
  NetworkingNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.read,
    this.title,
    this.body,
    this.data = const {},
  });

  final String id;
  final String kind;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool read;

  factory NetworkingNotification.fromJson(Map<String, dynamic> json) {
    return NetworkingNotification(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      title: json['title']?.toString(),
      body: json['body']?.toString(),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : const {},
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      read: json['read'] == true,
    );
  }
}

List<String> _strings(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
}

class NetworkingApi {
  NetworkingApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Uri _u(String path) => Uri.parse('${OwambeApiAuth.resolveApiBase()}/$path');

  Future<Map<String, String>> _headers(AuthSession session) =>
      OwambeApiAuth.authorizedHeaders(tenantId: OwambeApiAuth.resolveTenantId());

  void _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        throw NetworkingApiException(
          code: (body['code'] ?? 'ERROR').toString(),
          message: (body['message'] ?? res.body).toString(),
        );
      }
    } catch (e) {
      if (e is NetworkingApiException) rethrow;
    }
    throw NetworkingApiException(code: 'HTTP_${res.statusCode}', message: res.body);
  }

  Future<List<DirectoryPerson>> listPeople({
    required AuthSession session,
    required String eventId,
    String? q,
    String? company,
    String? interest,
  }) async {
    final uri = _u('events/$eventId/people').replace(queryParameters: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
      if (interest != null && interest.trim().isNotEmpty) 'interest': interest.trim(),
    });
    final res = await _http.get(uri, headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => DirectoryPerson.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<DirectoryPerson>> suggestions({
    required AuthSession session,
    required String eventId,
  }) async {
    final res = await _http.get(
      _u('events/$eventId/people/suggestions'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => DirectoryPerson.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<NetworkingConnection>> listConnections({
    required AuthSession session,
    required String eventId,
  }) async {
    final res = await _http.get(
      _u('events/$eventId/connections'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => NetworkingConnection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> requestConnection({
    required AuthSession session,
    required String eventId,
    required String userId,
  }) async {
    final res = await _http.post(
      _u('events/$eventId/connections'),
      headers: await _headers(session),
      body: jsonEncode({'userId': userId}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> acceptConnection({required AuthSession session, required String connectionId}) async {
    final res = await _http.post(
      _u('networking/connections/$connectionId/accept'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> declineConnection({required AuthSession session, required String connectionId}) async {
    final res = await _http.post(
      _u('networking/connections/$connectionId/decline'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> removeConnection({required AuthSession session, required String connectionId}) async {
    final res = await _http.delete(
      _u('networking/connections/$connectionId'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<BusinessCard> fetchBusinessCard(AuthSession session) async {
    final res = await _http.get(_u('me/business-card'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    return BusinessCard.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<NetworkingNotification>> fetchNotifications(AuthSession session) async {
    final res = await _http.get(_u('me/networking-notifications'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => NetworkingNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> notifyShare({
    required AuthSession session,
    required String kind,
    required String recipientUserId,
    String? eventId,
  }) async {
    final res = await _http.post(
      _u('me/networking-share-notify'),
      headers: await _headers(session),
      body: jsonEncode({
        'kind': kind,
        'recipientUserId': recipientUserId,
        if (eventId != null) 'eventId': eventId,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }
}
