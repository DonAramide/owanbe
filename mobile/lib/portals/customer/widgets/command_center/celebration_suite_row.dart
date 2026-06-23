import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

class CelebrationSuiteCard extends StatelessWidget {
  const CelebrationSuiteCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.eosColors.primary),
          SizedBox(height: context.eos.spacing.sm),
          Text(title, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: context.eos.spacing.xxs),
          Text(subtitle, style: context.eosText.bodySmall),
        ],
      ),
    );
  }
}

class CelebrationSuiteRow extends StatelessWidget {
  const CelebrationSuiteRow({
    super.key,
    required this.onWebsite,
    required this.onAsoEbi,
    required this.onWall,
    required this.onRegistry,
  });

  final VoidCallback onWebsite;
  final VoidCallback onAsoEbi;
  final VoidCallback onWall;
  final VoidCallback onRegistry;

  @override
  Widget build(BuildContext context) {
    final cardWidth = EosResponsive.isMobile(context) ? 160.0 : 180.0;

    return SizedBox(
      height: 132,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: cardWidth,
            child: CelebrationSuiteCard(
              title: 'Website',
              subtitle: 'Your celebration microsite',
              icon: Icons.language_outlined,
              onTap: onWebsite,
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          SizedBox(
            width: cardWidth,
            child: CelebrationSuiteCard(
              title: 'Aso-Ebi',
              subtitle: 'Fabric & reservations',
              icon: Icons.checkroom_outlined,
              onTap: onAsoEbi,
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          SizedBox(
            width: cardWidth,
            child: CelebrationSuiteCard(
              title: 'Wall',
              subtitle: 'Celebration messages',
              icon: Icons.forum_outlined,
              onTap: onWall,
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          SizedBox(
            width: cardWidth,
            child: CelebrationSuiteCard(
              title: 'Registry',
              subtitle: 'Gifts & contributions',
              icon: Icons.card_giftcard_outlined,
              onTap: onRegistry,
            ),
          ),
        ],
      ),
    );
  }
}
