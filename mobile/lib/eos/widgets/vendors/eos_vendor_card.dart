import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../cards/eos_surface_card.dart';
import 'eos_vendor_tier_chip.dart';

class EosVendorCard extends StatelessWidget {
  const EosVendorCard({
    super.key,
    required this.businessName,
    required this.category,
    required this.tier,
    this.rating,
    this.onTap,
  });

  final String businessName;
  final String category;
  final String tier;
  final double? rating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.eosColors.primaryContainer,
            child: Text(
              businessName.isNotEmpty ? businessName[0].toUpperCase() : 'V',
              style: context.eosText.titleSmall?.copyWith(color: context.eosColors.primary),
            ),
          ),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(businessName, style: context.eosText.titleSmall),
                Text(category, style: context.eosText.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              EosVendorTierChip(tier: tier),
              if (rating != null) ...[
                SizedBox(height: context.eos.spacing.xxs),
                Text('★ ${rating!.toStringAsFixed(1)}', style: context.eosText.labelSmall),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
