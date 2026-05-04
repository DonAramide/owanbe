import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import 'outbox_sync_contract.dart';

class OwanbeApiAuth {
  const OwanbeApiAuth({required this.accessToken, required this.tenantId});

  final String accessToken;
  final String tenantId;
}

typedef ResolveOwanbeApiAuth = Future<OwanbeApiAuth?> Function();

/// Sends outbox rows to `OWANBE_API_BASE` (OpenAPI server URL including `/v1`).
class OwanbeRestOutboxTransport implements OutboxTransport {
  OwanbeRestOutboxTransport({
    required this.baseUrl,
    required this.resolveAuth,
  });

  /// e.g. `http://localhost:8080/v1` (no trailing slash).
  final String baseUrl;
  final ResolveOwanbeApiAuth resolveAuth;

  Uri _url(String relativePath) {
    final trimmed = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$root/$trimmed');
  }

  Map<String, String> _jsonHeaders(OwanbeApiAuth auth) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth.accessToken}',
        'X-Tenant-Id': auth.tenantId,
      };

  @override
  Future<OutboxDeliveryResult> send(OutboxActionRow row) async {
    final auth = await resolveAuth();
    if (auth == null) {
      return const OutboxDeliveryResult.failed(
        message: 'Missing API auth (sign in via Supabase) or OWANBE_TENANT_ID',
      );
    }

    try {
      switch (row.actionType) {
        case OwanbeOutboxActionKinds.bookingCreate:
          return _handleResponse(
            await http.post(
              _url('bookings'),
              headers: {
                ..._jsonHeaders(auth),
                'Idempotency-Key': row.clientMutationId,
              },
              body: row.payloadJson,
            ),
          );
        case OwanbeOutboxActionKinds.bookingPatch:
          return _sendBookingPatch(row, auth);
        case OwanbeOutboxActionKinds.bookingPaymentInitiate:
          return _sendBookingPayment(row, auth);
        default:
          return OutboxDeliveryResult.failed(
            message: 'Unknown actionType: ${row.actionType}',
          );
      }
    } catch (e, st) {
      debugPrint('Outbox transport error: $e\n$st');
      return OutboxDeliveryResult.retryLater(message: e.toString());
    }
  }

  Future<OutboxDeliveryResult> _sendBookingPatch(
    OutboxActionRow row,
    OwanbeApiAuth auth,
  ) async {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      return const OutboxDeliveryResult.failed(message: 'booking.patch payload must be a JSON object');
    }
    final bookingId = decoded['bookingId'] as String?;
    final version = decoded['version'];
    if (bookingId == null || bookingId.isEmpty) {
      return const OutboxDeliveryResult.failed(message: 'booking.patch requires bookingId');
    }
    if (version is! int) {
      return const OutboxDeliveryResult.failed(message: 'booking.patch requires int version');
    }
    final bodyMap = Map<String, dynamic>.from(decoded)..remove('bookingId');
    final body = jsonEncode(bodyMap);

    final res = await http.patch(
      _url('bookings/$bookingId'),
      headers: {
        ..._jsonHeaders(auth),
        'If-Match': version.toString(),
      },
      body: body,
    );
    return _handleResponse(res);
  }

  Future<OutboxDeliveryResult> _sendBookingPayment(
    OutboxActionRow row,
    OwanbeApiAuth auth,
  ) async {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      return const OutboxDeliveryResult.failed(
        message: 'booking.payment.initiate payload must be a JSON object',
      );
    }
    final bookingId = decoded['bookingId'] as String?;
    if (bookingId == null || bookingId.isEmpty) {
      return const OutboxDeliveryResult.failed(message: 'payment initiate requires bookingId');
    }
    final bodyMap = Map<String, dynamic>.from(decoded)..remove('bookingId');
    final body = jsonEncode(bodyMap);

    final res = await http.post(
      _url('bookings/$bookingId/payments'),
      headers: {
        ..._jsonHeaders(auth),
        'Idempotency-Key': row.clientMutationId,
      },
      body: body,
    );
    return _handleResponse(res);
  }

  OutboxDeliveryResult _handleResponse(http.Response res) {
    final code = res.statusCode;
    if (code >= 200 && code < 300) {
      return const OutboxDeliveryResult.completed();
    }
    if (code == 409) {
      return OutboxDeliveryResult.failed(
        httpStatus: code,
        message: 'Version conflict (refresh booking and retry): ${res.body}',
      );
    }
    if (code == 401 || code == 403) {
      return OutboxDeliveryResult.failed(
        httpStatus: code,
        message: 'HTTP $code: ${res.body}',
      );
    }
    if (code == 422 || code == 400) {
      return OutboxDeliveryResult.failed(
        httpStatus: code,
        message: 'HTTP $code: ${res.body}',
      );
    }
    if (code == 429 || code >= 500) {
      return OutboxDeliveryResult.retryLater(
        httpStatus: code,
        message: 'HTTP $code: ${res.body}',
      );
    }
    return OutboxDeliveryResult.failed(
      httpStatus: code,
      message: 'HTTP $code: ${res.body}',
    );
  }
}

Future<OwanbeApiAuth?> defaultResolveOwanbeApiAuthFromSupabase({
  required String? tenantIdFromEnv,
}) async {
  final tenant = tenantIdFromEnv?.trim();
  if (tenant == null || tenant.isEmpty) return null;

  final session = Supabase.instance.client.auth.currentSession;
  final token = session?.accessToken;
  if (token == null || token.isEmpty) return null;

  return OwanbeApiAuth(accessToken: token, tenantId: tenant);
}
