import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/home_hub_models.dart';

/// Welcome hero with greeting, avatar, and nearest-event countdown.
class HomeWelcomeHero extends StatelessWidget {
  const HomeWelcomeHero({
    super.key,
    required this.displayName,
    this.nearestEvent,
  });

  final String displayName;
  final CustomerEventSummary? nearestEvent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstName = displayName.trim().isEmpty
        ? 'there'
        : displayName.trim().split(RegExp(r'\s+')).first;
    final countdown = nearestEvent != null ? formatCountdown(nearestEvent!.startsAt, now) : null;

    return Container(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EosColors.plumDark, EosColors.plum, EosColors.plumLight],
        ),
        borderRadius: EosRadius.card,
        boxShadow: context.eos.shadowElevated,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: EosColors.champagne,
            child: Text(
              firstName.isNotEmpty ? firstName[0].toUpperCase() : 'O',
              style: context.eosText.titleLarge?.copyWith(
                color: EosColors.plumDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${homeGreeting(now)}, $firstName',
                  style: context.eosText.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: context.eos.spacing.xxs),
                Text(
                  'Plan. Invite. Celebrate.',
                  style: context.eosText.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (countdown != null) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.eos.spacing.sm,
                      vertical: context.eos.spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: EosColors.champagne.withValues(alpha: 0.92),
                      borderRadius: EosRadius.chip,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 14, color: EosColors.plumDark),
                        SizedBox(width: context.eos.spacing.xxs),
                        Flexible(
                          child: Text(
                            nearestEvent!.isLive
                                ? 'Live now · ${nearestEvent!.title}'
                                : '$countdown · ${nearestEvent!.title}',
                            style: context.eosText.labelSmall?.copyWith(
                              color: EosColors.plumDark,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
