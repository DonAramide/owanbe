import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/public_models.dart';

class PublicEventGrid extends StatelessWidget {
  const PublicEventGrid({
    super.key,
    required this.events,
    this.onEventTap,
  });

  final List<PublicEvent> events;
  final void Function(PublicEvent event)? onEventTap;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return EosSurfaceCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.eos.spacing.xl),
            child: Text('No events match your search', style: context.eosText.bodyMedium),
          ),
        ),
      );
    }

    final cols = EosResponsive.columnsFor(context).clamp(1, 3);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = context.eos.spacing.md;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: events.map((e) {
            return SizedBox(
              width: width.clamp(280, 420),
              child: _DiscoverCard(
                event: e,
                onTap: () {
                  if (onEventTap != null) {
                    onEventTap!(e);
                  } else {
                    context.push('/events/${e.id}');
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.event, required this.onTap});

  final PublicEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cheapest = event.cheapestTier();
    return EosSurfaceCard(
      onTap: onTap,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: EosRadius.input,
              gradient: LinearGradient(
                colors: [Color(event.coverGradientStart), Color(event.coverGradientEnd)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: context.eos.spacing.sm,
                  left: context.eos.spacing.sm,
                  child: EosEventStatusBadge(status: event.status),
                ),
                if (event.isFeatured)
                  Positioned(
                    top: context.eos.spacing.sm,
                    right: context.eos.spacing.sm,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: EosColors.champagne,
                        borderRadius: context.eos.radius.chip,
                      ),
                      child: Text('FEATURED', style: context.eosText.labelSmall?.copyWith(color: EosColors.plumDark)),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(event.title, style: context.eosText.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          SizedBox(height: context.eos.spacing.xxs),
          Text('${event.city} · ${event.category}', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              if (cheapest != null)
                Text(
                  'From ${ngnFromMinor(cheapest.priceMinor.toString())}',
                  style: context.eosText.labelLarge?.copyWith(color: context.eosColors.primary),
                ),
              const Spacer(),
              Icon(Icons.arrow_forward, size: 18, color: context.eosColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}
