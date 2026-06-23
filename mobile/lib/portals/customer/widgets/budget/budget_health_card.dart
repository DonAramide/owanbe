import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../models/budget_dashboard_models.dart';

class BudgetHealthCard extends StatelessWidget {
  const BudgetHealthCard({
    super.key,
    required this.health,
    required this.budgetMinor,
    required this.committedMinor,
    required this.remainingMinor,
  });

  final BudgetHealth health;
  final int budgetMinor;
  final int committedMinor;
  final int remainingMinor;

  ({Color bg, Color fg, IconData icon, String label, String message}) _style() => switch (health) {
        BudgetHealth.healthy => (
            bg: EosColors.successSoft,
            fg: EosColors.success,
            icon: Icons.check_circle_outline,
            label: 'Healthy',
            message: 'Spending is on track for your celebration budget.',
          ),
        BudgetHealth.warning => (
            bg: EosColors.warningSoft,
            fg: EosColors.warning,
            icon: Icons.warning_amber_outlined,
            label: 'Warning',
            message: 'You are approaching your budget limit — review allocations.',
          ),
        BudgetHealth.overBudget => (
            bg: EosColors.criticalSoft,
            fg: EosColors.critical,
            icon: Icons.error_outline,
            label: 'Over budget',
            message: 'Committed spend exceeds your planned budget.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final style = _style();
    final pct = budgetMinor == 0 ? 0 : ((committedMinor / budgetMinor) * 100).clamp(0, 999).round();

    return EosSurfaceCard(
      elevated: true,
      accentColor: style.fg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.eos.spacing.sm),
                decoration: BoxDecoration(color: style.bg, borderRadius: EosRadius.chip),
                child: Icon(style.icon, color: style.fg),
              ),
              SizedBox(width: context.eos.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget health', style: context.eosText.labelSmall),
                    Text(
                      style.label,
                      style: context.eosText.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: style.fg,
                      ),
                    ),
                  ],
                ),
              ),
              Text('$pct%', style: context.eosText.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(style.message, style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          ClipRRect(
            borderRadius: EosRadius.chip,
            child: LinearProgressIndicator(
              value: budgetMinor == 0 ? 0 : (committedMinor / budgetMinor).clamp(0.0, 1.2),
              minHeight: 8,
              backgroundColor: context.eosColors.surfaceContainerHighest,
              color: style.fg,
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budget ${formatRevenue(budgetMinor)}', style: context.eosText.bodySmall),
              Text('Committed ${formatRevenue(committedMinor)}', style: context.eosText.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
