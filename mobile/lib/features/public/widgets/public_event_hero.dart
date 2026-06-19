import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/public_models.dart';

class PublicEventHero extends StatelessWidget {
  const PublicEventHero({
    super.key,
    required this.event,
    this.onCta,
    this.ctaLabel = 'Get tickets',
  });

  final PublicEvent event;
  final VoidCallback? onCta;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final cheapest = event.cheapestTier();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(event.coverGradientStart),
            Color(event.coverGradientEnd),
          ],
        ),
        borderRadius: EosRadius.card,
        boxShadow: context.eos.shadowSoft,
      ),
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: EosResponsive(
          mobile: _content(context, cheapest, compact: true),
          tablet: _content(context, cheapest),
          desktop: _content(context, cheapest, wide: true),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, TicketTier? cheapest, {bool compact = false, bool wide = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: context.eos.spacing.xs,
          children: [
            EosEventStatusBadge(status: event.status),
            Chip(
              label: Text(event.category),
              backgroundColor: Colors.white24,
              labelStyle: context.eosText.labelSmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.md),
        Text(
          event.title,
          style: context.eosText.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: context.eos.spacing.xs),
        Text(event.tagline, style: context.eosText.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
        SizedBox(height: context.eos.spacing.md),
        Row(
          children: [
            Icon(Icons.place_outlined, color: Colors.white70, size: 18),
            SizedBox(width: context.eos.spacing.xxs),
            Expanded(
              child: Text(
                '${event.venue} · ${event.city}',
                style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          _formatDate(event.startsAt),
          style: context.eosText.labelMedium?.copyWith(color: Colors.white),
        ),
        SizedBox(height: context.eos.spacing.lg),
        Row(
          children: [
            if (cheapest != null)
              Text(
                'From ${ngnFromMinor(cheapest.priceMinor.toString())}',
                style: EosTypography.metric(
                  const ColorScheme.light(onSurface: Colors.white),
                  size: wide ? 28 : 22,
                ).copyWith(color: Colors.white),
              ),
            const Spacer(),
            if (onCta != null)
              FilledButton(
                onPressed: onCta,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: EosColors.plum,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.eos.spacing.lg,
                    vertical: context.eos.spacing.sm,
                  ),
                ),
                child: Text(ctaLabel),
              ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}
