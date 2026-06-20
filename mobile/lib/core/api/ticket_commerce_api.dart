import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_session.dart';

class TicketCommerceApiException implements Exception {
  TicketCommerceApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'TicketCommerceApiException($code): $message';
}

class TicketOrderResponse {
  TicketOrderResponse({required this.orderId, required this.totalMinor, required this.currency});
  final String orderId;
  final String totalMinor;
  final String currency;

  factory TicketOrderResponse.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>;
    return TicketOrderResponse(
      orderId: order['id'] as String,
      totalMinor: order['totalMinor'] as String,
      currency: order['currency'] as String,
    );
  }
}

class TicketPaymentResponse {
  TicketPaymentResponse({
    required this.paymentId,
    required this.status,
    required this.entitlements,
  });
  final String paymentId;
  final String status;
  final List<TicketEntitlementResponse> entitlements;

  factory TicketPaymentResponse.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>;
    final ents = (json['entitlements'] as List<dynamic>? ?? [])
        .map((e) => TicketEntitlementResponse.fromJson(e as Map<String, dynamic>))
        .toList();
    return TicketPaymentResponse(
      paymentId: payment['id'] as String,
      status: payment['status'] as String,
      entitlements: ents,
    );
  }
}

class TicketEntitlementResponse {
  TicketEntitlementResponse({
    required this.id,
    required this.ticketCode,
    required this.qrPayload,
    required this.tierName,
    required this.eventId,
    required this.eventTitle,
    required this.eventCity,
    required this.eventVenue,
    required this.startsAt,
    this.issuedAt,
  });

  final String id;
  final String ticketCode;
  final String qrPayload;
  final String tierName;
  final String eventId;
  final String eventTitle;
  final String eventCity;
  final String eventVenue;
  final DateTime startsAt;
  final DateTime? issuedAt;

  factory TicketEntitlementResponse.fromJson(Map<String, dynamic> json) {
    return TicketEntitlementResponse(
      id: json['id'] as String,
      ticketCode: json['ticketCode'] as String,
      qrPayload: json['qrPayload'] as String,
      tierName: json['tierName'] as String,
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String,
      eventCity: json['eventCity'] as String? ?? '',
      eventVenue: json['eventVenue'] as String? ?? '',
      startsAt: DateTime.parse(json['startsAt'] as String),
      issuedAt: json['issuedAt'] != null ? DateTime.parse(json['issuedAt'] as String) : null,
    );
  }
}

class TicketCommerceApi {
  TicketCommerceApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base {
    final raw = (dotenv.env['OWANBE_API_BASE'] ?? 'http://localhost:8080/v1').trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String get _tenantId => (dotenv.env['OWANBE_TENANT_ID'] ?? devTenantId).trim();

  bool get isConfigured => _tenantId.isNotEmpty;

  Future<Map<String, String>> _headers(AuthSession session) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Tenant-Id': _tenantId,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers['X-Dev-User-Id'] = session.userId;
      headers['X-Dev-User-Email'] = session.email ?? session.userId;
    }
    return headers;
  }

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw TicketCommerceApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is TicketCommerceApiException) rethrow;
      throw TicketCommerceApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<TicketOrderResponse> createTicketOrder({
    required AuthSession session,
    required String eventId,
    required String currency,
    required List<Map<String, dynamic>> items,
    String? idempotencyKey,
  }) async {
    final headers = await _headers(session);
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await _http.post(
      _u('events/$eventId/ticket-orders'),
      headers: headers,
      body: jsonEncode({
        'attendeeId': session.userId,
        'currency': currency,
        'items': items,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return TicketOrderResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<TicketPaymentResponse> createTicketPayment({
    required AuthSession session,
    required String orderId,
    String? idempotencyKey,
  }) async {
    final headers = await _headers(session);
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await _http.post(
      _u('ticket-orders/$orderId/payments'),
      headers: headers,
    );
    if (res.statusCode >= 400) _throw(res);
    return TicketPaymentResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<TicketEntitlementResponse>> fetchMyEntitlements(AuthSession session) async {
    final res = await _http.get(_u('me/ticket-entitlements'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => TicketEntitlementResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
