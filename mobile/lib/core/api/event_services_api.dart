import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import 'owambe_api_auth.dart';
import '../../portals/customer/models/rentals_models.dart';

class EventServicesApiException implements Exception {
  EventServicesApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => message;
}

enum AttendeeServiceStatus {
  pending,
  confirmed,
  inProgress,
  ready,
  completed,
  cancelled,
  expired,
}

AttendeeServiceStatus parseServiceStatus(String? raw) {
  switch ((raw ?? 'pending').toLowerCase()) {
    case 'confirmed':
      return AttendeeServiceStatus.confirmed;
    case 'in_progress':
      return AttendeeServiceStatus.inProgress;
    case 'ready':
      return AttendeeServiceStatus.ready;
    case 'completed':
      return AttendeeServiceStatus.completed;
    case 'cancelled':
      return AttendeeServiceStatus.cancelled;
    case 'expired':
      return AttendeeServiceStatus.expired;
    default:
      return AttendeeServiceStatus.pending;
  }
}

String serviceStatusLabel(AttendeeServiceStatus s) {
  switch (s) {
    case AttendeeServiceStatus.pending:
      return 'Pending';
    case AttendeeServiceStatus.confirmed:
      return 'Confirmed';
    case AttendeeServiceStatus.inProgress:
      return 'In progress';
    case AttendeeServiceStatus.ready:
      return 'Ready';
    case AttendeeServiceStatus.completed:
      return 'Completed';
    case AttendeeServiceStatus.cancelled:
      return 'Cancelled';
    case AttendeeServiceStatus.expired:
      return 'Expired';
  }
}

class EventServiceVendor {
  EventServiceVendor({
    required this.vendorId,
    required this.businessName,
    required this.availability,
    required this.hasRentals,
    required this.rentalItemCount,
    this.slug,
    this.description,
    this.logoUrl,
    this.city,
    this.category,
    this.categories = const [],
  });

  final String vendorId;
  final String businessName;
  final String? slug;
  final String? description;
  final String? logoUrl;
  final String? city;
  final String? category;
  final List<String> categories;
  final String availability;
  final bool hasRentals;
  final int rentalItemCount;

