import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_planner_models.dart';
import '../models/vendor_crm_models.dart';
import '../providers/customer_ai_planner_providers.dart';
import '../providers/customer_event_command_providers.dart';
import '../providers/customer_event_providers.dart';
import '../providers/customer_guest_providers.dart';
import '../providers/vendor_crm_providers.dart';
import '../../../core/providers/silent_refresh.dart';
import 'event_planning_models.dart';

/// Aggregated planning workspace — orchestrates existing modules, no duplicate logic.
final eventPlanningWorkspaceProvider =
    FutureProvider.autoDispose.family<EventPlanningWorkspace, String>((ref, eventId) async {
  ref.watch(customerEventCommandRefreshProvider);
  ref.watch(customerGuestRefreshProvider);
  ref.watch(customerEventRevisionProvider);

  final snapshot = await ref.watch(customerEventCommandProvider(eventId).future);
  final guests = await ref.watch(customerEventGuestsProvider(eventId).future);

  VendorCrmSnapshot? crm;
  try {
    refreshWhenDataChanges(ref, eventVendorCrmProvider(eventId));
    crm = await ref.read(eventVendorCrmProvider(eventId).future);
  } catch (_) {
    crm = null;
  }

  final ctx = await ref.watch(aiPlannerEventContextProvider(eventId).future);
  final inputs = defaultInputsFromEvent(ctx.event, budgetMinor: ctx.budgetMinor);
  final plan = buildAiPlannerPlan(
    inputs: inputs,
    event: ctx.event,
    vendors: ctx.vendors,
  );

  return buildEventPlanningWorkspace(
    snapshot: snapshot,
    plan: plan,
    crm: crm,
    guests: guests,
  );
});
