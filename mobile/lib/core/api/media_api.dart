import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import 'owambe_api_auth.dart';
import 'owambe_http_client.dart';

class MediaApiException implements Exception {
  MediaApiException({required this.code, required this.message, this.statusCode});
  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MediaPresignResult {
  const MediaPresignResult({
    required this.objectId,
    required this.uploadUrl,
    required this.publicUrl,
  });

  final String objectId;
  final String uploadUrl;
  final String publicUrl;
}

/// Presign + raw-byte upload for celebrant images and other media.
class MediaApi {
  MediaApi({http.Client? client}) : _http = client ?? createOwambeHttpClient();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base => OwambeApiAuth.resolveApiBase();

  String get _tenantId => OwambeApiAuth.resolveTenantId(devTenantId);

  Future<Map<String, String>> _headers({AuthSession? session, bool json = true}) async =>
      OwambeApiAuth.authorizedHeaders(tenantId: _tenantId, json: json);

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    String code = 'HTTP_${res.statusCode}';
    String message = res.reasonPhrase ?? 'Request failed';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      code = (body['code'] ?? code).toString();
      message = (body['message'] ?? message).toString();
    } catch (_) {}
    throw MediaApiException(code: code, message: message, statusCode: res.statusCode);
  }

  Future<MediaPresignResult> presignUpload({
    required String filename,
    required String contentType,
    String purpose = 'celebrant_image',
    AuthSession? session,
  }) async {
    final res = await _http.post(
      _u('media/presign'),
      headers: await _headers(session: session),
      body: jsonEncode({
        'filename': filename,
        'contentType': contentType,
        'purpose': purpose,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return MediaPresignResult(
      objectId: (json['objectId'] ?? '').toString(),
      uploadUrl: (json['uploadUrl'] ?? '').toString(),
      publicUrl: (json['publicUrl'] ?? '').toString(),
    );
  }

  Future<void> uploadBytes({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
    AuthSession? session,
  }) async {
    await uploadBytesReturningPublicUrl(
      uploadUrl: uploadUrl,
      bytes: bytes,
      contentType: contentType,
      session: session,
    );
  }

  /// PUT bytes to [uploadUrl]; returns server `publicUrl` when present.
  Future<String?> uploadBytesReturningPublicUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
    AuthSession? session,
  }) async {
    final uri = Uri.parse(uploadUrl);
    final res = await _http.put(
      uri,
      headers: await _headers(session: session, json: false)..['Content-Type'] = contentType,
      body: bytes,
    );
    if (res.statusCode >= 400) _throw(res);
    if (res.body.isEmpty) return null;
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final url = json['publicUrl']?.toString();
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (_) {
      return null;
    }
  }
}
