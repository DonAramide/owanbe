import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/home_hub_models.dart';

/// Prominent banner for the nearest upcoming or live event.
class HomeUpcomingEventBanner extends StatelessWidget {
  const HomeUpcomingEventBanner({
    super.key,
    required this.event,
    this.onTap,
  });

  final CustomerEventSummary event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final countdown = formatCountdown(event.startsAt, now);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: EosRadius.card,
        child: Ink(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          decoration: BoxDecoration(
            borderRadius: EosRadius.card,
            gradient: LinearGradient(
              colors: [
                Color(event.coverGradientStart),
                Color(event.coverGradientEnd),
              ],
            ),
            boxShadow: context.eos.shadowElevated,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (event.isLive) const EosLiveIndicator(compact: true),
                        if (event.isLive) SizedBox(width: context.eos.spacing.xs),
                        Text(
                          event.isLive ? 'Live celebration' : 'Up next',
                          style: context.eosText.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.eos.spacing.xs),
                    Text(
                      event.title,
                      style: context.eosText.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.eos.spacing.xxs),
                    Text(
                      '$countdown · ${formatEventDate(event.startsAt)}',
                      style: context.eosText.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white.withValues(alpha: 0.9)),
            ],
          ),
        ),
      ),
    );
  }
}
