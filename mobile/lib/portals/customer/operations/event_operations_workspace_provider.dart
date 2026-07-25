import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/operations/models/operations_models.dart';
import '../../../features/operations/providers/operations_providers.dart';
import '../models/vendor_crm_models.dart';
import '../planning/event_planning_workspace_provider.dart';
import '../providers/customer_event_command_providers.dart';
import '../providers/customer_guest_providers.dart';
import '../providers/program_providers.dart';
import '../providers/vendor_crm_providers.dart';
import '../closing/event_closing_actions.dart';
import 'event_operations_models.dart';

/// Live operations workspace — aggregates existing ops infrastructure (Phase 4).
final eventOperationsWorkspaceProvider =
    FutureProvider.autoDispose.family<EventOperationsWorkspace, String>((ref, eventId) async {
  ref.watch(customerEventCommandRefreshProvider);
  ref.watch(operationsRevisionProvider);
  ref.watch(customerGuestRefreshProvider);

  final planning = await ref.watch(eventPlanningWorkspaceProvider(eventId).future);
  final snapshot = planning.snapshot;
  final guests = await ref.watch(customerEventGuestsProvider(eventId).future);
  final program = await ref.watch(eventProgramProvider(eventId).future);

  List<OpsGuest> opsGuests = const [];
  List<OpsFeedEvent> opsFeed = const [];
  List<OpsIncident> incidents = const [];
  EventHealthSnapshot? health;
  LiveEventKpis? kpis;
  List<VendorOpsSnapshot> vendorOps = const [];

  try {
    opsGuests = await ref.watch(operationsGuestsProvider(eventId).future);
  } catch (_) {}
  try {
    opsFeed = await ref.watch(operationsFeedProvider(eventId).future);
  } catch (_) {}
  try {
    incidents = await ref.watch(operationsIncidentsProvider(eventId).future);
  } catch (_) {}
  try {
    health = await ref.watch(operationsHealthProvider(eventId).future);
  } catch (_) {}
  try {
    kpis = await ref.watch(operationsKpisProvider(eventId).future);
  } catch (_) {}
  try {
    vendorOps = await ref.watch(operationsVendorsProvider(eventId).future);
  } catch (_) {}

  VendorCrmSnapshot? crm;
  try {
    crm = await ref.watch(eventVendorCrmProvider(eventId).future);
  } catch (_) {}

  return buildEventOperationsWorkspace(
    event: snapshot.event,
    lifecycleStage: planning.lifecycleStage,
    snapshot: snapshot,
    guests: guests,
    opsGuests: opsGuests,
    program: program,
    crm: crm,
    vendorOps: vendorOps,
    health: health,
    kpis: kpis,
    opsFeed: opsFeed,
    incidents: incidents,
  );
});

/// Resolves which primary surface Event Desktop should show.
final eventDesktopModeProvider = FutureProvider.autoDispose.family<EventDesktopMode, String>(
  (ref, eventId) async {
    ref.watch(archivedEventIdsProvider);
    if (ref.read(archivedEventIdsProvider).contains(eventId)) {
      return EventDesktopMode.archived;
    }
    final ops = await ref.watch(eventOperationsWorkspaceProvider(eventId).future);
    return ops.mode;
  },
);
