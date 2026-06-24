import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../../../features/operations/models/operations_models.dart';
import '../../models/command_center_models.dart';
import '../empty_state_card.dart';

class CommandActivityFeed extends StatelessWidget {
  const CommandActivityFeed({
    super.key,
    required this.items,
  });

  final List<OpsFeedEvent> items;

  IconData _iconFor(FeedEventType type) => switch (type) {
        FeedEventType.guestCheckedIn => Icons.how_to_reg_outlined,
        FeedEventType.vendorJoined => Icons.storefront_outlined,
        FeedEventType.orderPlaced => Icons.receipt_long_outlined,
        FeedEventType.refundRequested => Icons.undo_outlined,
        FeedEventType.incidentLogged => Icons.warning_amber_outlined,
        FeedEventType.wallPost => Icons.forum_outlined,
        FeedEventType.wallPinned => Icons.push_pin_outlined,
      };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateCard(
        title: 'No activity yet',
        message: 'Guest RSVPs, vendor updates, and invitations will appear here.',
        icon: Icons.timeline_outlined,
      );
    }

    final visible = items.take(8).toList();

    return Column(
      children: [
        for (final item in visible)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: context.eosColors.primaryContainer,
                    child: Icon(_iconFor(item.type), size: 18, color: context.eosColors.primary),
                  ),
                  SizedBox(width: context.eos.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.headline, style: context.eosText.titleSmall),
                        if (item.detail.isNotEmpty) ...[
                          SizedBox(height: context.eos.spacing.xxs),
                          Text(item.detail, style: context.eosText.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  Text(formatTimeAgo(item.timestamp), style: context.eosText.labelSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
