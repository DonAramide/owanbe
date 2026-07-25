import 'package:flutter/material.dart';

import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_pass_status.dart';

class AttendeePassStatusChip extends StatelessWidget {
  const AttendeePassStatusChip({super.key, required this.status, this.compact = false});

  final AttendeePassLiveStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: context.eosText.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  (Color, Color) _colors(BuildContext context) {
    switch (status) {
      case AttendeePassLiveStatus.readyForEntry:
        return (EosColors.champagne.withValues(alpha: 0.35), EosColors.plumDark);
      case AttendeePassLiveStatus.checkedIn:
      case AttendeePassLiveStatus.insideEvent:
        return (Colors.green.shade100, Colors.green.shade900);
      case AttendeePassLiveStatus.completed:
        return (Colors.blueGrey.shade100, Colors.blueGrey.shade800);
      case AttendeePassLiveStatus.cancelled:
      case AttendeePassLiveStatus.refunded:
      case AttendeePassLiveStatus.expired:
        return (Colors.red.shade50, Colors.red.shade800);
      case AttendeePassLiveStatus.registered:
        return (context.eosColors.surfaceContainerHighest, context.eosColors.onSurface);
    }
  }
}

class AttendeePassSkeleton extends StatelessWidget {
  const AttendeePassSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 18, width: 160, color: context.eosColors.surfaceContainerHighest),
          SizedBox(height: context.eos.spacing.sm),
          Container(height: 12, width: 220, color: context.eosColors.surfaceContainerHighest),
          SizedBox(height: context.eos.spacing.lg),
          Center(
            child: Container(
              height: 140,
              width: 140,
              color: context.eosColors.surfaceContainerHighest,
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Container(height: 40, color: context.eosColors.surfaceContainerHighest),
        ],
      ),
    );
  }
}
