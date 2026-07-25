import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../models/command_center_models.dart';
import '../../widgets/command_center/command_activity_feed.dart';

/// Post-event summary surface when lifecycle is completed (Phase 4).
class EventCompletedReports extends StatelessWidget {
  const EventCompletedReports({
    super.key,
    required this.snapshot,
  });

  final EventCommandCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final event = snapshot.event;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Event Reports', style: context.eosText.titleLarge),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Final operational summary for ${event.title}',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.lg),
        Row(
          children: [
            Expanded(
              child: EosKpiCard(
                title: 'Guests',
                value: '${snapshot.guestInvited}',
                subtitle: '${snapshot.guestRsvp} RSVPs · ${snapshot.guestCheckedIn} checked in',
              ),
            ),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(
              child: EosKpiCard(
                title: 'Revenue',
                value: formatRevenue(event.revenueMinor),
                subtitle: '${event.ticketsSold} tickets sold',
              ),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.md),
        EosKpiCard(
          title: 'Vendors',
          value: '${snapshot.vendorCompleted}',
          subtitle: '${snapshot.vendorAccepted} confirmed · ${snapshot.vendorRequested} requested',
        ),
        SizedBox(height: context.eos.spacing.lg),
        Text('Activity log', style: context.eosText.titleMedium),
        SizedBox(height: context.eos.spacing.sm),
        CommandActivityFeed(items: snapshot.feed),
      ],
    );
  }
}
