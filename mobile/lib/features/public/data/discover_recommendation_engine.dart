import '../models/discover_filters.dart';
import '../models/public_models.dart';

/// Deterministic recommendation layer for Phase 2.
///
/// Replaceable later by an AI recommendation engine without changing Discover UI:
/// swap [DiscoverRecommendationEngine] implementation behind the same provider.
abstract class DiscoverRecommendationEngine {
  List<PublicEvent> personalized({
    required List<PublicEvent> catalog,
    required List<String> preferredCategories,
    required List<String> interests,
    required List<String> recentlyViewedIds,
    required List<String> purchasedEventIds,
    int limit = 8,
  });

  List<PublicEvent> similar({
    required List<PublicEvent> catalog,
    required PublicEvent? seed,
    int limit = 8,
  });

  List<PublicEvent> recentlyViewed({
    required List<PublicEvent> catalog,
    required List<String> recentlyViewedIds,
    int limit = 8,
  });

  List<PublicEvent> popularNearYou({
    required List<PublicEvent> catalog,
    required DiscoverUserLocation? location,
    int limit = 8,
  });

  List<PublicEvent> trending({
    required List<PublicEvent> catalog,
    int limit = 8,
  });

  List<PublicEvent> nearby({
    required List<PublicEvent> catalog,
    required DiscoverUserLocation? location,
    int limit = 8,
  });
}

class HeuristicDiscoverRecommendationEngine implements DiscoverRecommendationEngine {
  const HeuristicDiscoverRecommendationEngine();

  @override
  List<PublicEvent> personalized({
    required List<PublicEvent> catalog,
    required List<String> preferredCategories,
    required List<String> interests,
    required List<String> recentlyViewedIds,
    required List<String> purchasedEventIds,
    int limit = 8,
  }) {
    final prefCats = preferredCategories.map((e) => e.toLowerCase()).toSet();
    final interestSet = interests.map((e) => e.toLowerCase()).toSet();
    final recent = recentlyViewedIds.toSet();
    final purchased = purchasedEventIds.toSet();

    final scored = <({PublicEvent e, int score})>[];
    for (final e in catalog) {
      if (purchased.contains(e.id)) continue;
      var score = e.engagementScore;
      if (prefCats.contains(e.category.toLowerCase())) score += 80;
      for (final tag in e.tags) {
        if (interestSet.contains(tag.toLowerCase())) score += 40;
      }
      if (interestSet.contains(e.category.toLowerCase())) score += 30;
      if (recent.contains(e.id)) score += 20;
      if (e.isFeatured) score += 15;
      scored.add((e: e, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.e).toList();
  }

  @override
  List<PublicEvent> similar({
    required List<PublicEvent> catalog,
    required PublicEvent? seed,
    int limit = 8,
  }) {
    if (seed == null) {
      // Fallback: same-category clusters from trending.
      return trending(catalog: catalog, limit: limit);
    }
    final scored = <({PublicEvent e, int score})>[];
    for (final e in catalog) {
      if (e.id == seed.id) continue;
      var score = 0;
      if (e.category.toLowerCase() == seed.category.toLowerCase()) score += 50;
      if (seed.organizerId != null && e.organizerId == seed.organizerId) score += 40;
      if (e.city.toLowerCase() == seed.city.toLowerCase()) score += 25;
      final seedTags = seed.tags.map((t) => t.toLowerCase()).toSet();
      for (final t in e.tags) {
        if (seedTags.contains(t.toLowerCase())) score += 15;
      }
      if (e.venueType == seed.venueType) score += 10;
      score += e.engagementScore ~/ 5;
      if (score > 0) scored.add((e: e, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.e).toList();
  }

  @override
  List<PublicEvent> recentlyViewed({
    required List<PublicEvent> catalog,
    required List<String> recentlyViewedIds,
    int limit = 8,
  }) {
    final byId = {for (final e in catalog) e.id: e};
    final out = <PublicEvent>[];
    for (final id in recentlyViewedIds) {
      final e = byId[id];
      if (e != null) out.add(e);
      if (out.length >= limit) break;
    }
    return out;
  }

  @override
  List<PublicEvent> popularNearYou({
    required List<PublicEvent> catalog,
    required DiscoverUserLocation? location,
    int limit = 8,
  }) {
    final near = nearby(catalog: catalog, location: location, limit: catalog.length);
    final ranked = [...near]..sort((a, b) => b.engagementScore.compareTo(a.engagementScore));
    return ranked.take(limit).toList();
  }

  @override
  List<PublicEvent> trending({
    required List<PublicEvent> catalog,
    int limit = 8,
  }) {
    final ranked = [...catalog]..sort((a, b) {
        final byScore = b.engagementScore.compareTo(a.engagementScore);
        if (byScore != 0) return byScore;
        return a.startsAt.compareTo(b.startsAt);
      });
    return ranked.take(limit).toList();
  }

  @override
  List<PublicEvent> nearby({
    required List<PublicEvent> catalog,
    required DiscoverUserLocation? location,
    int limit = 8,
  }) {
    final withCoords = catalog.where((e) => e.hasCoordinates).toList();
    if (withCoords.isEmpty) {
      // Soft fallback: city clusters by upcoming date when no geo yet.
      final sorted = [...catalog]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return sorted.take(limit).toList();
    }
    if (location == null) {
      // No user location — surface geo-tagged events first (still a Nearby rail).
      return withCoords.take(limit).toList();
    }
    final scored = withCoords.map((e) {
      final km = haversineKm(
        lat1: location.latitude,
        lon1: location.longitude,
        lat2: e.venueLatitude!,
        lon2: e.venueLongitude!,
      );
      return (e: e, km: km);
    }).toList()
      ..sort((a, b) => a.km.compareTo(b.km));
    return scored.take(limit).map((s) => s.e).toList();
  }
}
