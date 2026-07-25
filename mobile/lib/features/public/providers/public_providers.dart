import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../portals/attendee/providers/attendee_profile_providers.dart';
import '../../organizer/providers/organizer_providers.dart';
import '../../public/providers/attendee_events_provider.dart';
import '../data/discover_recommendation_engine.dart';
import '../data/public_event_catalog.dart';
import '../data/recently_viewed_events_store.dart';
import '../models/discover_filters.dart';
import '../models/public_models.dart';

final publicCatalogProvider = Provider<PublicEventCatalog>((ref) => PublicEventCatalog());

final discoverQueryProvider = StateProvider<String>((ref) => '');
final discoverCategoryProvider = StateProvider<String>((ref) => 'all');

final discoverRecommendationEngineProvider = Provider<DiscoverRecommendationEngine>((ref) {
  return const HeuristicDiscoverRecommendationEngine();
});

/// Single cached catalog fetch — powers all Discover marketplace sections.
final publicEventCatalogProvider = FutureProvider.autoDispose<List<PublicEvent>>((ref) async {
  ref.watch(organizerRevisionProvider);
  try {
    return await ref.read(eventsApiProvider).listPublicEvents();
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref.watch(publicCatalogProvider).listEvents();
  }
});

/// Filtered catalog for Discover (search + chips + filter panel). Avoids duplicate API calls.
final discoverFilteredEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  final catalog = ref.watch(publicEventCatalogProvider);
  final query = ref.watch(discoverQueryProvider);
  final chipCategory = ref.watch(discoverCategoryProvider);
  final filters = ref.watch(discoverFiltersProvider);
  final location = ref.watch(discoverUserLocationProvider);

  return catalog.whenData(
    (events) => applyDiscoverFilters(
      events,
      filters,
      location: location,
      searchQuery: query,
      chipCategory: chipCategory,
    ),
  );
});

/// Backward-compatible provider used by landing / tickets / public Discover.
/// Derived from the single cached catalog + search/category/filters (no second list fetch).
final publicEventsProvider = FutureProvider.autoDispose<List<PublicEvent>>((ref) async {
  final events = await ref.watch(publicEventCatalogProvider.future);
  final query = ref.watch(discoverQueryProvider);
  final category = ref.watch(discoverCategoryProvider);
  final filters = ref.watch(discoverFiltersProvider);
  final location = ref.watch(discoverUserLocationProvider);
  return applyDiscoverFilters(
    events,
    filters,
    location: location,
    searchQuery: query,
    chipCategory: category,
  );
});

final publicEventProvider = FutureProvider.autoDispose.family<PublicEvent?, String>((ref, id) async {
  ref.watch(organizerRevisionProvider);
  try {
    return await ref.read(eventsApiProvider).getPublicEvent(id);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref.watch(publicCatalogProvider).getEvent(id);
  }
});

final eventCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final events = await ref.watch(publicEventCatalogProvider.future);
  final cats = events.map((e) => e.category).toSet().toList()..sort();
  return ['all', ...cats];
});

// —— Marketplace section slices (lazy: only computed when watched) ——

List<PublicEvent> _upcoming(List<PublicEvent> events) {
  final now = DateTime.now();
  final list = events.where((e) => e.startsAt.isAfter(now.subtract(const Duration(hours: 6)))).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return list;
}

final discoverFeaturedEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  return ref.watch(discoverFilteredEventsProvider).whenData(
        (events) => events.where((e) => e.isFeatured).take(8).toList(),
      );
});

final discoverTrendingEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  final engine = ref.watch(discoverRecommendationEngineProvider);
  return ref.watch(discoverFilteredEventsProvider).whenData(
        (events) => engine.trending(catalog: events, limit: 8),
      );
});

final discoverUpcomingEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  final pageSize = ref.watch(discoverUpcomingPageSizeProvider);
  return ref.watch(discoverFilteredEventsProvider).whenData(
        (events) => _upcoming(events).take(pageSize).toList(),
      );
});

final discoverUpcomingTotalProvider = Provider.autoDispose<AsyncValue<int>>((ref) {
  return ref.watch(discoverFilteredEventsProvider).whenData((events) => _upcoming(events).length);
});

final discoverFreeEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  return ref.watch(discoverFilteredEventsProvider).whenData(
        (events) => events.where((e) => e.isFree).take(8).toList(),
      );
});

final discoverPaidEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  return ref.watch(discoverFilteredEventsProvider).whenData(
        (events) => events.where((e) => e.isPaid).take(8).toList(),
      );
});

final discoverNearbyEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  final engine = ref.watch(discoverRecommendationEngineProvider);
  final location = ref.watch(discoverUserLocationProvider);
  return ref.watch(discoverFilteredEventsProvider).whenData(
        (events) => engine.nearby(catalog: events, location: location, limit: 8),
      );
});

final discoverPersonalizedEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  final engine = ref.watch(discoverRecommendationEngineProvider);
  final profile = ref.watch(attendeeProfileProvider).valueOrNull;
  final recentIds = ref.watch(recentlyViewedEventIdsProvider);
  final purchased = ref.watch(attendeeEventsProvider).valueOrNull?.map((e) => e.eventId).toList() ?? const [];

  return ref.watch(discoverFilteredEventsProvider).whenData(
        (events) => engine.personalized(
          catalog: events,
          preferredCategories: profile?.preferredEventCategories ?? const [],
          interests: profile?.interests ?? const [],
          recentlyViewedIds: recentIds,
          purchasedEventIds: purchased,
          limit: 8,
        ),
      );
});

final discoverSimilarEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  final engine = ref.watch(discoverRecommendationEngineProvider);
  final recentIds = ref.watch(recentlyViewedEventIdsProvider);
  return ref.watch(discoverFilteredEventsProvider).whenData((events) {
    PublicEvent? seed;
    for (final id in recentIds) {
      for (final e in events) {
        if (e.id == id) {
          seed = e;
          break;
        }
      }
      if (seed != null) break;
    }
    seed ??= events.where((e) => e.isFeatured).firstOrNull ?? events.firstOrNull;
    return engine.similar(catalog: events, seed: seed, limit: 8);
  });
});

final discoverRecentlyViewedEventsProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  final engine = ref.watch(discoverRecommendationEngineProvider);
  final recentIds = ref.watch(recentlyViewedEventIdsProvider);
  return ref.watch(publicEventCatalogProvider).whenData(
        (events) => engine.recentlyViewed(
          catalog: events,
          recentlyViewedIds: recentIds,
          limit: 8,
        ),
      );
});

final discoverPopularNearYouProvider = Provider.autoDispose<AsyncValue<List<PublicEvent>>>((ref) {
  final engine = ref.watch(discoverRecommendationEngineProvider);
  final location = ref.watch(discoverUserLocationProvider);
  return ref.watch(discoverFilteredEventsProvider).whenData(
        (events) => engine.popularNearYou(catalog: events, location: location, limit: 8),
      );
});

class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => [];

  int get itemCount => state.fold(0, (sum, line) => sum + line.quantity);
  int get totalMinor => state.fold(0, (sum, line) => sum + line.lineTotalMinor);

  void addOrUpdate(CartLine line) {
    final idx = state.indexWhere((l) => l.eventId == line.eventId && l.tierId == line.tierId);
    if (idx >= 0) {
      final next = [...state];
      next[idx] = next[idx].copyWith(quantity: next[idx].quantity + line.quantity);
      state = next;
    } else {
      state = [...state, line];
    }
  }

  void setQuantity(String eventId, String tierId, int quantity) {
    if (quantity <= 0) {
      removeLine(eventId, tierId);
      return;
    }
    state = [
      for (final line in state)
        if (line.eventId == eventId && line.tierId == tierId)
          line.copyWith(quantity: quantity)
        else
          line,
    ];
  }

  void removeLine(String eventId, String tierId) {
    state = state.where((l) => !(l.eventId == eventId && l.tierId == tierId)).toList();
  }

  void clear() => state = [];
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

class AttendeeTicketsNotifier extends Notifier<List<AttendeeTicket>> {
  @override
  List<AttendeeTicket> build() => [];

  void addAll(List<AttendeeTicket> tickets) {
    final byId = {for (final t in state) t.id: t};
    for (final t in tickets) {
      byId[t.id] = t;
    }
    state = byId.values.toList();
  }
}

final attendeeTicketsProvider =
    NotifierProvider<AttendeeTicketsNotifier, List<AttendeeTicket>>(AttendeeTicketsNotifier.new);

final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).fold(0, (sum, line) => sum + line.quantity),
);
