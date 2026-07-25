import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/operations/models/operations_models.dart';
import '../../../features/operations/providers/operations_providers.dart';
import '../models/budget_dashboard_models.dart';
import '../models/customer_finance_models.dart';
import '../providers/customer_ai_planner_providers.dart';
import '../providers/customer_budget_providers.dart';
import '../providers/customer_event_command_providers.dart';
import '../providers/customer_finance_providers.dart';
import '../providers/customer_guest_providers.dart';
import '../providers/program_providers.dart';
import '../providers/vendor_crm_providers.dart';
import '../models/ai_planner_models.dart';
import '../models/vendor_crm_models.dart';
import '../planning/event_planning_workspace_provider.dart';
import 'event_closing_actions.dart';
import 'event_closing_models.dart';

/// Post-event closing workspace — aggregates existing modules (Phase 5).
final eventClosingWorkspaceProvider =
    FutureProvider.autoDispose.family<EventClosingWorkspace, String>((ref, eventId) async {
  ref.watch(customerEventCommandRefreshProvider);
  ref.watch(customerGuestRefreshProvider);
  ref.watch(customerBudgetRefreshProvider);
  ref.watch(archivedEventIdsProvider);

  final planning = await ref.watch(eventPlanningWorkspaceProvider(eventId).future);
  final snapshot = planning.snapshot;
  final guests = await ref.watch(customerEventGuestsProvider(eventId).future);
  final program = await ref.watch(eventProgramProvider(eventId).future);

  final ctx = await ref.watch(aiPlannerEventContextProvider(eventId).future);
  final inputs = defaultInputsFromEvent(ctx.event, budgetMinor: ctx.budgetMinor);
  final plan = buildAiPlannerPlan(
    inputs: inputs,
    event: ctx.event,
    vendors: ctx.vendors,
  );

  List<OpsGuest> opsGuests = const [];
  List<OpsIncident> incidents = const [];

  try {
    opsGuests = await ref.watch(operationsGuestsProvider(eventId).future);
  } catch (_) {}
  try {
    incidents = await ref.watch(operationsIncidentsProvider(eventId).future);
  } catch (_) {}

  VendorCrmSnapshot? crm;
  try {
    crm = await ref.watch(eventVendorCrmProvider(eventId).future);
  } catch (_) {}

  BudgetDashboardSnapshot? budget;
  try {
    budget = await ref.watch(customerEventBudgetProvider(eventId).future);
  } catch (_) {}

  CustomerEventFinanceSummary? finance;
  try {
    finance = await ref.watch(customerEventFinanceSummaryProvider(eventId).future);
  } catch (_) {}

  final isArchived = ref.read(archivedEventIdsProvider).contains(eventId);
  final phase = isArchived ? EventClosingPhase.archived : EventClosingPhase.active;

  return buildEventClosingWorkspace(
    event: snapshot.event,
    snapshot: snapshot,
    plan: plan,
    program: program,
    guests: guests,
    opsGuests: opsGuests,
    crm: crm,
    budget: budget,
    finance: finance,
    incidents: incidents,
    phase: phase,
  );
});
