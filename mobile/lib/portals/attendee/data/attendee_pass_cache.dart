import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/ticket_commerce_api.dart';
import '../../../core/bootstrap/shared_preferences_provider.dart';

const _kEntitlementsCachePrefix = 'attendee_pass_entitlements_v1_';

/// Persists last successful entitlement fetch so QR + pass details work offline.
class AttendeePassCache {
  AttendeePassCache(this._prefs);

  final SharedPreferences _prefs;

  String _key(String userId) => '$_kEntitlementsCachePrefix$userId';

  List<TicketEntitlementResponse> read(String userId) {
    final raw = _prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => TicketEntitlementResponse.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> write(String userId, List<TicketEntitlementResponse> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_key(userId), encoded);
  }
}

final attendeePassCacheProvider = Provider<AttendeePassCache>((ref) {
  return AttendeePassCache(ref.watch(sharedPreferencesProvider));
});
