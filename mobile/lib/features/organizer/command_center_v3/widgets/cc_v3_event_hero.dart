import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../../../shared/models/event_access_mode.dart';
import '../../models/organizer_models.dart';
import '../../../../portals/customer/models/home_hub_models.dart';
import '../../widgets/organizer_shared.dart';

class CcV3EventHero extends StatelessWidget {
  const CcV3EventHero({
    super.key,
    required this.event,
    required this.daysUntil,
    this.onPublish,
    this.onGoLive,
  });

  final OrganizerEvent event;
  final int daysUntil;
  final VoidCallback? onPublish;
  final VoidCallback? onGoLive;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.celebrantImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _gradientHero(event),
                  )
                : _gradientHero(event),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                ),
              ),
            ),
          ),
          Positioned(
            left: context.eos.spacing.lg,
            right: context.eos.spacing.lg,
            bottom: context.eos.spacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: context.eos.spacing.xs,
                  runSpacing: context.eos.spacing.xs,
                  children: [
                    _HeroChip(label: event.category),
                    _HeroChip(label: event.eventAccessMode.label),
                    _HeroChip(label: organizerStatusLabel(event.status)),
                  ],
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  event.title,
                  style: context.eosText.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (event.tagline.isNotEmpty)
                  Text(
                    event.tagline,
                    style: context.eosText.bodyMedium?.copyWith(color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: context.eos.spacing.xs),
                Text(
                  '${formatEventDate(event.startsAt)} · ${event.venue}, ${event.city}',
                  style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Positioned(
            top: context.eos.spacing.md,
            right: context.eos.spacing.md,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.eos.spacing.md,
                vertical: context.eos.spacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '$daysUntil',
                    style: context.eosText.headlineSmall?.copyWith(
                      color: EosColors.plum,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('days', style: context.eosText.labelSmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientHero(OrganizerEvent event) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(event.coverGradientStart), Color(event.coverGradientEnd)],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}