import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/vendor/models/vendor_models.dart';
import 'events_api.dart';
import 'owanbe_api_auth.dart';

class VendorBookingsApi {
  VendorBookingsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId(EventsApi.devTenantId);

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw EventsApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is EventsApiException) rethrow;
      throw EventsApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<List<VendorOrder>> listOrders() async {
    final res = await _http.get(_u('bookings'), headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => mapVendorOrder(e as Map<String, dynamic>))
        .toList();
  }

  Future<VendorOrder> updateStatus(String bookingId, VendorOrderAction action) async {
    final res = await _http.patch(
      _u('bookings/$bookingId/status'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'action': action.apiValue}),
    );
    if (res.statusCode >= 400) _throw(res);
    return mapVendorOrder(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

enum VendorOrderAction { accept, fulfill, cancel }

extension VendorOrderActionX on VendorOrderAction {
  String get apiValue => switch (this) {
        VendorOrderAction.accept => 'accept',
        VendorOrderAction.fulfill => 'fulfill',
        VendorOrderAction.cancel => 'cancel',
      };
}

VendorOrderStatus _mapBookingStatus(String raw) => switch (raw) {
      'pending_payment' => VendorOrderStatus.newOrder,
      'draft' => VendorOrderStatus.newOrder,
      'confirmed' => VendorOrderStatus.accepted,
      'in_progress' => VendorOrderStatus.inProgress,
      'completed' => VendorOrderStatus.fulfilled,
      'cancelled' => VendorOrderStatus.cancelled,
      'refunded' => VendorOrderStatus.cancelled,
      'disputed' => VendorOrderStatus.inProgress,
      _ => VendorOrderStatus.newOrder,
    };

VendorOrderAction? actionForStatus(VendorOrderStatus target) => switch (target) {
      VendorOrderStatus.accepted => VendorOrderAction.accept,
      VendorOrderStatus.fulfilled => VendorOrderAction.fulfill,
      VendorOrderStatus.cancelled => VendorOrderAction.cancel,
      _ => null,
    };

VendorOrder mapVendorOrder(Map<String, dynamic> json) {
  final created = DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now();
  return VendorOrder(
    id: (json['id'] ?? '').toString(),
    eventId: (json['eventId'] ?? '').toString(),
    eventTitle: (json['eventTitle'] ?? json['locationText'] ?? 'Event').toString(),
    customerName: (json['clientName'] ?? 'Customer').toString(),
    itemName: (json['packageName'] ?? 'Package').toString(),
    amountMinor: (json['subtotalMinor'] as num?)?.toInt() ?? (json['totalMinor'] as num?)?.toInt() ?? 0,
    status: _mapBookingStatus((json['status'] ?? '').toString()),
    placedAt: created,
    notes: json['clientNotes']?.toString(),
  );
}
