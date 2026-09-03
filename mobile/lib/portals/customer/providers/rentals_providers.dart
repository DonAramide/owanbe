import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owambe_api_auth.dart';
import '../../../core/api/persistence_providers.dart';
import '../models/rentals_models.dart';

class RentalsApi {
  RentalsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId();

  Future<List<RentalCatalogItem>> fetchCatalog({String? category}) async {
    final q = category != null && category.isNotEmpty ? '?category=${Uri.encodeComponent(category)}' : '';
    final res = await _http.get(
      Uri.parse('$_base/rentals/catalog$q'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => RentalCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RentalBooking>> fetchEventBookings(String eventId) async {
    final res = await _http.get(
      Uri.parse('$_base/events/$eventId/rentals'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['bookings'] as List<dynamic>? ?? [])
        .map((e) => RentalBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RentalBooking> createBooking({
    required String eventId,
    required String catalogItemId,
    required int quantityRequested,
    required String requesterName,
    String? deliveryDate,
    String? pickupDate,
    String? deliveryAddress,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/rentals/bookings'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'catalogItemId': catalogItemId,
        'quantityRequested': quantityRequested,
        'requesterName': requesterName,
        if (deliveryDate != null) 'deliveryDate': deliveryDate,
        if (pickupDate != null) 'pickupDate': pickupDate,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return RentalBooking.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<RentalBooking> createVendorBuyerBooking({
    required String eventId,
    required String catalogItemId,
    required String requesterName,
    String? deliveryAddress,
  }) async {
    final res = await _http.post(
      Uri.parse('$_base/events/$eventId/rentals/vendor-buyer-bookings'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'catalogItemId': catalogItemId,
        'quantityRequested': 1,
        'requesterName': requesterName,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return RentalBooking.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<RentalBooking>> fetchMyBookings() async {
    final res = await _http.get(
      Uri.parse('$_base/me/rental-bookings'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['bookings'] as List<dynamic>? ?? [])
        .map((e) => RentalBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<({String id, String title})>> fetchBuyerEligibleEvents() async {
    final res = await _http.get(
      Uri.parse('$_base/me/rental-buyer-events'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      return (id: (m['id'] ?? '').toString(), title: (m['title'] ?? '').toString());
    }).toList();
  }

  Future<({List<RentalCatalogItem> items, List<RentalBlackout> blackouts})> fetchVendorInventory(
    String vendorId,
  ) async {
    final res = await _http.get(
      Uri.parse('$_base/vendors/$vendorId/rentals/inventory'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      items: (body['items'] as List<dynamic>? ?? [])
          .map((e) => RentalCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      blackouts: (body['blackouts'] as List<dynamic>? ?? [])
          .map((e) => RentalBlackout.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<RentalCatalogItem> createInventoryItem(String vendorId, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$_base/vendors/$vendorId/rentals/inventory'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return RentalCatalogItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<RentalBooking>> fetchVendorBookings(String vendorId) async {
    final res = await _http.get(
      Uri.parse('$_base/vendors/$vendorId/rentals/bookings'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['bookings'] as List<dynamic>? ?? [])
        .map((e) => RentalBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RentalBooking> vendorAction(String vendorId, String bookingId, String action, [Map<String, dynamic>? body]) async {
    final res = await _http.post(
      Uri.parse('$_base/vendors/$vendorId/rentals/bookings/$bookingId/$action'),
      headers: await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode(body ?? {}),
    );
    if (res.statusCode >= 400) _throw(res);
    return RentalBooking.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError((body['message'] ?? body['code'] ?? 'Request failed').toString());
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError('Rentals API error (${res.statusCode})');
    }
  }
}

final rentalsApiProvider = Provider<RentalsApi>((ref) => RentalsApi());

final rentalsRefreshProvider = StateProvider<int>((ref) => 0);

void refreshRentals(WidgetRef ref) {
  ref.read(rentalsRefreshProvider.notifier).state++;
}

final rentalsCatalogProvider = FutureProvider.autoDispose.family<List<RentalCatalogItem>, String?>((ref, category) async {
  ref.watch(rentalsRefreshProvider);
  try {
    return await ref.read(rentalsApiProvider).fetchCatalog(category: category);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return const [];
  }
});

final myRentalBookingsProvider = FutureProvider.autoDispose<List<RentalBooking>>((ref) async {
  ref.watch(rentalsRefreshProvider);
  try {
    return await ref.read(rentalsApiProvider).fetchMyBookings();
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return const [];
  }
});

final eventRentalsProvider = FutureProvider.autoDispose.family<List<RentalBooking>, String>((ref, eventId) async {
  ref.watch(rentalsRefreshProvider);
  try {
    return await ref.read(rentalsApiProvider).fetchEventBookings(eventId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return const [];
  }
});

final vendorRentalsBookingsProvider = FutureProvider.autoDispose.family<List<RentalBooking>, String>((ref, vendorId) async {
  ref.watch(rentalsRefreshProvider);
  try {
    return await ref.read(rentalsApiProvider).fetchVendorBookings(vendorId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return const [];
  }
});

final vendorRentalsInventoryProvider =
    FutureProvider.autoDispose.family<({List<RentalCatalogItem> items, List<RentalBlackout> blackouts}), String>(
        (ref, vendorId) async {
  ref.watch(rentalsRefreshProvider);
  try {
    return await ref.read(rentalsApiProvider).fetchVendorInventory(vendorId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return (items: <RentalCatalogItem>[], blackouts: <RentalBlackout>[]);
  }
});
