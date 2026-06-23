import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/marketplace_models.dart';

class VendorMetricsRow extends StatelessWidget {
  const VendorMetricsRow({super.key, required this.metrics});

  final VendorMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final width = wide ? (constraints.maxWidth - 3 * context.eos.spacing.md) / 4 : constraints.maxWidth / 2 - context.eos.spacing.sm;

        return Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.md,
          children: [
            _MetricTile(width: width, label: 'Events', value: '${metrics.eventsCompleted}', icon: Icons.celebration_outlined),
            _MetricTile(width: width, label: 'Response', value: '${metrics.responseHours}h', icon: Icons.schedule_outlined),
            _MetricTile(
              width: width,
              label: 'On-time',
              value: '${(metrics.onTimeRate * 100).round()}%',
              icon: Icons.verified_user_outlined,
            ),
            _MetricTile(width: width, label: 'Repeat clients', value: '${metrics.repeatClients}', icon: Icons.favorite_outline),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: EosSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: context.eosColors.primary),
            SizedBox(height: context.eos.spacing.sm),
            Text(value, style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: context.eosText.bodySmall),
          ],
        ),
      ),
    );
  }
}