  factory EventServiceVendor.fromJson(Map<String, dynamic> json) {
    return EventServiceVendor(
      vendorId: (json['vendorId'] ?? '').toString(),
      businessName: (json['businessName'] ?? 'Vendor').toString(),
      slug: json['slug']?.toString(),
      description: json['description']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      city: json['city']?.toString(),
      category: json['category']?.toString(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      availability: (json['availability'] ?? 'unavailable').toString(),
      hasRentals: json['hasRentals'] == true,
      rentalItemCount: (json['rentalItemCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class EventServiceBooking {
  EventServiceBooking({
    required this.booking,
    required this.serviceStatus,
    required this.confirmationNumber,
    this.serviceKind = 'rental',
  });

  final RentalBooking booking;
  final AttendeeServiceStatus serviceStatus;
  final String confirmationNumber;
  final String serviceKind;

  factory EventServiceBooking.fromJson(Map<String, dynamic> json) {
    return EventServiceBooking(
      booking: RentalBooking.fromJson(json),
      serviceStatus: parseServiceStatus(json['serviceStatus']?.toString()),
      confirmationNumber: (json['confirmationNumber'] ?? '').toString(),
      serviceKind: (json['serviceKind'] ?? 'rental').toString(),
    );
  }
}

class EventServicesHub {
  EventServicesHub({
    required this.eventId,
    required this.eventTitle,
    required this.availableServices,
    required this.categories,
    required this.vendors,
    required this.myBookings,
    required this.bookingCount,
    this.startsAt,
    this.endsAt,
  });

  final String eventId;
  final String eventTitle;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<({String id, String label, String description, int vendorCount, int itemCount})>
      availableServices;
  final List<String> categories;
  final List<EventServiceVendor> vendors;
  final List<EventServiceBooking> myBookings;
  final int bookingCount;

  factory EventServicesHub.fromJson(Map<String, dynamic> json) {
    final services = <({String id, String label, String description, int vendorCount, int itemCount})>[];
    for (final e in json['availableServices'] as List<dynamic>? ?? const []) {
      if (e is! Map) continue;
      services.add((
        id: (e['id'] ?? '').toString(),
        label: (e['label'] ?? '').toString(),
        description: (e['description'] ?? '').toString(),
        vendorCount: (e['vendorCount'] as num?)?.toInt() ?? 0,
        itemCount: (e['itemCount'] as num?)?.toInt() ?? 0,
      ));
    }
    return EventServicesHub(
      eventId: (json['eventId'] ?? '').toString(),
      eventTitle: (json['eventTitle'] ?? 'Event').toString(),
      startsAt: DateTime.tryParse((json['startsAt'] ?? '').toString()),
      endsAt: DateTime.tryParse((json['endsAt'] ?? '').toString()),
      availableServices: services,
      categories: (json['categories'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      vendors: (json['vendors'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => EventServiceVendor.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      myBookings: (json['myBookings'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => EventServiceBooking.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      bookingCount: (json['bookingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ServiceNotification {
  ServiceNotification({
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

  factory ServiceNotification.fromJson(Map<String, dynamic> json) {
    return ServiceNotification(
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

class EventServicesApi {
  EventServicesApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Uri _u(String path) => Uri.parse('${OwambeApiAuth.resolveApiBase()}/$path');

  Future<Map<String, String>> _headers(AuthSession session) =>
      OwambeApiAuth.authorizedHeaders(tenantId: OwambeApiAuth.resolveTenantId());

  void _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        throw EventServicesApiException(
          code: (body['code'] ?? 'ERROR').toString(),
          message: (body['message'] ?? res.body).toString(),
        );
      }
    } catch (e) {
      if (e is EventServicesApiException) rethrow;
    }
    throw EventServicesApiException(code: 'HTTP_${res.statusCode}', message: res.body);
  }

  Future<EventServicesHub> fetchHub({required AuthSession session, required String eventId}) async {
    final res = await _http.get(_u('events/$eventId/services'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    return EventServicesHub.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<EventServiceVendor>> listVendors({
    required AuthSession session,
    required String eventId,
    String? q,
    String? category,
  }) async {
    final uri = _u('events/$eventId/services/vendors').replace(queryParameters: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
    });
    final res = await _http.get(uri, headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => EventServiceVendor.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<RentalCatalogItem>> listRentals({
    required AuthSession session,
    required String eventId,
    String? category,
  }) async {
    final uri = _u('events/$eventId/services/rentals').replace(queryParameters: {
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
    });
    final res = await _http.get(uri, headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => RentalCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventServiceBooking> bookRental({
    required AuthSession session,
    required String eventId,
    required String catalogItemId,
    required int quantityRequested,
    String? requesterName,
    String? deliveryDate,
    String? pickupDate,
    String? deliveryAddress,
  }) async {
    final res = await _http.post(
      _u('events/$eventId/services/rentals/bookings'),
      headers: await _headers(session),
      body: jsonEncode({
        'catalogItemId': catalogItemId,
        'quantityRequested': quantityRequested,
        if (requesterName != null) 'requesterName': requesterName,
        if (deliveryDate != null) 'deliveryDate': deliveryDate,
        if (pickupDate != null) 'pickupDate': pickupDate,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return EventServiceBooking.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<EventServiceBooking>> listMyBookings({
    required AuthSession session,
    String? eventId,
  }) async {
    final uri = _u('me/service-bookings').replace(queryParameters: {
      if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
    });
    final res = await _http.get(uri, headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => EventServiceBooking.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<EventServiceBooking> cancelBooking({
    required AuthSession session,
    required String bookingId,
  }) async {
    final res = await _http.post(
      _u('me/service-bookings/$bookingId/cancel'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    return EventServiceBooking.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<ServiceNotification>> fetchNotifications(AuthSession session) async {
    final res = await _http.get(_u('me/service-notifications'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => ServiceNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
