import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';
import '../cards/eos_surface_card.dart';
import 'eos_event_status_badge.dart';

class EosEventCard extends StatelessWidget {
  const EosEventCard({
    super.key,
    required this.title,
    required this.dateLabel,
    required this.venue,
    required this.status,
    this.attendeeCount,
    this.onTap,
  });

  final String title;
  final String dateLabel;
  final String venue;
  final String status;
  final int? attendeeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      onTap: onTap,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.eosColors.primaryContainer,
                  borderRadius: context.eos.radius.input,
                ),
                child: Icon(Icons.celebration_outlined, color: context.eosColors.primary),
              ),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.eosText.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(dateLabel, style: context.eosText.bodySmall),
                  ],
                ),
              ),
              EosEventStatusBadge(status: status),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: EosColors.slate500),
              SizedBox(width: context.eos.spacing.xxs),
              Expanded(child: Text(venue, style: context.eosText.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (attendeeCount != null)
                Text('$attendeeCount going', style: context.eosText.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
