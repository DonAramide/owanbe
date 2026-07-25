import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import 'vendor_intelligence_engine.dart';
import 'vendor_providers.dart';

/// Live vendor CRM inbox — replaces demo negotiations on Vendor Dashboard.
final vendorInboxSnapshotProvider = FutureProvider.autoDispose<VendorCrmSnapshot>((ref) async {
  ref.watch(vendorCrmRefreshProvider);
  final vendorId = await ref.watch(canonicalVendorIdProvider.future);
  return ref.watch(vendorInboxProvider(vendorId).future);
});

List<VendorRequest> vendorInboxPendingRequests(VendorCrmSnapshot snapshot) {
  return snapshot.items
      .where((r) => r.stage == 'new' || r.stage == 'negotiating')
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

List<VendorRequest> vendorInboxAcceptedJobs(VendorCrmSnapshot snapshot) {
  return snapshot.items
      .where((r) => ['accepted', 'scheduled', 'arrived'].contains(r.stage))
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

List<VendorRequest> vendorInboxDeclinedRequests(VendorCrmSnapshot snapshot) {
  return snapshot.items.where((r) => r.stage == 'declined' || r.stage == 'cancelled').toList();
}

List<VendorRequest> vendorInboxCompletedJobs(VendorCrmSnapshot snapshot) {
  return snapshot.items.where((r) => r.stage == 'completed').toList();
}

NegotiationItem vendorRequestToNegotiation(VendorRequest request) {
  final pendingVendor = request.stage == 'new' || request.stage == 'negotiating';
  return NegotiationItem(
    id: request.id,
    clientName: request.organizerName ?? 'Organizer',
    eventName: request.eventTitle ?? 'Event',
    serviceType: request.serviceLabel ?? 'Vendor service',
    originalQuoteMinor: 0,
    counterQuoteMinor: 0,
    status: pendingVendor ? 'pending_vendor' : 'accepted',
    lastUpdated: request.updatedAt,
  );
}

List<NegotiationItem> vendorInboxNegotiations(VendorCrmSnapshot snapshot) {
  return vendorInboxPendingRequests(snapshot).map(vendorRequestToNegotiation).toList();
}

List<String> vendorInboxNotifications(VendorCrmSnapshot snapshot) {
  final notes = <String>[];
  for (final r in snapshot.items.take(8)) {
    final event = r.eventTitle ?? 'Event';
    final label = switch (r.stage) {
      'new' => 'Incoming request: $event',
      'negotiating' => 'Negotiation active: $event',
      'accepted' => 'Accepted job: $event',
      'declined' => 'Declined: $event',
      'completed' => 'Completed: $event',
      _ => 'Update: $event · ${r.stage}',
    };
    notes.add(label);
  }
  return notes;
}

List<IntelligenceInsight> vendorInboxInsights(VendorCrmSnapshot snapshot) {
  final pending = vendorInboxPendingRequests(snapshot).length;
  if (pending == 0) {
    return [
      IntelligenceInsight(
        message: 'No pending vendor requests — inbox is clear.',
        type: 'success',
        timestamp: DateTime.now(),
      ),
    ];
  }
  return [
    IntelligenceInsight(
      message: '$pending request${pending == 1 ? '' : 's'} need your response.',
      type: 'info',
      timestamp: DateTime.now(),
    ),
  ];
}

Future<void> vendorAcceptRequest(WidgetRef ref, VendorRequest request) async {
  await ref.read(vendorCrmApiProvider).transitionStage(request.id, 'accepted');
  refreshVendorCrm(ref);
  bumpVendorRevision(ref);
}

Future<void> vendorDeclineRequest(WidgetRef ref, VendorRequest request, {String? note}) async {
  await ref.read(vendorCrmApiProvider).transitionStage(request.id, 'declined', note: note);
  refreshVendorCrm(ref);
  bumpVendorRevision(ref);
}

Future<void> vendorCounterRequest(
  WidgetRef ref,
  VendorRequest request, {
  required int amountMinor,
  String? message,
}) async {
  await ref.read(vendorCrmApiProvider).counterOffer(
        request.id,
        amountMinor: amountMinor,
        message: message,
      );
  refreshVendorCrm(ref);
  bumpVendorRevision(ref);
}

Future<void> vendorMessageOrganizer(
  WidgetRef ref,
  VendorRequest request, {
  required String message,
}) async {
  await ref.read(vendorCrmApiProvider).postMessage(request.id, message: message);
  refreshVendorCrm(ref);
  bumpVendorRevision(ref);
}
