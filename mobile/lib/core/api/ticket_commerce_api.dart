import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import 'owambe_api_auth.dart';

class TicketCommerceApiException implements Exception {
  TicketCommerceApiException({required this.code, required this.message});
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

class TicketOrderResponse {
  TicketOrderResponse({
    required this.orderId,
    required this.totalMinor,
    required this.currency,
    this.status,
    this.eventId,
    this.eventTitle,
    this.subtotalMinor,
    this.platformFeeMinor,
    this.createdAt,
    this.lines = const [],
  });

  final String orderId;
  final String totalMinor;
  final String currency;
  final String? status;
  final String? eventId;
  final String? eventTitle;
  final String? subtotalMinor;
  final String? platformFeeMinor;
  final DateTime? createdAt;
  final List<TicketOrderLineResponse> lines;

  factory TicketOrderResponse.fromJson(Map<String, dynamic> json) {
    final order = (json['order'] as Map<String, dynamic>?) ?? json;
    final linesRaw = order['lines'] as List<dynamic>? ?? const [];
    return TicketOrderResponse(
      orderId: (order['id'] ?? order['orderId']).toString(),
      totalMinor: (order['totalMinor'] ?? '0').toString(),
      currency: (order['currency'] ?? 'NGN').toString(),
      status: order['status']?.toString(),
      eventId: order['eventId']?.toString(),
      eventTitle: order['eventTitle']?.toString(),
      subtotalMinor: order['subtotalMinor']?.toString(),
      platformFeeMinor: order['platformFeeMinor']?.toString(),
      createdAt: _parseDate(order['createdAt']),
      lines: linesRaw
          .whereType<Map>()
          .map((e) => TicketOrderLineResponse.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class TicketOrderLineResponse {
  TicketOrderLineResponse({
    required this.id,
    required this.tierId,
    required this.tierName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.lineSubtotalMinor,
  });

  final String id;
  final String tierId;
  final String tierName;
  final int quantity;
  final String unitPriceMinor;
  final String lineSubtotalMinor;

  factory TicketOrderLineResponse.fromJson(Map<String, dynamic> json) {
    return TicketOrderLineResponse(
      id: (json['id'] ?? '').toString(),
      tierId: (json['tierId'] ?? '').toString(),
      tierName: (json['tierName'] ?? 'Ticket').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceMinor: (json['unitPriceMinor'] ?? '0').toString(),
      lineSubtotalMinor: (json['lineSubtotalMinor'] ?? '0').toString(),
    );
  }
}

class TicketOrderSummary {
  TicketOrderSummary({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.currency,
    required this.totalMinor,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String status;
  final String currency;
  final String totalMinor;
  final DateTime createdAt;

  factory TicketOrderSummary.fromJson(Map<String, dynamic> json) {
    return TicketOrderSummary(
      id: (json['id'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      eventTitle: (json['eventTitle'] ?? 'Event').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      currency: (json['currency'] ?? 'NGN').toString(),
      totalMinor: (json['totalMinor'] ?? '0').toString(),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class TicketPaymentResponse {
  TicketPaymentResponse({
    required this.paymentId,
    required this.status,
    required this.entitlements,
    this.ticketOrderId,
    this.clientActionUrl,
    this.quaserReference,
  });

  final String paymentId;
  final String status;
  final List<TicketEntitlementResponse> entitlements;
  final String? ticketOrderId;
  final String? clientActionUrl;
  final String? quaserReference;

  bool get isCaptured => status.toLowerCase() == 'captured';
  bool get needsHostedPayment =>
      !isCaptured && clientActionUrl != null && clientActionUrl!.trim().isNotEmpty;

  factory TicketPaymentResponse.fromJson(Map<String, dynamic> json) {
    final payment = (json['payment'] as Map<String, dynamic>?) ?? const {};
    final quaser = (json['quaser'] as Map<String, dynamic>?) ?? const {};
    final ents = (json['entitlements'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => TicketEntitlementResponse.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return TicketPaymentResponse(
      paymentId: (payment['id'] ?? '').toString(),
      status: (payment['status'] ?? 'initiated').toString(),
      ticketOrderId: payment['ticketOrderId']?.toString(),
      quaserReference: payment['quaserReference']?.toString(),
      clientActionUrl: quaser['clientActionUrl']?.toString() ?? quaser['client_action_url']?.toString(),
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
    this.status,
    this.endsAt,
    this.checkedInAt,
    this.venueAddress,
    this.accessLevel,
    this.seatLabel,
    this.gateInfo,
    this.entryInstructions,
    this.arrivalInstructions,
    this.supportContactEmail,
    this.supportContactPhone,
    this.groupLabel,
    this.ticketOrderId,
    this.siblingCount = 1,
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
  final String? status;
  final DateTime? endsAt;
  final DateTime? checkedInAt;
  final String? venueAddress;
  final String? accessLevel;
  final String? seatLabel;
  final String? gateInfo;
  final String? entryInstructions;
  final String? arrivalInstructions;
  final String? supportContactEmail;
  final String? supportContactPhone;
  final String? groupLabel;
  final String? ticketOrderId;
  final int siblingCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketCode': ticketCode,
        'qrPayload': qrPayload,
        'tierName': tierName,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'eventCity': eventCity,
        'eventVenue': eventVenue,
        'startsAt': startsAt.toIso8601String(),
        if (issuedAt != null) 'issuedAt': issuedAt!.toIso8601String(),
        if (status != null) 'status': status,
        if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
        if (checkedInAt != null) 'checkedInAt': checkedInAt!.toIso8601String(),
        if (venueAddress != null) 'venueAddress': venueAddress,
        if (accessLevel != null) 'accessLevel': accessLevel,
        if (seatLabel != null) 'seatLabel': seatLabel,
        if (gateInfo != null) 'gateInfo': gateInfo,
        if (entryInstructions != null) 'entryInstructions': entryInstructions,
        if (arrivalInstructions != null) 'arrivalInstructions': arrivalInstructions,
        if (supportContactEmail != null) 'supportContactEmail': supportContactEmail,
        if (supportContactPhone != null) 'supportContactPhone': supportContactPhone,
        if (groupLabel != null) 'groupLabel': groupLabel,
        if (ticketOrderId != null) 'ticketOrderId': ticketOrderId,
        'siblingCount': siblingCount,
      };

  /// Supports both full `me/ticket-entitlements` rows and partial payment payloads.
  factory TicketEntitlementResponse.fromJson(Map<String, dynamic> json) {
    final ticketCode = (json['ticketCode'] ?? json['ticket_code'] ?? '').toString();
    final qrPayload = (json['qrPayload'] ?? json['qr_payload'] ?? ticketCode).toString();
    final startsAt = _parseDate(json['startsAt'] ?? json['starts_at']) ?? DateTime.now();
    return TicketEntitlementResponse(
      id: (json['id'] ?? '').toString(),
      ticketCode: ticketCode.isEmpty ? (json['id'] ?? 'ticket').toString() : ticketCode,
      qrPayload: qrPayload.isEmpty ? ticketCode : qrPayload,
      tierName: (json['tierName'] ?? json['tier_name'] ?? 'Ticket').toString(),
      eventId: (json['eventId'] ?? json['event_id'] ?? '').toString(),
      eventTitle: (json['eventTitle'] ?? json['event_title'] ?? 'Your event').toString(),
      eventCity: (json['eventCity'] ?? json['event_city'] ?? '').toString(),
      eventVenue: (json['eventVenue'] ?? json['event_venue'] ?? '').toString(),
      startsAt: startsAt,
      issuedAt: _parseDate(json['issuedAt'] ?? json['issued_at']),
      status: json['status']?.toString(),
      endsAt: _parseDate(json['endsAt'] ?? json['ends_at']),
      checkedInAt: _parseDate(json['checkedInAt'] ?? json['checked_in_at']),
      venueAddress: json['venueAddress']?.toString() ?? json['venue_address']?.toString(),
      accessLevel: json['accessLevel']?.toString() ?? json['access_level']?.toString(),
      seatLabel: json['seatLabel']?.toString() ?? json['seat_label']?.toString(),
      gateInfo: json['gateInfo']?.toString() ?? json['gate_info']?.toString(),
      entryInstructions:
          json['entryInstructions']?.toString() ?? json['entry_instructions']?.toString(),
      arrivalInstructions:
          json['arrivalInstructions']?.toString() ?? json['arrival_instructions']?.toString(),
      supportContactEmail:
          json['supportContactEmail']?.toString() ?? json['support_contact_email']?.toString(),
      supportContactPhone:
          json['supportContactPhone']?.toString() ?? json['support_contact_phone']?.toString(),
      groupLabel: json['groupLabel']?.toString() ?? json['group_label']?.toString(),
      ticketOrderId: json['ticketOrderId']?.toString() ?? json['ticket_order_id']?.toString(),
      siblingCount: (json['siblingCount'] as num?)?.toInt() ??
          (json['sibling_count'] as num?)?.toInt() ??
          1,
    );
  }
}

class TicketRefundCaseResponse {
  TicketRefundCaseResponse({
    required this.id,
    required this.status,
    required this.amountMinor,
    required this.currency,
    this.reason,
    this.createdAt,
  });

  final String id;
  final String status;
  final String amountMinor;
  final String currency;
  final String? reason;
  final DateTime? createdAt;

  factory TicketRefundCaseResponse.fromJson(Map<String, dynamic> json) {
    return TicketRefundCaseResponse(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'requested').toString(),
      amountMinor: (json['amountMinor'] ?? '0').toString(),
      currency: (json['currency'] ?? 'NGN').toString(),
      reason: json['reason']?.toString(),
      createdAt: _parseDate(json['createdAt']),
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

class TicketCommerceApi {
  TicketCommerceApi({http.Client? client}) : _http = client ?? http.Client();

  static const _timeout = Duration(seconds: 12);
  final http.Client _http;

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) =>
      _http.get(uri, headers: headers).timeout(_timeout);

  Future<http.Response> _post(Uri uri, {Map<String, String>? headers, Object? body}) =>
      _http.post(uri, headers: headers, body: body).timeout(_timeout);

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base => OwambeApiAuth.resolveApiBase();

  String get _tenantId => OwambeApiAuth.resolveTenantId(devTenantId);

  bool get isConfigured => _tenantId.isNotEmpty;

  Future<Map<String, String>> _headers(AuthSession session) =>
      OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);

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
    final res = await _post(
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
    final res = await _post(
      _u('ticket-orders/$orderId/payments'),
      headers: headers,
    );
    if (res.statusCode >= 400) _throw(res);
    return TicketPaymentResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<TicketOrderResponse> getTicketOrder({
    required AuthSession session,
    required String orderId,
  }) async {
    final res = await _get(_u('ticket-orders/$orderId'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    return TicketOrderResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<TicketOrderSummary>> fetchMyOrders(AuthSession session) async {
    final res = await _get(_u('me/ticket-orders'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => TicketOrderSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TicketEntitlementResponse>> fetchMyEntitlements(AuthSession session) async {
    final res = await _get(_u('me/ticket-entitlements'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => TicketEntitlementResponse.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> resendTicket({
    required AuthSession session,
    required String entitlementId,
  }) async {
    final res = await _post(
      _u('ticket-entitlements/$entitlementId/resend'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<List<TicketRefundCaseResponse>> listOrderRefunds({
    required AuthSession session,
    required String orderId,
  }) async {
    final res = await _get(
      _u('ticket-orders/$orderId/refunds'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => TicketRefundCaseResponse.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<TicketRefundCaseResponse> requestRefund({
    required AuthSession session,
    required String orderId,
    required String amountMinor,
    required String reason,
  }) async {
    final res = await _post(
      _u('ticket-orders/$orderId/refunds'),
      headers: await _headers(session),
      body: jsonEncode({'amountMinor': amountMinor, 'reason': reason}),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return TicketRefundCaseResponse(
      id: (body['id'] ?? '').toString(),
      status: (body['status'] ?? 'requested').toString(),
      amountMinor: amountMinor,
      currency: 'NGN',
      reason: reason,
      createdAt: DateTime.now(),
    );
  }
}
