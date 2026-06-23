import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../models/ai_planner_models.dart';

class PlannerInputCard extends StatelessWidget {
  const PlannerInputCard({
    super.key,
    required this.inputs,
    required this.budgetController,
    required this.guestController,
    required this.locationController,
    required this.onEventTypeChanged,
    required this.onBudgetChanged,
    required this.onGuestCountChanged,
    required this.onLocationChanged,
    required this.onGenerate,
    required this.generating,
  });

  final AiPlannerInputs inputs;
  final TextEditingController budgetController;
  final TextEditingController guestController;
  final TextEditingController locationController;
  final ValueChanged<AiPlannerEventType> onEventTypeChanged;
  final ValueChanged<int> onBudgetChanged;
  final ValueChanged<int> onGuestCountChanged;
  final ValueChanged<String> onLocationChanged;
  final VoidCallback onGenerate;
  final bool generating;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Celebration details',
            style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: context.eos.spacing.md),
          EosSelectField<AiPlannerEventType>(
            label: 'Event type',
            value: inputs.eventType,
            items: [
              for (final type in AiPlannerEventType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (v) {
              if (v != null) onEventTypeChanged(v);
            },
          ),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(
            label: 'Budget (₦)',
            hint: 'e.g. 2500000',
            keyboardType: TextInputType.number,
            controller: budgetController,
            onChanged: (raw) {
              final major = int.tryParse(raw.replaceAll(',', '')) ?? 0;
              onBudgetChanged(major * 100);
            },
          ),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(
            label: 'Guest count',
            hint: 'Expected guests',
            keyboardType: TextInputType.number,
            controller: guestController,
            onChanged: (raw) => onGuestCountChanged(int.tryParse(raw) ?? 0),
          ),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(
            label: 'Location',
            hint: 'City or venue area',
            controller: locationController,
            onChanged: onLocationChanged,
          ),
          if (inputs.budgetMinor > 0) ...[
            SizedBox(height: context.eos.spacing.sm),
            Text(
              'Budget: ${formatRevenue(inputs.budgetMinor)} · ${inputs.guestCount} guests',
              style: context.eosText.labelSmall?.copyWith(color: context.eosColors.onSurfaceVariant),
            ),
          ],
          SizedBox(height: context.eos.spacing.lg),
          FilledButton.icon(
            onPressed: generating ? null : onGenerate,
            icon: generating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.eosColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(generating ? 'Generating plan…' : 'Generate my plan'),
          ),
        ],
      ),
    );
  }
}
