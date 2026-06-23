import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/vendors_api.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../models/ai_planner_models.dart';
import 'customer_budget_providers.dart';
import 'marketplace_providers.dart';

class AiPlannerInputsNotifier extends StateNotifier<AiPlannerInputs?> {
  AiPlannerInputsNotifier() : super(null);

  void setInputs(AiPlannerInputs inputs) => state = inputs;

  void update(AiPlannerInputs Function(AiPlannerInputs current) fn) {
    final current = state;
    if (current != null) state = fn(current);
  }
}

final aiPlannerInputsProvider =
    StateNotifierProvider.autoDispose.family<AiPlannerInputsNotifier, AiPlannerInputs?, String>(
  (ref, eventId) => AiPlannerInputsNotifier(),
);

final aiPlannerGeneratedProvider =
    StateProvider.autoDispose.family<bool, String>((ref, eventId) => false);

void resetAiPlanner(WidgetRef ref, String eventId) {
  ref.read(aiPlannerGeneratedProvider(eventId).notifier).state = false;
}

final aiPlannerEventContextProvider = FutureProvider.autoDispose.family<AiPlannerEventContext, String>(
  (ref, eventId) async {
    ref.watch(organizerRevisionProvider);

    final event = await ref.watch(organizerEventProvider(eventId).future);
    if (event == null) throw StateError('Event not found');

    var budgetMinor = 0;
    try {
      final budget = await ref.watch(customerEventBudgetProvider(eventId).future);
      budgetMinor = budget.budgetMinor;
    } catch (_) {
      budgetMinor = 0;
    }

  final vendors = await ref.watch(marketplaceVendorsProvider.future);

    return AiPlannerEventContext(
      event: event,
      budgetMinor: budgetMinor,
      vendors: vendors,
    );
  },
);

class AiPlannerEventContext {
  const AiPlannerEventContext({
    required this.event,
    required this.budgetMinor,
    required this.vendors,
  });

  final OrganizerEvent event;
  final int budgetMinor;
  final List<MarketplaceVendor> vendors;
}

final aiPlannerPlanProvider = Provider.autoDispose.family<AiPlannerPlan?, String>((ref, eventId) {
  final generated = ref.watch(aiPlannerGeneratedProvider(eventId));
  if (!generated) return null;

  final inputs = ref.watch(aiPlannerInputsProvider(eventId));
  if (inputs == null) return null;

  final context = ref.watch(aiPlannerEventContextProvider(eventId));
  return context.when(
    data: (ctx) => buildAiPlannerPlan(
      inputs: inputs,
      event: ctx.event,
      vendors: ctx.vendors,
    ),
    loading: () => null,
    error: (_, _) => null,
  );
});
