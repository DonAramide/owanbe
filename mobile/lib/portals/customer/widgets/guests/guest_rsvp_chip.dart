import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/customer_guest_models.dart';

class GuestRsvpChip extends StatelessWidget {
  const GuestRsvpChip({super.key, required this.status});

  final GuestRsvpStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      GuestRsvpStatus.confirmed => (EosColors.successSoft, EosColors.success),
      GuestRsvpStatus.pending => (EosColors.warningSoft, EosColors.warning),
      GuestRsvpStatus.declined => (EosColors.criticalSoft, EosColors.critical),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.eos.spacing.sm,
        vertical: context.eos.spacing.xxs,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: EosRadius.chip),
      child: Text(
        status.label,
        style: context.eosText.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
