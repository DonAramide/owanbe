import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/program_constants.dart';
import '../../models/program_models.dart';
import 'program_status_badge.dart';

class ProgramDayWidget extends StatelessWidget {
  const ProgramDayWidget({
    super.key,
    required this.day,
    this.onOpenProgram,
  });

  final ProgramDaySnapshot day;
  final VoidCallback? onOpenProgram;

  @override
  Widget build(BuildContext context) {
    final current = day.current;
    final next = day.next;

    return EosSurfaceCard(
      onTap: onOpenProgram,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: EosColors.plum),
              SizedBox(width: context.eos.spacing.sm),
              Text('Run sheet', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (day.countdownLabel != null)
                Text(
                  '${day.countdownLabel}: ${formatProgramCountdown(day.countdownSeconds)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          if (current != null) ...[
            Text('Now', style: Theme.of(context).textTheme.labelSmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(current.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${formatProgramTime(current.startTime)} · ${programOwnerLabels[current.ownerType] ?? current.ownerName}',
              ),
              trailing: ProgramStatusBadge(status: current.status),
            ),
          ] else
            Text(
              'No activity in progress',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          if (next != null && (current == null || next.id != current.id)) ...[
            SizedBox(height: context.eos.spacing.sm),
            Text('Up next', style: Theme.of(context).textTheme.labelSmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(next.title),
              subtitle: Text(
                '${formatProgramTime(next.startTime)} · ${programOwnerLabels[next.ownerType] ?? next.ownerName}',
              ),
              trailing: ProgramStatusBadge(status: next.status),
            ),
          ],
          if (onOpenProgram != null) ...[
            SizedBox(height: context.eos.spacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenProgram,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Open full program'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
