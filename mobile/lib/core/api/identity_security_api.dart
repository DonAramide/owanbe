import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'owanbe_api_auth.dart';

class IdentitySecurityApiException implements Exception {
  IdentitySecurityApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// Phase 29 — Nest identity-security + Supabase Auth MFA client.
class IdentitySecurityApi {
  IdentitySecurityApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();

  Future<Map<String, String>> _headers() => OwambeApiAuth.authorizedHeaders(json: true);

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw IdentitySecurityApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is IdentitySecurityApiException) rethrow;
      throw IdentitySecurityApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<Map<String, dynamic>> securityCenter() async {
    final res = await _http.get(_u('identity-security/center'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String> securityReportCsv() async {
    final res = await _http.get(_u('identity-security/report.csv'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return res.body;
  }

  Future<List<Map<String, dynamic>>> listUsers({
    String? q,
    String? status,
    String? tenantId,
  }) async {
    final res = await _http.get(
      _u('identity-security/users', {
        if (q != null && q.isNotEmpty) 'q': q,
        if (status != null && status.isNotEmpty) 'status': status,
        if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
      }),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<void> suspendUser(String userId, {String? reason}) async {
    final res = await _http.post(
      _u('identity-security/users/$userId/suspend'),
      headers: await _headers(),
      body: jsonEncode({if (reason != null) 'reason': reason}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> reactivateUser(String userId) async {
    final res = await _http.post(
      _u('identity-security/users/$userId/reactivate'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<Map<String, dynamic>> myMfaStatus() async {
    final res = await _http.get(_u('me/security/mfa'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> userMfaStatus(String userId) async {
    final res = await _http.get(
      _u('identity-security/users/$userId/mfa'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> recordMfaEvent(String kind, {Map<String, dynamic>? metadata}) async {
    final res = await _http.post(
      _u('me/security/mfa/events'),
      headers: await _headers(),
      body: jsonEncode({'kind': kind, if (metadata != null) 'metadata': metadata}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<Map<String, dynamic>> resetMfa(String userId, {String? reason}) async {
    final res = await _http.post(
      _u('identity-security/users/$userId/mfa/reset'),
      headers: await _headers(),
      body: jsonEncode({if (reason != null) 'reason': reason}),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mySessions() async {
    final res = await _http.get(_u('me/security/sessions'), headers: await _headers());
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> userSessions(String userId) async {
    final res = await _http.get(
      _u('identity-security/users/$userId/sessions'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> revokeSessions(String userId) async {
    final res = await _http.post(
      _u('identity-security/users/$userId/sessions/revoke'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Enroll TOTP via Supabase Auth (same IdP as login). Returns QR URI + factor id.
  Future<Map<String, dynamic>> enrollTotpViaSupabase({String friendlyName = 'Owambe'}) async {
    final res = await Supabase.instance.client.auth.mfa.enroll(
      factorType: FactorType.totp,
      friendlyName: friendlyName,
    );
    final totp = res.totp;
    if (totp == null) {
      throw StateError('TOTP enrollment payload missing from MFA enroll response');
    }
    return {
      'factorId': res.id,
      'qrCode': totp.qrCode,
      'secret': totp.secret,
      'uri': totp.uri,
    };
  }

  Future<void> verifyTotpEnrollment({
    required String factorId,
    required String code,
  }) async {
    final challenge = await Supabase.instance.client.auth.mfa.challenge(factorId: factorId);
    await Supabase.instance.client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code.trim(),
    );
    await recordMfaEvent('enrolled', metadata: {'factorId': factorId});
  }

  Future<void> verifyTotpLogin({
    required String factorId,
    required String code,
  }) async {
    final challenge = await Supabase.instance.client.auth.mfa.challenge(factorId: factorId);
    await Supabase.instance.client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code.trim(),
    );
    await recordMfaEvent('verified', metadata: {'factorId': factorId});
  }
}

final identitySecurityApiProvider = Provider<IdentitySecurityApi>((ref) => IdentitySecurityApi());

final identitySecurityCenterProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(identitySecurityApiProvider).securityCenter();
});

final identitySecurityUsersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) async {
  return ref.read(identitySecurityApiProvider).listUsers(q: query.isEmpty ? null : query);
});

final myMfaStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(identitySecurityApiProvider).myMfaStatus();
});
