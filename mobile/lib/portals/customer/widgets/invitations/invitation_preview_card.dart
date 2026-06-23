import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../../../features/organizer/models/organizer_models.dart';
import '../../models/home_hub_models.dart';

class InvitationPreviewCard extends StatelessWidget {
  const InvitationPreviewCard({super.key, required this.event});

  final OrganizerEvent event;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: EosRadius.card,
              gradient: LinearGradient(
                colors: [
                  Color(event.coverGradientStart),
                  Color(event.coverGradientEnd),
                ],
              ),
            ),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            alignment: Alignment.bottomLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.eos.spacing.sm,
                    vertical: context.eos.spacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: EosColors.champagne.withValues(alpha: 0.92),
                    borderRadius: EosRadius.chip,
                  ),
                  child: Text(
                    "You're invited",
                    style: context.eosText.labelSmall?.copyWith(
                      color: EosColors.plumDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  event.title,
                  style: context.eosText.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Text(
            event.tagline.isNotEmpty ? event.tagline : event.category,
            style: context.eosText.bodyMedium,
          ),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            '${formatEventDate(event.startsAt)} · ${event.venue}, ${event.city}',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.md),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.celebration_outlined),
            label: const Text('RSVP to celebrate'),
          ),
        ],
      ),
    );
  }
}
