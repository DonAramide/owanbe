import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/bootstrap/shared_preferences_provider.dart';

const _kSchedulePrefix = 'attendee_personal_schedule_v1_';

/// Attendee-only personal session picks (local — Phase 7).
class AttendeePersonalScheduleStore {
  AttendeePersonalScheduleStore(this._prefs);

  final SharedPreferences _prefs;

  String _key(String userId, String eventId) => '$_kSchedulePrefix${userId}_$eventId';

  Set<String> read(String userId, String eventId) {
    final raw = _prefs.getString(_key(userId, eventId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> write(String userId, String eventId, Set<String> sessionIds) async {
    await _prefs.setString(_key(userId, eventId), jsonEncode(sessionIds.toList()));
  }

  Future<void> add(String userId, String eventId, String sessionId) async {
    final next = {...read(userId, eventId), sessionId};
    await write(userId, eventId, next);
  }

  Future<void> remove(String userId, String eventId, String sessionId) async {
    final next = {...read(userId, eventId)}..remove(sessionId);
    await write(userId, eventId, next);
  }
}

final attendeePersonalScheduleStoreProvider = Provider<AttendeePersonalScheduleStore>((ref) {
  return AttendeePersonalScheduleStore(ref.watch(sharedPreferencesProvider));
});

final attendeePersonalScheduleProvider =
    StateNotifierProvider.autoDispose.family<_PersonalScheduleNotifier, Set<String>, String>(
  (ref, eventId) {
    final session = ref.watch(authSessionProvider);
    final userId = session?.userId ?? 'guest';
    final store = ref.watch(attendeePersonalScheduleStoreProvider);
    return _PersonalScheduleNotifier(store: store, userId: userId, eventId: eventId);
  },
);

class _PersonalScheduleNotifier extends StateNotifier<Set<String>> {
  _PersonalScheduleNotifier({
    required this.store,
    required this.userId,
    required this.eventId,
  }) : super(store.read(userId, eventId));

  final AttendeePersonalScheduleStore store;
  final String userId;
  final String eventId;

  Future<void> add(String sessionId) async {
    await store.add(userId, eventId, sessionId);
    state = store.read(userId, eventId);
  }

  Future<void> remove(String sessionId) async {
    await store.remove(userId, eventId, sessionId);
    state = store.read(userId, eventId);
  }

  Future<void> toggle(String sessionId) async {
    if (state.contains(sessionId)) {
      await remove(sessionId);
    } else {
      await add(sessionId);
    }
  }
}
