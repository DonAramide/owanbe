import 'package:flutter/material.dart';

import '../../../../core/api/vendors_api.dart';
import '../../../../eos/eos.dart';
import 'verified_vendor_badge.dart';

class PremiumVendorCard extends StatelessWidget {
  const PremiumVendorCard({
    super.key,
    required this.vendor,
    this.onTap,
    this.coverColorStart = 0xFF4B2C6F,
    this.coverColorEnd = 0xFFD4A853,
  });

  final MarketplaceVendor vendor;
  final VoidCallback? onTap;
  final int coverColorStart;
  final int coverColorEnd;

  @override
  Widget build(BuildContext context) {
    final rating = vendor.ratingAverage;

    return EosSurfaceCard(
      onTap: onTap,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 88,
            decoration: BoxDecoration(
              borderRadius: EosRadius.input,
              gradient: LinearGradient(
                colors: [Color(coverColorStart), Color(coverColorEnd)],
              ),
            ),
            padding: EdgeInsets.all(context.eos.spacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        vendor.businessName,
                        style: context.eosText.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        vendor.categoryLabel,
                        style: context.eosText.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (vendor.isVerified) const VerifiedVendorBadge(compact: true),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              if (rating != null) ...[
                Icon(Icons.star_rounded, size: 18, color: EosColors.champagne),
                SizedBox(width: context.eos.spacing.xxs),
                Text(
                  rating.toStringAsFixed(1),
                  style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (vendor.reviewCount != null) ...[
                  Text(' · ${vendor.reviewCount} reviews', style: context.eosText.bodySmall),
                ],
              ],
              const Spacer(),
              if (vendor.city != null)
                Text(vendor.city!, style: context.eosText.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
