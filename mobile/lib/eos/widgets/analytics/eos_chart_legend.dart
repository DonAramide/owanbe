import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';

class EosChartLegend extends StatelessWidget {
  const EosChartLegend({super.key, required this.items});

  final List<EosLegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.eos.spacing.md,
      runSpacing: context.eos.spacing.xs,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
              ),
              SizedBox(width: context.eos.spacing.xs),
              Text(item.label, style: context.eosText.labelSmall),
            ],
          ),
      ],
    );
  }
}

class EosLegendItem {
  const EosLegendItem({required this.label, required this.color});
  final String label;
  final Color color;
}
