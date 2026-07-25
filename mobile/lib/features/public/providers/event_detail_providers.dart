import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../portals/attendee/providers/attendee_profile_providers.dart';
import '../../../portals/customer/models/program_models.dart';
import '../../public/providers/attendee_events_provider.dart';
import '../data/recently_viewed_events_store.dart';
import '../models/public_models.dart';
import 'public_providers.dart';

/// Offline detection — fails soft if connectivity plugin is unavailable (web hot reload).
final attendeeOfflineProvider = Provider.autoDispose<bool>((ref) {
  final async = ref.watch(_connectivityOfflineProvider);
  return async.maybeWhen(data: (v) => v, orElse: () => false);
});

final _connectivityOfflineProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.isEmpty || results.every((r) => r == ConnectivityResult.none);
  } catch (_) {
    return false;
  }
});

final publicEventProgramProvider =
    FutureProvider.autoDispose.family<ProgramSnapshot, String>((ref, eventId) async {
  final json = await ref.watch(eventsApiProvider).fetchPublicProgram(eventId);
  return ProgramSnapshot.fromJson(json);
});

/// @Deprecated — use [publicEventProgramProvider] (full ProgramSnapshot).
typedef EventProgramSnapshot = ProgramSnapshot;

final eventDetailSimilarProvider =
    Provider.autoDispose.family<AsyncValue<List<PublicEvent>>, String>((ref, eventId) {
  final engine = ref.watch(discoverRecommendationEngineProvider);
  return ref.watch(publicEventCatalogProvider).whenData((catalog) {
    final seed = catalog.where((e) => e.id == eventId).firstOrNull;
    return engine.similar(catalog: catalog, seed: seed, limit: 6);
  });
});

final eventDetailFromOrganizerProvider =
    Provider.autoDispose.family<AsyncValue<List<PublicEvent>>, String>((ref, eventId) {
  return ref.watch(publicEventCatalogProvider).whenData((catalog) {
    final seed = catalog.where((e) => e.id == eventId).firstOrNull;
    final organizerId = seed?.organizerId;
    if (organizerId == null || organizerId.isEmpty) return const <PublicEvent>[];
    return catalog.where((e) => e.id != eventId && e.organizerId == organizerId).take(6).toList();
  });
});

final eventDetailRecommendedProvider =
    Provider.autoDispose.family<AsyncValue<List<PublicEvent>>, String>((ref, eventId) {
  final engine = ref.watch(discoverRecommendationEngineProvider);
  final profile = ref.watch(attendeeProfileProvider).valueOrNull;
  final recentIds = ref.watch(recentlyViewedEventIdsProvider);
  final purchased = ref.watch(attendeeEventsProvider).valueOrNull?.map((e) => e.eventId).toList() ?? const [];
  return ref.watch(publicEventCatalogProvider).whenData((catalog) {
    return engine.personalized(
      catalog: catalog.where((e) => e.id != eventId).toList(),
      preferredCategories: profile?.preferredEventCategories ?? const [],
      interests: profile?.interests ?? const [],
      recentlyViewedIds: recentIds,
      purchasedEventIds: purchased,
      limit: 6,
    );
  });
});
