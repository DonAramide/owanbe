import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../navigation/event_navigator.dart';
import '../providers/customer_budget_providers.dart';
import '../widgets/budget/budget_balance_row.dart';
import '../widgets/budget/budget_health_card.dart';
import '../widgets/budget/budget_pie_chart.dart';
import '../widgets/budget/category_allocation_section.dart';
import '../widgets/budget/vendor_allocation_list.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_loading_skeleton.dart';

/// CUS-043 Budget Dashboard at `/events/:eventId/budget`.
class CustomerEventBudgetScreen extends ConsumerWidget {
  const CustomerEventBudgetScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(customerEventBudgetProvider(eventId));

    return EventModuleScaffold(
      eventId: eventId,
      title: 'Budget',
      subtitle: 'Celebration finances',
      body: budget.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EventErrorView.module(
              moduleLabel: 'budget',
              onRetry: () {
                refreshEventBudget(ref);
                ref.invalidate(customerEventBudgetProvider(eventId));
              },
              onBackToOverview: () => context.eventNav.backToOverview(eventId),
            ),
          ],
        ),
        data: (data) => EventModuleScrollBody(
          onRefresh: () async {
            refreshEventBudget(ref);
            await ref.read(customerEventBudgetProvider(eventId).future);
          },
          primaryKpi: BudgetHealthCard(
            health: data.health,
            budgetMinor: data.budgetMinor,
            committedMinor: data.committedMinor,
            remainingMinor: data.remainingMinor,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BudgetBalanceRow(
                committedMinor: data.committedMinor,
                remainingMinor: data.remainingMinor,
              ),
              SizedBox(height: context.eos.spacing.lg),
              EosSection(
                title: 'Spend breakdown',
                subtitle: 'Where your celebration budget is going.',
                child: BudgetPieChart(slices: data.pieSlices),
              ),
              EosSection(
                title: 'Category allocation',
                subtitle: 'Hall, catering, DJ, décor, and photography.',
                child: CategoryAllocationSection(categories: data.categories),
              ),
              EosSection(
                title: 'Vendor allocation',
                subtitle: 'Committed spend per celebration partner.',
                child: VendorAllocationList(vendors: data.vendors),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
