import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/home_hub_models.dart';

/// Horizontal celebration card for an active owned event.
class HomeActiveEventCard extends StatelessWidget {
  const HomeActiveEventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  final CustomerEventSummary event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progressPct = (event.progress * 100).round();

    return SizedBox(
      width: EosResponsive.isMobile(context) ? 280 : 320,
      child: EosSurfaceCard(
        onTap: onTap,
        elevated: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: EosRadius.input,
                gradient: LinearGradient(
                  colors: [
                    Color(event.coverGradientStart),
                    Color(event.coverGradientEnd),
                  ],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: EdgeInsets.all(context.eos.spacing.sm),
              child: Row(
                children: [
                  if (event.isLive) const EosLiveIndicator(compact: true),
                  if (event.isLive) SizedBox(width: context.eos.spacing.xs),
                  Expanded(
                    child: Text(
                      event.title,
                      style: context.eosText.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.eos.spacing.sm),
            Text(formatEventDate(event.startsAt), style: context.eosText.labelSmall),
            SizedBox(height: context.eos.spacing.xxs),
            Text(
              '${event.city} · ${event.venue}',
              style: context.eosText.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: context.eos.spacing.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: EosRadius.chip,
                    child: LinearProgressIndicator(
                      value: event.progress,
                      minHeight: 6,
                      backgroundColor: context.eosColors.surfaceContainerHighest,
                      color: context.eosColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: context.eos.spacing.sm),
                Text('$progressPct%', style: context.eosText.labelSmall),
              ],
            ),
            SizedBox(height: context.eos.spacing.xs),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 14, color: context.eosColors.onSurfaceVariant),
                SizedBox(width: context.eos.spacing.xxs),
                Expanded(
                  child: Text(
                    '${event.guestCount} guest${event.guestCount == 1 ? '' : 's'}',
                    style: context.eosText.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
