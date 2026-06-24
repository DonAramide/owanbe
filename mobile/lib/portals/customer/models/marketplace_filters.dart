import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/vendors_api.dart';

enum MarketplaceSort { recommended, rating, priceLow, priceHigh, name }

class MarketplaceFilters {
  const MarketplaceFilters({
    this.query = '',
    this.serviceCategory = 'All',
    this.city = '',
    this.minRating = 0,
    this.maxPriceMinor = 0,
    this.sort = MarketplaceSort.recommended,
  });

  final String query;
  final String serviceCategory;
  final String city;
  final double minRating;
  final int maxPriceMinor;
  final MarketplaceSort sort;

  MarketplaceFilters copyWith({
    String? query,
    String? serviceCategory,
    String? city,
    double? minRating,
    int? maxPriceMinor,
    MarketplaceSort? sort,
  }) {
    return MarketplaceFilters(
      query: query ?? this.query,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      city: city ?? this.city,
      minRating: minRating ?? this.minRating,
      maxPriceMinor: maxPriceMinor ?? this.maxPriceMinor,
      sort: sort ?? this.sort,
    );
  }
}

final marketplaceFiltersProvider = StateProvider.autoDispose<MarketplaceFilters>((ref) {
  return const MarketplaceFilters();
});

final marketplaceExpectedGuestsProvider = StateProvider.autoDispose<int>((ref) => 150);

List<MarketplaceVendor> applyMarketplaceFilters(List<MarketplaceVendor> vendors, MarketplaceFilters filters) {
  var result = [...vendors];

  if (filters.serviceCategory != 'All') {
    result = result.where((v) => v.matchesService(filters.serviceCategory)).toList();
  }

  if (filters.city.trim().isNotEmpty) {
    final city = filters.city.trim().toLowerCase();
    result = result.where((v) => (v.city ?? '').toLowerCase().contains(city)).toList();
  }

  if (filters.minRating > 0) {
    result = result.where((v) => (v.ratingAverage ?? 0) >= filters.minRating).toList();
  }

  if (filters.maxPriceMinor > 0) {
    result = result
        .where((v) => v.priceFromMinor == null || v.priceFromMinor! <= filters.maxPriceMinor)
        .toList();
  }

  if (filters.query.trim().isNotEmpty) {
    final q = filters.query.trim().toLowerCase();
    result = result
        .where(
          (v) =>
              v.businessName.toLowerCase().contains(q) ||
              v.categoryLabel.toLowerCase().contains(q) ||
              (v.city ?? '').toLowerCase().contains(q) ||
              (v.description ?? '').toLowerCase().contains(q) ||
              (v.slug ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  switch (filters.sort) {
    case MarketplaceSort.rating:
      result.sort((a, b) => (b.ratingAverage ?? 0).compareTo(a.ratingAverage ?? 0));
    case MarketplaceSort.priceLow:
      result.sort((a, b) => (a.priceFromMinor ?? 0).compareTo(b.priceFromMinor ?? 0));
    case MarketplaceSort.priceHigh:
      result.sort((a, b) => (b.priceFromMinor ?? 0).compareTo(a.priceFromMinor ?? 0));
    case MarketplaceSort.name:
      result.sort((a, b) => a.businessName.compareTo(b.businessName));
    case MarketplaceSort.recommended:
      result.sort((a, b) {
        final scoreA = (a.ratingAverage ?? 0) * 10 + (a.isVerified ? 5 : 0);
        final scoreB = (b.ratingAverage ?? 0) * 10 + (b.isVerified ? 5 : 0);
        return scoreB.compareTo(scoreA);
      });
  }

  return result;
}

List<String> marketplaceServiceCategories(List<MarketplaceVendor> vendors) {
  final cats = vendors.map((v) => v.categoryLabel).toSet().toList()..sort();
  return ['All', ...cats];
}

List<String> marketplaceCities(List<MarketplaceVendor> vendors) {
  final cities = vendors.map((v) => v.city).whereType<String>().where((c) => c.isNotEmpty).toSet().toList()
    ..sort();
  return cities;
}
