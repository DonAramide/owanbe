import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/persistence_providers.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../data/organizer_event_store.dart';

Future<OrganizerEvent> createEventFromDraft(WidgetRef ref, EventWizardDraft draft) async {
  try {
    final event = await ref.read(eventsApiProvider).createEvent({
      'title': draft.title,
      'tagline': draft.tagline,
      'description': draft.description,
      'city': draft.city,
      'venue': draft.venue,
      'category': draft.category,
      'venueType': draft.venueType.name,
      'tags': draft.tags,
      'bannerLabel': draft.bannerLabel,
      'mediaLabels': draft.mediaLabels,
      'startsAt': draft.startsAt.toIso8601String(),
      'endsAt': draft.endsAt.toIso8601String(),
      'ticketTiers': draft.ticketTiers
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'description': t.description,
                'priceMinor': t.priceMinor,
                'currency': t.currency,
                'capacity': t.capacity,
                'remaining': t.remaining,
                'tierType': t.tierType.name,
                'visibility': t.visibility.name,
              })
          .toList(),
    });
    bumpOrganizerRevision(ref);
    return event;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    final event = OrganizerEventStore.instance.createDraft(draft);
    bumpOrganizerRevision(ref);
    return event;
  }
}

Future<OrganizerEvent> publishEvent(WidgetRef ref, String eventId) async {
  try {
    final event = await ref.read(eventsApiProvider).publishEvent(eventId);
    bumpOrganizerRevision(ref);
    return event;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    final event = OrganizerEventStore.instance.publish(eventId);
    bumpOrganizerRevision(ref);
    return event;
  }
}

Future<OrganizerEvent> goLiveEvent(WidgetRef ref, String eventId) async {
  try {
    final event = await ref.read(eventsApiProvider).goLiveEvent(eventId);
    bumpOrganizerRevision(ref);
    return event;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    final event = OrganizerEventStore.instance.setLive(eventId);
    bumpOrganizerRevision(ref);
    return event;
  }
}

Future<OrganizerTicketTier> addTicketTier(WidgetRef ref, String eventId, OrganizerTicketTier tier) async {
  try {
    final created = await ref.read(eventsApiProvider).createTier(eventId, {
      'id': tier.id,
      'name': tier.name,
      'description': tier.description,
      'priceMinor': tier.priceMinor,
      'currency': tier.currency,
      'capacity': tier.capacity,
      'remaining': tier.remaining,
      'tierType': tier.tierType.name,
      'visibility': tier.visibility.name,
      if (tier.salesWindowStart != null) 'salesStartAt': tier.salesWindowStart!.toIso8601String(),
      if (tier.salesWindowEnd != null) 'salesEndAt': tier.salesWindowEnd!.toIso8601String(),
      'salesPaused': tier.salesPaused,
    });
    bumpOrganizerRevision(ref);
    return created;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    final created = OrganizerEventStore.instance.addTicketTier(eventId, tier);
    bumpOrganizerRevision(ref);
    return created;
  }
}

Future<void> updateTicketTier(
  WidgetRef ref,
  String eventId,
  OrganizerTicketTier tier,
  OrganizerTicketTier Function(OrganizerTicketTier) fn,
) async {
  final updated = fn(tier);
  final dbId = tier.dbTierId;
  if (dbId != null) {
    try {
      await ref.read(eventsApiProvider).patchTier(dbId, {
        'name': updated.name,
        'description': updated.description,
        'priceMinor': updated.priceMinor,
        'capacity': updated.capacity,
        'remaining': updated.remaining,
        'tierType': updated.tierType.name,
        'visibility': updated.visibility.name,
        if (updated.salesWindowStart != null) 'salesStartAt': updated.salesWindowStart!.toIso8601String(),
        if (updated.salesWindowEnd != null) 'salesEndAt': updated.salesWindowEnd!.toIso8601String(),
        'salesPaused': updated.salesPaused,
      });
      bumpOrganizerRevision(ref);
      return;
    } catch (e) {
      if (!allowMockPersistenceFallback()) rethrow;
    }
  }
  OrganizerEventStore.instance.updateTicketTier(eventId, tier.id, fn);
  bumpOrganizerRevision(ref);
}

Future<void> updateVendorSlot(
  WidgetRef ref,
  String eventId,
  String vendorId,
  VendorSlotStatus status,
) async {
  if (!allowMockPersistenceFallback()) return;
  OrganizerEventStore.instance.setVendorStatus(eventId, vendorId, status);
  bumpOrganizerRevision(ref);
}

Future<void> inviteVendor(
  WidgetRef ref,
  String eventId, {
  required String businessName,
  required String category,
}) async {
  if (!allowMockPersistenceFallback()) return;
  OrganizerEventStore.instance.inviteVendor(eventId, businessName: businessName, category: category);
  bumpOrganizerRevision(ref);
}

Future<void> updateAttendee(
  WidgetRef ref,
  String eventId,
  OrganizerEvent Function(OrganizerEvent) transform,
) async {
  if (!allowMockPersistenceFallback()) return;
  OrganizerEventStore.instance.update(eventId, transform);
  bumpOrganizerRevision(ref);
}
