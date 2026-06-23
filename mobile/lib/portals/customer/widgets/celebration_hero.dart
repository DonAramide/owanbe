import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Full-width hero for customer home and event headers.
class CelebrationHero extends StatelessWidget {
  const CelebrationHero({
    super.key,
    this.imageUrl,
    this.title,
    this.subtitle,
    this.countdownLabel,
    this.onTap,
    this.height,
  });

  final String? imageUrl;
  final String? title;
  final String? subtitle;
  final String? countdownLabel;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final heroHeight = height ?? (EosResponsive.isMobile(context) ? 200.0 : 260.0);

    return ClipRRect(
      borderRadius: EosRadius.card,
      child: SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  Image.network(imageUrl!, fit: BoxFit.cover)
                else
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [EosColors.plumDark, EosColors.plum, EosColors.plumLight],
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(context.eos.spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (countdownLabel != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.eos.spacing.sm,
                            vertical: context.eos.spacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: EosColors.champagne.withValues(alpha: 0.9),
                            borderRadius: EosRadius.chip,
                          ),
                          child: Text(
                            countdownLabel!,
                            style: context.eosText.labelSmall?.copyWith(
                              color: EosColors.plumDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (countdownLabel != null) SizedBox(height: context.eos.spacing.sm),
                      if (title != null)
                        Text(
                          title!,
                          style: context.eosText.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (subtitle != null) ...[
                        SizedBox(height: context.eos.spacing.xxs),
                        Text(
                          subtitle!,
                          style: context.eosText.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
