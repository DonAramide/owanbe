import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owanbe_api_auth.dart';
import '../models/celebration_wall_models.dart';

class CelebrationWallApi {
  CelebrationWallApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId();

  Future<WallSnapshot> fetchPublic(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/wall'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return WallSnapshot.publicFromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<WallSnapshot> fetchManage(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/wall/manage'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return WallSnapshot.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<WallPost> createPost({
    required String eventId,
    required String guestName,
    required String message,
    String? photoUrl,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/wall/posts'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'guestName': guestName,
        'message': message,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return WallPost.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<WallPost> react({
    required String eventId,
    required String postId,
    required String reaction,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/wall/posts/$postId/reactions'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'reaction': reaction}),
    );
    if (res.statusCode >= 400) _throw(res);
    return WallPost.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<WallPost> moderate({
    required String eventId,
    required String postId,
    required String action,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/wall/posts/$postId/moderate'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'action': action}),
    );
    if (res.statusCode >= 400) _throw(res);
    return WallPost.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<WallSettings> patchSettings({
    required String eventId,
    required bool liveMode,
  }) async {
    final res = await _http.patch(
      Uri.parse('$_base/events/$eventId/wall/settings'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'liveMode': liveMode}),
    );
    if (res.statusCode >= 400) _throw(res);
    return WallSettings.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError((body['message'] ?? 'Request failed').toString());
    } catch (_) {
      throw StateError('Wall API error (${res.statusCode})');
    }
  }
}

final celebrationWallApiProvider = Provider<CelebrationWallApi>((ref) => CelebrationWallApi());

final celebrationWallRefreshProvider = StateProvider<int>((ref) => 0);

void refreshCelebrationWall(WidgetRef ref) {
  ref.read(celebrationWallRefreshProvider.notifier).state++;
}

final celebrationWallPublicProvider =
    FutureProvider.autoDispose.family<WallSnapshot, String>((ref, eventId) async {
  ref.watch(celebrationWallRefreshProvider);
  return ref.read(celebrationWallApiProvider).fetchPublic(eventId);
});

final celebrationWallManageProvider =
    FutureProvider.autoDispose.family<WallSnapshot, String>((ref, eventId) async {
  ref.watch(celebrationWallRefreshProvider);
  return ref.read(celebrationWallApiProvider).fetchManage(eventId);
});
