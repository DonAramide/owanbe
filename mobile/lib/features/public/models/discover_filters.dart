import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/public_models.dart';

/// Discover marketplace filters — client-side on cached catalog.
/// Architecture-ready: can later map fields onto GET /events query params.
class DiscoverFilters {
  const DiscoverFilters({
    this.dateFrom,
    this.dateTo,
    this.maxPriceMinor = 0,
    this.freeOnly = false,
    this.paidOnly = false,
    this.maxDistanceKm = 0,
    this.venueTypes = const {},
    this.categories = const {},
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;

  /// 0 = no max price filter
  final int maxPriceMinor;
  final bool freeOnly;
  final bool paidOnly;

  /// 0 = no distance filter (Nearby section still ranks by distance when location known)
  final double maxDistanceKm;

  /// physical / virtual / hybrid
  final Set<String> venueTypes;
  final Set<String> categories;

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      maxPriceMinor > 0 ||
      freeOnly ||
      paidOnly ||
      maxDistanceKm > 0 ||
      venueTypes.isNotEmpty ||
      categories.isNotEmpty;

  int get activeCount => [
        if (dateFrom != null || dateTo != null) 1,
        if (maxPriceMinor > 0) 1,
        if (freeOnly || paidOnly) 1,
        if (maxDistanceKm > 0) 1,
        if (venueTypes.isNotEmpty) 1,
        if (categories.isNotEmpty) 1,
      ].length;

  DiscoverFilters copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDates = false,
    int? maxPriceMinor,
    bool? freeOnly,
    bool? paidOnly,
    double? maxDistanceKm,
    Set<String>? venueTypes,
    Set<String>? categories,
  }) {
    return DiscoverFilters(
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      maxPriceMinor: maxPriceMinor ?? this.maxPriceMinor,
      freeOnly: freeOnly ?? this.freeOnly,
      paidOnly: paidOnly ?? this.paidOnly,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      venueTypes: venueTypes ?? this.venueTypes,
      categories: categories ?? this.categories,
    );
  }
}

/// Optional user coordinates for distance / nearby (set via Filters → Use my location).
class DiscoverUserLocation {
  const DiscoverUserLocation({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

final discoverFiltersProvider = StateProvider.autoDispose<DiscoverFilters>((ref) {
  return const DiscoverFilters();
});

final discoverUserLocationProvider = StateProvider.autoDispose<DiscoverUserLocation?>((ref) {
  return null;
});

/// Upcoming page size for lazy "See more" on the Upcoming grid.
final discoverUpcomingPageSizeProvider = StateProvider.autoDispose<int>((ref) => 6);

double haversineKm({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

double _rad(double deg) => deg * math.pi / 180;

List<PublicEvent> applyDiscoverFilters(
  List<PublicEvent> events,
  DiscoverFilters filters, {
  DiscoverUserLocation? location,
  String searchQuery = '',
  String chipCategory = 'all',
}) {
  var result = [...events];

  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    // Preserve existing search semantics: title, city, category.
    result = result
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.city.toLowerCase().contains(q) ||
              e.category.toLowerCase().contains(q),
        )
        .toList();
  }

  if (chipCategory.isNotEmpty && chipCategory != 'all') {
    result = result.where((e) => e.category.toLowerCase() == chipCategory.toLowerCase()).toList();
  }

  if (filters.categories.isNotEmpty) {
    final cats = filters.categories.map((c) => c.toLowerCase()).toSet();
    result = result.where((e) => cats.contains(e.category.toLowerCase())).toList();
  }

  if (filters.venueTypes.isNotEmpty) {
    final types = filters.venueTypes.map((t) => t.toLowerCase()).toSet();
    result = result.where((e) => types.contains(e.venueType.toLowerCase())).toList();
  }

  if (filters.dateFrom != null) {
    final from = DateTime(filters.dateFrom!.year, filters.dateFrom!.month, filters.dateFrom!.day);
    result = result.where((e) => !e.startsAt.isBefore(from)).toList();
  }
  if (filters.dateTo != null) {
    final to = DateTime(filters.dateTo!.year, filters.dateTo!.month, filters.dateTo!.day, 23, 59, 59);
    result = result.where((e) => !e.startsAt.isAfter(to)).toList();
  }

  if (filters.freeOnly) {
    result = result.where((e) => e.isFree).toList();
  } else if (filters.paidOnly) {
    result = result.where((e) => e.isPaid).toList();
  }

  if (filters.maxPriceMinor > 0) {
    result = result.where((e) {
      final cheapest = e.cheapestTier();
      if (cheapest == null) return false;
      return cheapest.priceMinor <= filters.maxPriceMinor;
    }).toList();
  }

  if (filters.maxDistanceKm > 0 && location != null) {
    result = result.where((e) {
      if (!e.hasCoordinates) return false;
      final km = haversineKm(
        lat1: location.latitude,
        lon1: location.longitude,
        lat2: e.venueLatitude!,
        lon2: e.venueLongitude!,
      );
      return km <= filters.maxDistanceKm;
    }).toList();
  }

  return result;
}
