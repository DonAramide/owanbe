import 'package:flutter/material.dart';

import '../../../eos/eos.dart';
import '../../models/ai_planner_models.dart';

class PlannerRentalRecommendations extends StatelessWidget {
  const PlannerRentalRecommendations({super.key, required this.items});

  final List<PlannerRentalRecommendation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${item.categoryLabel} · ${item.suggestedQuantity}'),
                subtitle: Text(item.rationale),
              ),
            ),
          ),
      ],
    );
  }
}
