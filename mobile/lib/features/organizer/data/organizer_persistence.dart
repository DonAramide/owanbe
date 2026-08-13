import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/events_api.dart';
import '../../../core/api/media_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendors_api.dart';
import '../../../features/vendor/vendor_identity.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../../../shared/models/event_access_mode.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../data/organizer_event_store.dart';

enum EventCreationStage { upload, create }

class EventCreationException implements Exception {
  const EventCreationException({required this.stage, required this.message, this.cause});
  final EventCreationStage stage;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

String _userFacingError(Object error, String fallback) {
  if (error is MediaApiException) return error.message;
  if (error is EventsApiException) return error.message;
  if (error is EventCreationException) return error.message;
  return fallback;
}

Future<String> _uploadCelebrantImage(WidgetRef ref, Uint8List bytes) async {
  final media = ref.read(mediaApiProvider);
  final presign = await media.presignUpload(
    filename: 'celebrant.jpg',
    contentType: 'image/jpeg',
    purpose: 'celebrant_image',
  );
  if (presign.uploadUrl.isEmpty || presign.publicUrl.isEmpty) {
    throw MediaApiException(code: 'INVALID_PRESIGN', message: 'Upload could not be prepared');
  }
  await media.uploadBytes(
    uploadUrl: presign.uploadUrl,
    bytes: bytes,
    contentType: 'image/jpeg',
  );
  return presign.publicUrl;
}

Future<OrganizerEvent> createEventFromV2Draft(
  WidgetRef ref,
  EventWizardV2Draft draft, {
  Uint8List? celebrantImageBytes,
}) async {
  String? celebrantImageUrl;
  if (celebrantImageBytes != null) {
    try {
      celebrantImageUrl = await _uploadCelebrantImage(ref, celebrantImageBytes);
    } catch (e) {
      throw EventCreationException(
        stage: EventCreationStage.upload,
        message: _userFacingError(e, 'Could not upload celebrant photo. Check your connection and try again.'),
        cause: e,
      );
    }
  }

  final body = <String, dynamic>{
    'title': draft.title,
    'tagline': draft.tagline,
    'description': draft.description,
    'city': draft.city,
    'venue': draft.venueName,
    'category': draft.categoryLabel,
    'categorySlug': draft.categorySlug,
    'eventAccessMode': draft.eventAccessMode.apiValue,
    'budgetMinor': draft.budgetMinor,
    'expectedGuests': draft.expectedGuests,
    'venueName': draft.venueName,
    'venueAddress': draft.venueAddress,
    'venueType': draft.venueType.name,
    if (draft.venueLatitude != null) 'venueLatitude': draft.venueLatitude,
    if (draft.venueLongitude != null) 'venueLongitude': draft.venueLongitude,
    if (draft.googlePlaceId != null) 'googlePlaceId': draft.googlePlaceId,
    'tags': draft.tags,
    'startsAt': draft.startsAt.toIso8601String(),
    'endsAt': draft.endsAt.toIso8601String(),
    'budgetAllocation': draft.budgetAllocation,
    'requiredServices': draft.requiredServices,
    'venueDeferred': draft.venueDeferred,
    if (draft.state.isNotEmpty) 'state': draft.state,
    if (draft.lga.isNotEmpty) 'lga': draft.lga,
    if (celebrantImageUrl != null) 'celebrantImageUrl': celebrantImageUrl,
    if (draft.celebrantImageUrl != null && celebrantImageUrl == null)
      'celebrantImageUrl': draft.celebrantImageUrl,
    'language': draft.language,
    'ageRestrictionMin': draft.ageRestrictionMin,
    'listingVisibility': draft.listingVisibility,
    'registrationEnabled': draft.registrationEnabled,
    'checkInEnabled': draft.checkInEnabled,
    'bannerLabel': draft.bannerLabel,
    'themeColor': draft.themeColor,
    if (draft.selectedTemplateSlug.isNotEmpty) 'selectedTemplateSlug': draft.selectedTemplateSlug,
    if (draft.preferredVendorIds.isNotEmpty) 'preferredVendorIds': draft.preferredVendorIds,
  };
  if (draft.eventAccessMode == EventAccessMode.publicTicketed && draft.ticketTiers.isNotEmpty) {
    body['ticketTiers'] = draft.ticketTiers
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
        .toList();
  }

  try {
    final event = await ref.read(eventsApiProvider).createEvent(body);
    bumpOrganizerRevision(ref);
    return event;
  } catch (e) {
    if (allowOfflineMockPersistence()) {
      final legacy = EventWizardDraft(
        title: draft.title,
        tagline: draft.tagline,
        city: draft.city,
        venue: draft.venueName,
        category: draft.categoryLabel,
        tags: draft.tags,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
        ticketTiers: draft.ticketTiers,
      );
      final event = OrganizerEventStore.instance.createDraft(legacy).copyWith(
            eventAccessMode: draft.eventAccessMode,
            budgetMinor: draft.budgetMinor,
            expectedGuests: draft.expectedGuests,
            categorySlug: draft.categorySlug,
            venueName: draft.venueName,
            venueAddress: draft.venueAddress,
            venueLatitude: draft.venueLatitude,
            venueLongitude: draft.venueLongitude,
            googlePlaceId: draft.googlePlaceId,
            celebrantImageUrl: celebrantImageUrl,
          );
      bumpOrganizerRevision(ref);
      return event;
    }
    throw EventCreationException(
      stage: EventCreationStage.create,
      message: _userFacingError(e, 'Could not create event. Please try again.'),
      cause: e,
    );
  }
}

Map<String, dynamic> v2DraftToApiBody(EventWizardV2Draft draft, {String? celebrantImageUrl}) {
  return {
    'title': draft.title,
    'tagline': draft.tagline,
    'description': draft.description,
    'city': draft.city,
    'venue': draft.venueName,
    'category': draft.categoryLabel,
    'categorySlug': draft.categorySlug,
    'eventAccessMode': draft.eventAccessMode.apiValue,
    'budgetMinor': draft.budgetMinor,
    'expectedGuests': draft.expectedGuests,
    'venueName': draft.venueName,
    'venueAddress': draft.venueAddress,
    'venueType': draft.venueType.name,
    if (draft.venueLatitude != null) 'venueLatitude': draft.venueLatitude,
    if (draft.venueLongitude != null) 'venueLongitude': draft.venueLongitude,
    if (draft.googlePlaceId != null) 'googlePlaceId': draft.googlePlaceId,
    'tags': draft.tags,
    'startsAt': draft.startsAt.toIso8601String(),
    'endsAt': draft.endsAt.toIso8601String(),
    'budgetAllocation': draft.budgetAllocation,
    'requiredServices': draft.requiredServices,
    'venueDeferred': draft.venueDeferred,
    if (draft.state.isNotEmpty) 'state': draft.state,
    if (draft.lga.isNotEmpty) 'lga': draft.lga,
    if (celebrantImageUrl != null) 'celebrantImageUrl': celebrantImageUrl,
    if (draft.celebrantImageUrl != null) 'celebrantImageUrl': draft.celebrantImageUrl,
    'language': draft.language,
    'ageRestrictionMin': draft.ageRestrictionMin,
    'listingVisibility': draft.listingVisibility,
    'registrationEnabled': draft.registrationEnabled,
    'checkInEnabled': draft.checkInEnabled,
    'bannerLabel': draft.bannerLabel,
    'themeColor': draft.themeColor,
    if (draft.selectedTemplateSlug.isNotEmpty) 'selectedTemplateSlug': draft.selectedTemplateSlug,
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
  };
}

/// Soft-cancels a mid-wizard server draft so it leaves normal organizer views.
Future<void> discardServerDraft(WidgetRef ref, String eventId) async {
  try {
    await ref.read(eventsApiProvider).discardEvent(eventId);
    bumpOrganizerRevision(ref);
  } catch (e) {
    if (!allowOfflineMockPersistence()) {
      throw EventCreationException(
        stage: EventCreationStage.create,
        message: _userFacingError(e, 'Could not discard draft. Please try again.'),
        cause: e,
      );
    }
  }
}

Future<OrganizerEvent> patchEventFromV2Draft(
  WidgetRef ref,
  String eventId,
  EventWizardV2Draft draft,
) async {
  try {
    final event = await ref.read(eventsApiProvider).patchEvent(eventId, v2DraftToApiBody(draft));
    bumpOrganizerRevision(ref);
    return event;
  } catch (e) {
    if (!allowOfflineMockPersistence()) {
      throw EventCreationException(
        stage: EventCreationStage.create,
        message: _userFacingError(e, 'Could not save draft. Please try again.'),
        cause: e,
      );
    }
    bumpOrganizerRevision(ref);
    return (await ref.read(eventsApiProvider).getOrganizerEvent(eventId)) ??
        OrganizerEventStore.instance.byId(eventId)!;
  }
}

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
    if (!allowOfflineMockPersistence()) {
      throw EventCreationException(
        stage: EventCreationStage.create,
        message: _userFacingError(e, 'Could not create event. Please try again.'),
        cause: e,
      );
    }
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
      'capacity': tier.unlimitedCapacity ? 0 : tier.capacity,
      'remaining': tier.unlimitedCapacity ? 0 : tier.remaining,
      'tierType': tier.tierType.name,
      'visibility': tier.visibility.name,
      if (tier.salesWindowStart != null) 'salesStartAt': tier.salesWindowStart!.toIso8601String(),
      if (tier.salesWindowEnd != null) 'salesEndAt': tier.salesWindowEnd!.toIso8601String(),
      'salesPaused': tier.salesPaused,
      'unlimitedCapacity': tier.unlimitedCapacity,
      'minQuantity': tier.minQuantity,
      if (tier.maxQuantity != null) 'maxQuantity': tier.maxQuantity,
      if (tier.maxPerUser != null) 'maxPerUser': tier.maxPerUser,
      'sortOrder': tier.sortOrder,
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
        'capacity': updated.unlimitedCapacity ? 0 : updated.capacity,
        'remaining': updated.unlimitedCapacity ? 0 : updated.remaining,
        'tierType': updated.tierType.name,
        'visibility': updated.visibility.name,
        if (updated.salesWindowStart != null) 'salesStartAt': updated.salesWindowStart!.toIso8601String(),
        if (updated.salesWindowEnd != null) 'salesEndAt': updated.salesWindowEnd!.toIso8601String(),
        'salesPaused': updated.salesPaused,
        'unlimitedCapacity': updated.unlimitedCapacity,
        'minQuantity': updated.minQuantity,
        'maxQuantity': updated.maxQuantity,
        'maxPerUser': updated.maxPerUser,
        'sortOrder': updated.sortOrder,
        'archived': updated.archived,
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

Future<void> deleteTicketTier(WidgetRef ref, OrganizerTicketTier tier) async {
  final dbId = tier.dbTierId;
  if (dbId == null) {
    throw StateError('Missing tier database id');
  }
  await ref.read(eventsApiProvider).deleteTier(dbId);
  bumpOrganizerRevision(ref);
}

Future<void> archiveTicketTier(WidgetRef ref, OrganizerTicketTier tier) async {
  final dbId = tier.dbTierId;
  if (dbId == null) throw StateError('Missing tier database id');
  await ref.read(eventsApiProvider).archiveTier(dbId);
  bumpOrganizerRevision(ref);
}

Future<void> duplicateTicketTier(WidgetRef ref, OrganizerTicketTier tier) async {
  final dbId = tier.dbTierId;
  if (dbId == null) throw StateError('Missing tier database id');
  await ref.read(eventsApiProvider).duplicateTier(dbId);
  bumpOrganizerRevision(ref);
}

Future<void> reorderTicketTiers(WidgetRef ref, String eventId, List<OrganizerTicketTier> ordered) async {
  await ref.read(eventsApiProvider).reorderTiers(eventId, [for (final t in ordered) t.id]);
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
    bumpOrganizerRevision(ref);
    refreshVendorCrm(ref);
    return;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
  }
  OrganizerEventStore.instance.inviteVendor(eventId, vendor: vendor);
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
