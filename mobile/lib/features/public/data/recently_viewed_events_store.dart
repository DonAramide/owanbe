import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/bootstrap/shared_preferences_provider.dart';

const _kRecentlyViewedKey = 'attendee_discover_recently_viewed_ids';
const _kMaxRecent = 20;

/// Persist recently viewed public event IDs for Discover rails.
/// Replaceable later by a synced recommendation history API.
class RecentlyViewedEventsStore {
  RecentlyViewedEventsStore(this._prefs);

  final SharedPreferences _prefs;

  List<String> readIds() => List<String>.from(_prefs.getStringList(_kRecentlyViewedKey) ?? const []);

  Future<void> record(String eventId) async {
    if (eventId.trim().isEmpty) return;
    final next = <String>[eventId, ...readIds().where((id) => id != eventId)];
    if (next.length > _kMaxRecent) {
      next.removeRange(_kMaxRecent, next.length);
    }
    await _prefs.setStringList(_kRecentlyViewedKey, next);
  }
}

final recentlyViewedEventsStoreProvider = Provider<RecentlyViewedEventsStore>((ref) {
  return RecentlyViewedEventsStore(ref.watch(sharedPreferencesProvider));
});

final recentlyViewedEventIdsProvider = StateProvider<List<String>>((ref) {
  return ref.watch(recentlyViewedEventsStoreProvider).readIds();
});

Future<void> recordEventViewed(WidgetRef ref, String eventId) async {
  await ref.read(recentlyViewedEventsStoreProvider).record(eventId);
  ref.read(recentlyViewedEventIdsProvider.notifier).state =
      ref.read(recentlyViewedEventsStoreProvider).readIds();
}
