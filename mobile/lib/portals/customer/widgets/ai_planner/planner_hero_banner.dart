import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

class PlannerHeroBanner extends StatelessWidget {
  const PlannerHeroBanner({
    super.key,
    required this.readinessScore,
    required this.summary,
    required this.visible,
  });

  final int readinessScore;
  final String summary;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return Container(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        decoration: BoxDecoration(
          borderRadius: EosRadius.card,
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1A45), Color(0xFF7B4FA3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade200, size: 28),
                SizedBox(width: context.eos.spacing.sm),
                Expanded(
                  child: Text(
                    'AI Event Planner',
                    style: context.eosText.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.eos.spacing.sm),
            Text(
              'Tell us about your celebration and get a tailored vendor list, budget split, checklist, and timeline.',
              style: context.eosText.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      decoration: BoxDecoration(
        borderRadius: EosRadius.card,
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: readinessScore / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: Colors.amber.shade200,
                ),
                Text(
                  '$readinessScore%',
                  style: context.eosText.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planning readiness',
                  style: context.eosText.labelLarge?.copyWith(color: Colors.white70),
                ),
                SizedBox(height: context.eos.spacing.xs),
                Text(
                  summary,
                  style: context.eosText.bodyMedium?.copyWith(color: Colors.white),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
