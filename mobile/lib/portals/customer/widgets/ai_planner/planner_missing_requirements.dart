import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../eos/eos.dart';
import '../../models/ai_planner_models.dart';
import '../../router/customer_routes.dart';

class PlannerMissingRequirements extends StatelessWidget {
  const PlannerMissingRequirements({
    super.key,
    required this.items,
    required this.eventId,
  });

  final List<PlannerMissingRequirement> items;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EosSurfaceCard(
        elevated: true,
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: context.eosColors.primary),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(
              child: Text(
                'No critical gaps detected. You are in great shape!',
                style: context.eosText.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              elevated: true,
              onTap: item.actionRoute == null ? null : () => _navigate(context, item.actionRoute!),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconFor(item.severity), color: _colorFor(item.severity), size: 22),
                  SizedBox(width: context.eos.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: context.eos.spacing.xs),
                        Text(item.description, style: context.eosText.bodySmall),
                      ],
                    ),
                  ),
                  if (item.actionRoute != null) const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _navigate(BuildContext context, String route) {
    switch (route) {
      case 'vendors':
        context.push(CustomerRoutes.vendors);
      case 'guests':
        context.push(CustomerRoutes.eventGuests(eventId));
      case 'budget':
        context.push(CustomerRoutes.eventBudget(eventId));
    }
  }

  IconData _iconFor(PlannerRequirementSeverity severity) => switch (severity) {
        PlannerRequirementSeverity.critical => Icons.error_outline,
        PlannerRequirementSeverity.important => Icons.warning_amber_outlined,
        PlannerRequirementSeverity.suggestion => Icons.lightbulb_outline,
      };

  Color _colorFor(PlannerRequirementSeverity severity) => switch (severity) {
        PlannerRequirementSeverity.critical => const Color(0xFFDC2626),
        PlannerRequirementSeverity.important => const Color(0xFFD4A853),
        PlannerRequirementSeverity.suggestion => const Color(0xFF60A5FA),
      };
}
