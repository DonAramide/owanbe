import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/command_center_models.dart';

class PlanningProgressRing extends StatelessWidget {
  const PlanningProgressRing({
    super.key,
    required this.progress,
    required this.tasksCompleted,
    required this.tasksRemaining,
    required this.tasks,
  });

  final double progress;
  final int tasksCompleted;
  final int tasksRemaining;
  final List<PlanningTaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: context.eosColors.surfaceContainerHighest,
                      color: context.eosColors.primary,
                    ),
                    Center(
                      child: Text(
                        '$pct%',
                        style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.eos.spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Planning progress', style: context.eosText.titleMedium),
                    SizedBox(height: context.eos.spacing.xs),
                    Text(
                      '$tasksCompleted completed · $tasksRemaining remaining',
                      style: context.eosText.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          ...tasks.map(
            (task) => Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
              child: Row(
                children: [
                  Icon(
                    task.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: task.done ? EosColors.success : context.eosColors.onSurfaceVariant,
                  ),
                  SizedBox(width: context.eos.spacing.sm),
                  Expanded(child: Text(task.label, style: context.eosText.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
