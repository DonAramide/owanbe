import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/crm_sse_client.dart';
import 'vendor_crm_providers.dart';

/// Feature flag — mirrors API `CRM_REALTIME_SSE`. Default true when unset.
bool crmRealtimeSseEnabled() {
  final raw = (dotenv.env['CRM_REALTIME_SSE'] ?? 'true').trim().toLowerCase();
  return raw == 'true' || raw == '1' || raw == 'yes';
}

void _crmMetric(String metric, [Map<String, String> fields = const {}]) {
  developer.log(
    fields.isEmpty ? metric : '$metric $fields',
    name: 'crm_realtime',
  );
}

/// Phase 3A/3B ingress: SSE → dedupe → bump existing CRM refresh (REST authority).
/// Does not replace [vendorCrmLiveTickProvider] polling.
final crmRealtimeLifecycleProvider = Provider<void>((ref) {
  final userId = ref.watch(authSessionProvider.select((s) => s?.userId));
  if (!crmRealtimeSseEnabled() || userId == null || userId.isEmpty) {
    return;
  }

  final dedupe = CrmRealtimeDedupeCache();
  final knownUpdatedAt = <String, DateTime>{};

  Future<void> recoverViaRest() async {
    _crmMetric('crm_rest_recovery_refresh');
    refreshVendorCrm(ref);
  }

  void handleEvent(CrmRealtimeEnvelope evt) {
    if (!dedupe.claim(evt.eventId, evt.dedupeKey)) {
      _crmMetric('crm_realtime_dedupe_drop', {
        'eventId': evt.eventId,
        'dedupeKey': evt.dedupeKey,
      });
      // Soft refresh once is still safe; skip to avoid toast spam paths.
      return;
    }

    final resourceKey = '${evt.resourceType}:${evt.resourceId}';
    final known = knownUpdatedAt[resourceKey];
    if (known != null && evt.updatedAt.isBefore(known)) {
      _crmMetric('crm_realtime_stale_drop', {
        'eventId': evt.eventId,
        'requestId': evt.resourceId,
      });
      return;
    }
    knownUpdatedAt[resourceKey] = evt.updatedAt;

    _crmMetric('crm_realtime_deliver', {
      'type': evt.type,
      'eventId': evt.eventId,
      'requestId': evt.resourceId,
    });
    refreshVendorCrm(ref);
  }

  final client = CrmSseClient(
    onEvent: handleEvent,
    onReconnectRefresh: recoverViaRest,
    onLog: _crmMetric,
  );

  // Fire-and-forget; errors are internal to the client reconnect loop.
  // ignore: discarded_futures
  client.start();

  ref.onDispose(() {
    // ignore: discarded_futures
    client.stop();
  });
});
