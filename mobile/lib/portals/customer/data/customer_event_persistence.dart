import '../../../auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendors_api.dart';
import '../../../features/vendor/vendor_identity.dart';
import '../api/customer_events_api.dart';
import '../data/customer_event_dev_store.dart';
import '../models/customer_event_models.dart';
import '../providers/customer_event_providers.dart';
import '../providers/vendor_crm_providers.dart';

Future<CustomerEvent> publishCustomerEvent(WidgetRef ref, String eventId) async {
  try {
    final session = ref.read(authSessionProvider);
    final event = await ref.read(customerEventsApiProvider).publishEvent(eventId, session: session);
    bumpCustomerEventRevision(ref);
    return event;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    final event = CustomerEventDevStore.instance.publish(eventId);
    bumpCustomerEventRevision(ref);
    return event;
  }
}

Future<CustomerEvent> goLiveCustomerEvent(WidgetRef ref, String eventId) async {
  try {
    final session = ref.read(authSessionProvider);
    final event = await ref.read(customerEventsApiProvider).goLiveEvent(eventId, session: session);
    bumpCustomerEventRevision(ref);
    return event;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    final event = CustomerEventDevStore.instance.setLive(eventId);
    bumpCustomerEventRevision(ref);
    return event;
  }
}

Future<void> inviteVendorToEvent(
  WidgetRef ref,
  String eventId,
  MarketplaceVendor vendor, {
  String? message,
  String? serviceLabel,
  String? serviceKey,
  String? vendorServiceId,
}) async {
  try {
    await ref.read(vendorCrmApiProvider).createRequest(eventId, {
      'vendorId': VendorIdentity.resolveMarketplaceVendorId(vendor.id),
      'message': message ?? '',
      if (serviceLabel != null && serviceLabel.trim().isNotEmpty) 'serviceLabel': serviceLabel.trim(),
      if (serviceKey != null && serviceKey.trim().isNotEmpty) 'serviceKey': serviceKey.trim(),
      if (vendorServiceId != null && vendorServiceId.trim().isNotEmpty)
        'vendorServiceId': vendorServiceId.trim(),
      'source': 'marketplace',
    });
    bumpCustomerEventRevision(ref);
    refreshVendorCrm(ref);
    return;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
  }
  CustomerEventDevStore.instance.inviteVendor(eventId, vendor: vendor);
  bumpCustomerEventRevision(ref);
}
