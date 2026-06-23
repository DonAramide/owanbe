import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/customer_budget_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/budget/budget_balance_row.dart';
import '../widgets/budget/budget_health_card.dart';
import '../widgets/budget/budget_pie_chart.dart';
import '../widgets/budget/category_allocation_section.dart';
import '../widgets/budget/vendor_allocation_list.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';

/// CUS-043 Budget Dashboard at `/events/:eventId/budget`.
class CustomerEventBudgetScreen extends ConsumerWidget {
  const CustomerEventBudgetScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(customerEventBudgetProvider(eventId));

    return Scaffold(
      backgroundColor: EosColors.canvas,
      appBar: AppBar(
        backgroundColor: EosColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(CustomerRoutes.eventDetail(eventId));
            }
          },
        ),
        title: const Text('Budget dashboard'),
      ),
      body: budget.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Could not load budget',
              message: error.toString(),
              actionLabel: 'Back to event',
              onAction: () => context.go(CustomerRoutes.eventDetail(eventId)),
            ),
          ],
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            refreshEventBudget(ref);
            await ref.read(customerEventBudgetProvider(eventId).future);
          },
          child: ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              SectionHeader(
                title: data.event.title,
                subtitle: 'Celebration budget overview',
              ),
              SizedBox(height: context.eos.spacing.md),
              BudgetHealthCard(
                health: data.health,
                budgetMinor: data.budgetMinor,
                committedMinor: data.committedMinor,
                remainingMinor: data.remainingMinor,
              ),
              SizedBox(height: context.eos.spacing.lg),
              BudgetBalanceRow(
                committedMinor: data.committedMinor,
                remainingMinor: data.remainingMinor,
              ),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Spend breakdown',
                subtitle: 'Where your celebration budget is going.',
              ),
              BudgetPieChart(slices: data.pieSlices),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Category allocation',
                subtitle: 'Hall, catering, DJ, décor, and photography.',
              ),
              CategoryAllocationSection(categories: data.categories),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Vendor allocation',
                subtitle: 'Committed spend per celebration partner.',
              ),
              VendorAllocationList(vendors: data.vendors),
              SizedBox(height: context.eos.spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
