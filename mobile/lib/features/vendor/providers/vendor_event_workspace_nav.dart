import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../portals/customer/models/vendor_crm_models.dart';

/// Deep-link into the existing Events tab → Event Operations Center workspace.
///
/// Conversation Hub must NOT push GoRouter `/vendor/events` (that route does not
/// exist). Canonical path: switch Vendor shell tab 1 and open the existing
/// [VendorEvent360WorkspaceScreen] with request/event identity.
class VendorEventWorkspaceNav {
  const VendorEventWorkspaceNav({
    required this.eventId,
    this.eventUuid,
    this.requestId,
    this.initialTabIndex,
  });

  /// Public event key as used by Event Ops (often `external_ref`, e.g. evt_*).
  final String eventId;

  /// Canonical events.id UUID when known (matches vendor_event_requests.event_id).
  final String? eventUuid;

  /// Shared conversation identity = vendor_event_requests.id
  final String? requestId;

  /// Optional Event Ops tab (Conversation = 3).
  final int? initialTabIndex;
}

class VendorEventWorkspaceNavController extends Notifier<VendorEventWorkspaceNav?> {
  @override
  VendorEventWorkspaceNav? build() => null;

  void open({
    required String eventId,
    String? eventUuid,
    String? requestId,
    int? initialTabIndex,
  }) {
    state = VendorEventWorkspaceNav(
      eventId: eventId,
      eventUuid: eventUuid,
      requestId: requestId,
      initialTabIndex: initialTabIndex,
    );
  }

  void clear() => state = null;
}

final vendorEventWorkspaceNavProvider =
    NotifierProvider<VendorEventWorkspaceNavController, VendorEventWorkspaceNav?>(
  VendorEventWorkspaceNavController.new,
);

/// True when a CRM request belongs to the Event Ops event key.
///
/// Participation APIs often expose `external_ref` as eventId while CRM stores
/// the UUID in [VendorRequest.eventId].
bool vendorRequestMatchesEventKey(
  VendorRequest request, {
  required String eventKey,
  String? eventUuid,
}) {
  if (request.eventId == eventKey) return true;
  if (eventUuid != null && request.eventId == eventUuid) return true;
  final ext = request.eventExternalRef;
  if (ext != null && ext.isNotEmpty) {
    if (ext == eventKey) return true;
    if (eventUuid != null && ext == eventUuid) return true;
  }
  return false;
}

/// All CRM requests for an event, sorted by service label (stable, not updatedAt).
List<VendorRequest> vendorRequestsForEventKey(
  Iterable<VendorRequest> items, {
  required String eventKey,
  String? eventUuid,
}) {
  final matches = items
      .where((r) => vendorRequestMatchesEventKey(r, eventKey: eventKey, eventUuid: eventUuid))
      .toList()
    ..sort((a, b) {
      final la = (a.serviceLabel ?? a.serviceKey ?? '').toLowerCase();
      final lb = (b.serviceLabel ?? b.serviceKey ?? '').toLowerCase();
      final cmp = la.compareTo(lb);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
  return matches;
}

VendorRequest? findVendorRequestById(Iterable<VendorRequest> items, String requestId) {
  for (final r in items) {
    if (r.id == requestId) return r;
  }
  return null;
}

/// Returns the sole request for an event, or null when zero or multiple exist.
VendorRequest? findVendorRequestForEventKey(
  Iterable<VendorRequest> items, {
  required String eventKey,
  String? eventUuid,
}) {
  final matches = vendorRequestsForEventKey(items, eventKey: eventKey, eventUuid: eventUuid);
  if (matches.length == 1) return matches.first;
  return null;
}

/// Result of resolving which service-specific request to open in Event 360.
class VendorRequestSelectionResolution {
  const VendorRequestSelectionResolution._({
    this.requestId,
    this.choices = const [],
    this.validatedRequest,
  });

  final String? requestId;
  final List<VendorRequest> choices;
  final VendorRequest? validatedRequest;

  bool get needsSelection => requestId == null && choices.length > 1;

  bool get hasRequest => requestId != null;

  factory VendorRequestSelectionResolution.none() => const VendorRequestSelectionResolution._();

  factory VendorRequestSelectionResolution.resolved(VendorRequest request) =>
      VendorRequestSelectionResolution._(
        requestId: request.id,
        validatedRequest: request,
      );

  factory VendorRequestSelectionResolution.chooseFrom(List<VendorRequest> choices) =>
      VendorRequestSelectionResolution._(choices: choices);
}

/// Resolve a service-specific request id without silently picking among multiples.
VendorRequestSelectionResolution resolveVendorRequestSelection(
  Iterable<VendorRequest> items, {
  required String eventKey,
  String? eventUuid,
  String? requestId,
}) {
  if (requestId != null && requestId.isNotEmpty) {
    final match = findVendorRequestById(items, requestId);
    if (match != null &&
        vendorRequestMatchesEventKey(match, eventKey: eventKey, eventUuid: eventUuid)) {
      return VendorRequestSelectionResolution.resolved(match);
    }
    // Explicit requestId that doesn't match this event — do not fall back silently.
    return VendorRequestSelectionResolution.none();
  }

  final matches = vendorRequestsForEventKey(items, eventKey: eventKey, eventUuid: eventUuid);
  if (matches.isEmpty) return VendorRequestSelectionResolution.none();
  if (matches.length == 1) return VendorRequestSelectionResolution.resolved(matches.first);
  return VendorRequestSelectionResolution.chooseFrom(matches);
}
