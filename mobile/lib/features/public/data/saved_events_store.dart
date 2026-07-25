import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/bootstrap/shared_preferences_provider.dart';

const _kSavedEventsKey = 'attendee_saved_event_ids';

class SavedEventsStore {
  SavedEventsStore(this._prefs);
  final SharedPreferences _prefs;

  List<String> readIds() => List<String>.from(_prefs.getStringList(_kSavedEventsKey) ?? const []);

  bool isSaved(String eventId) => readIds().contains(eventId);

  Future<bool> toggle(String eventId) async {
    final next = [...readIds()];
    final saved = next.contains(eventId);
    if (saved) {
      next.remove(eventId);
    } else {
      next.insert(0, eventId);
    }
    await _prefs.setStringList(_kSavedEventsKey, next);
    return !saved;
  }
}

final savedEventsStoreProvider = Provider<SavedEventsStore>((ref) {
  return SavedEventsStore(ref.watch(sharedPreferencesProvider));
});

final savedEventIdsProvider = StateProvider<List<String>>((ref) {
  return ref.watch(savedEventsStoreProvider).readIds();
});

final isEventSavedProvider = Provider.family<bool, String>((ref, eventId) {
  return ref.watch(savedEventIdsProvider).contains(eventId);
});

Future<bool> toggleSavedEvent(WidgetRef ref, String eventId) async {
  final saved = await ref.read(savedEventsStoreProvider).toggle(eventId);
  ref.read(savedEventIdsProvider.notifier).state = ref.read(savedEventsStoreProvider).readIds();
  return saved;
}
