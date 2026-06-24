import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../models/event_command_center_v3_models.dart';
import '../workspace_tabs.dart';
import 'cc_v3_health_cards.dart';

class CcV3RemindersPanel extends StatelessWidget {
  const CcV3RemindersPanel({
    super.key,
    required this.reminders,
    required this.daysUntil,
    this.onNavigateTab,
  });

  final List<EventReminder> reminders;
  final int daysUntil;
  final void Function(EventWorkspaceTab tab)? onNavigateTab;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return const SizedBox.shrink();

    final countdown = reminders.where((r) => r.kind == EventReminderKind.countdown).toList();
    final rest = reminders.where((r) => r.kind != EventReminderKind.countdown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CcV3SectionHeader(
          title: 'Planning reminders',
          subtitle: 'Countdown, vendors to seal, and guest follow-ups',
        ),
        if (countdown.isNotEmpty) ...[
          _CountdownStrip(reminder: countdown.first, daysUntil: daysUntil),
          SizedBox(height: context.eos.spacing.md),
        ],
        for (final r in rest) ...[
          _ReminderTile(reminder: r, onNavigateTab: onNavigateTab),
          SizedBox(height: context.eos.spacing.sm),
        ],
      ],
    );
  }
}

class _CountdownStrip extends StatelessWidget {
  const _CountdownStrip({required this.reminder, required this.daysUntil});

  final EventReminder reminder;
  final int daysUntil;

  @override
  Widget build(BuildContext context) {
    final accent = switch (reminder.severity) {
      EventReminderSeverity.critical => EosColors.critical,
      EventReminderSeverity.warning => EosColors.warning,
      EventReminderSeverity.info => EosColors.champagne,
    };

    return EosSurfaceCard(
      elevated: true,
      accentColor: accent,
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
              color: accent.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  daysUntil > 0 ? '$daysUntil' : '!',
                  style: context.eosText.headlineSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
                ),
                Text(
                  daysUntil == 1 ? 'day' : 'days',
                  style: context.eosText.labelSmall?.copyWith(color: accent),
                ),
              ],
            ),
          ),
          SizedBox(width: context.eos.spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.headline, style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xxs),
                Text(reminder.detail, style: context.eosText.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, this.onNavigateTab});

  final EventReminder reminder;
  final void Function(EventWorkspaceTab tab)? onNavigateTab;

  @override
  Widget build(BuildContext context) {
    final color = switch (reminder.severity) {
      EventReminderSeverity.critical => EosColors.critical,
      EventReminderSeverity.warning => EosColors.warning,
      EventReminderSeverity.info => EosColors.info,
    };
    final icon = switch (reminder.kind) {
      EventReminderKind.countdown => Icons.event_outlined,
      EventReminderKind.vendor => Icons.handshake_outlined,
      EventReminderKind.attendee => Icons.people_outline,
      EventReminderKind.recommendation => Icons.lightbulb_outline,
    };

    return EosSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.headline, style: context.eosText.titleSmall?.copyWith(color: color)),
                SizedBox(height: context.eos.spacing.xxs),
                Text(reminder.detail, style: context.eosText.bodySmall),
                if (reminder.actionTab != null && onNavigateTab != null) ...[
                  SizedBox(height: context.eos.spacing.xs),
                  TextButton(
                    onPressed: () => onNavigateTab!(reminder.actionTab!),
                    child: Text(reminder.actionLabel ?? 'Open'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
