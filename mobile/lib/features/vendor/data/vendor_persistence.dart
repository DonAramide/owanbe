import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../models/vendor_models.dart';
import '../data/vendor_store.dart';
import '../providers/vendor_providers.dart';

Future<void> applyToEvent(WidgetRef ref, String eventId) async {
  try {
    await ref.read(vendorEventsApiProvider).apply(eventId);
    bumpVendorRevision(ref);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    VendorStore.instance.applyToEvent(eventId);
    bumpVendorRevision(ref);
  }
}

Future<void> acceptParticipation(WidgetRef ref, VendorEventParticipation participation) async {
  try {
    await ref.read(vendorEventsApiProvider).accept(participation.eventId);
    bumpVendorRevision(ref);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    VendorStore.instance.acceptParticipation(participation.id);
    bumpVendorRevision(ref);
  }
}

Future<void> rejectParticipation(WidgetRef ref, String eventId) async {
  try {
    await ref.read(vendorEventsApiProvider).reject(eventId);
    bumpVendorRevision(ref);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    bumpVendorRevision(ref);
  }
}
