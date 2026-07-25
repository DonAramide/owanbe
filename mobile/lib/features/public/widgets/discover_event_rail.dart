import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/public_models.dart';

/// Horizontal marketplace rail for Discover sections.
class DiscoverEventRail extends StatelessWidget {
  const DiscoverEventRail({
    super.key,
    required this.title,
    required this.events,
    required this.onEventTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<PublicEvent> events;
  final void Function(PublicEvent event) onEventTap;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return EosSection(
      title: title,
      subtitle: subtitle,
      child: SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: events.length,
          separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.sm),
          itemBuilder: (context, index) {
            final event = events[index];
            return SizedBox(
              width: 220,
              child: _RailCard(event: event, onTap: () => onEventTap(event)),
            );
          },
        ),
      ),
    );
  }
}

class DiscoverAsyncRail extends StatelessWidget {
  const DiscoverAsyncRail({
    super.key,
    required this.title,
    required this.asyncEvents,
    required this.onEventTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final AsyncValue<List<PublicEvent>> asyncEvents;
  final void Function(PublicEvent event) onEventTap;

  @override
  Widget build(BuildContext context) {
    return asyncEvents.when(
      loading: () => EosSection(
        title: title,
        subtitle: subtitle,
        child: const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (events) => DiscoverEventRail(
        title: title,
        subtitle: subtitle,
        events: events,
        onEventTap: onEventTap,
      ),
    );
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({required this.event, required this.onTap});

  final PublicEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cheapest = event.cheapestTier();
    return EosSurfaceCard(
      onTap: onTap,
      elevated: true,
      padding: EdgeInsets.all(context.eos.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 88,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: EosRadius.input,
              gradient: LinearGradient(
                colors: [Color(event.coverGradientStart), Color(event.coverGradientEnd)],
              ),
            ),
            child: Stack(
              children: [
                if (event.isFeatured)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: EosColors.champagne,
                        borderRadius: context.eos.radius.chip,
                      ),
                      child: Text(
                        'FEATURED',
                        style: context.eosText.labelSmall?.copyWith(color: EosColors.plumDark),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: context.eos.radius.chip,
                    ),
                    child: Text(
                      event.venueType.toUpperCase(),
                      style: context.eosText.labelSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.xs),
          Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.eosText.titleSmall),
          Text(
            '${event.city} · ${event.category}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.eosText.bodySmall,
          ),
          const Spacer(),
          Text(
            cheapest == null
                ? 'Tickets TBA'
                : cheapest.priceMinor <= 0
                    ? 'Free'
                    : 'From ${ngnFromMinor(cheapest.priceMinor.toString())}',
            style: context.eosText.labelMedium?.copyWith(color: context.eosColors.primary),
          ),
        ],
      ),
    );
  }
}
