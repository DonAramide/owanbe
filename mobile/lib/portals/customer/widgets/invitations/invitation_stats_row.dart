import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/invitation_hub_models.dart';
import '../summary_metric_card.dart';

class InvitationStatsRow extends StatelessWidget {
  const InvitationStatsRow({super.key, required this.stats});

  final InvitationFunnelStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final cardWidth = wide ? (constraints.maxWidth - 3 * context.eos.spacing.md) / 4 : constraints.maxWidth / 2 - context.eos.spacing.sm;

        return Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.md,
          children: [
            SizedBox(
              width: cardWidth,
              child: SummaryMetricCard(
                label: 'Sent',
                value: '${stats.sent}',
                icon: Icons.send_outlined,
                accentColor: EosColors.plum,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryMetricCard(
                label: 'Delivered',
                value: '${stats.delivered}',
                subtitle: '${(stats.deliveryRate * 100).round()}% delivery',
                icon: Icons.mark_email_read_outlined,
                accentColor: EosColors.info,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryMetricCard(
                label: 'Opened',
                value: '${stats.opened}',
                subtitle: '${(stats.openRate * 100).round()}% open rate',
                icon: Icons.drafts_outlined,
                accentColor: EosColors.champagne,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryMetricCard(
                label: 'RSVP',
                value: '${stats.rsvp}',
                subtitle: '${(stats.rsvpRate * 100).round()}% conversion',
                icon: Icons.how_to_reg_outlined,
                accentColor: EosColors.success,
              ),
            ),
          ],
        );
      },
    );
  }
}
