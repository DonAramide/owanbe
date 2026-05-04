import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/finance/admin_finance_models.dart';
import '../../features/disputes/dispute_models.dart';

class DisputesApi {
  DisputesApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base {
    final raw = (dotenv.env['OWANBE_API_BASE'] ?? 'http://localhost:8080/v1').trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String get _tenantId => (dotenv.env['OWANBE_TENANT_ID'] ?? '').trim();

  Future<Map<String, String>> _headers() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    if (token.isEmpty || _tenantId.isEmpty) {
      throw AdminFinanceApiException(code: 'AUTH_MISSING', message: 'Missing token or tenant id');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Tenant-Id': _tenantId,
    };
  }

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throwApi(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw AdminFinanceApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (_) {
      throw AdminFinanceApiException(code: 'HTTP_${res.statusCode}', message: 'Request failed');
    }
  }

  Future<PaginatedResponse<DisputeItem>> listAdmin({int page = 1, int limit = 50}) async {
    final res = await _http.get(
      _u('admin/disputes', {'page': '$page', 'limit': '$limit'}),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return PaginatedResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
      DisputeItem.fromJson,
    );
  }

  Future<PaginatedResponse<DisputeItem>> listMine({int limit = 50}) async {
    final res = await _http.get(_u('disputes', {'limit': '$limit'}), headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return PaginatedResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
      DisputeItem.fromJson,
    );
  }

  Future<DisputeDetail> getDetail(String id, {bool admin = false}) async {
    final res = await _http.get(
      _u(admin ? 'admin/disputes/$id' : 'disputes/$id'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return DisputeDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> create({
    required String bookingId,
    required String reason,
    required String description,
    String? amountClaimedMinor,
  }) async {
    final query = <String, String>{
      'bookingId': bookingId,
      'reason': reason,
      'description': description,
      if (amountClaimedMinor != null && amountClaimedMinor.isNotEmpty) 'amountClaimedMinor': amountClaimedMinor,
    };
    final res = await _http.post(_u('disputes', query), headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }

  Future<void> addMessage(String disputeId, String message) async {
    final res = await _http.post(
      _u('disputes/$disputeId/messages', {'message': message}),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }

  Future<void> addEvidence(String disputeId, {required String type, required String url}) async {
    final res = await _http.post(
      _u('disputes/$disputeId/evidence', {'type': type, 'url': url}),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }

  Future<void> resolve(
    String disputeId, {
    required String resolution,
    String? refundAmountMinor,
    String? note,
    bool releaseVendorPayout = false,
  }) async {
    final q = {
      'resolution': resolution,
      if (refundAmountMinor != null && refundAmountMinor.isNotEmpty) 'refundAmountMinor': refundAmountMinor,
      if (note != null && note.isNotEmpty) 'note': note,
      if (releaseVendorPayout) 'releaseVendorPayout': 'true',
    };
    final res = await _http.post(_u('admin/disputes/$disputeId/resolve', q), headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }
}
