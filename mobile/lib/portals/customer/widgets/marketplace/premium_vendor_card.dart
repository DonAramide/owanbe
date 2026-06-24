import 'package:flutter/material.dart';

import '../../../../core/api/vendors_api.dart';
import '../../../../eos/eos.dart';
import '../../models/marketplace_models.dart';
import 'verified_vendor_badge.dart';

class PremiumVendorCard extends StatelessWidget {
  const PremiumVendorCard({
    super.key,
    required this.vendor,
    this.onTap,
    this.coverColorStart = 0xFF4B2C6F,
    this.coverColorEnd = 0xFFD4A853,
    this.priceLabel,
    this.guestCount = 150,
    this.onPlayVideo,
  });

  final MarketplaceVendor vendor;
  final VoidCallback? onTap;
  final int coverColorStart;
  final int coverColorEnd;
  final String? priceLabel;
  final int guestCount;
  final VoidCallback? onPlayVideo;

  @override
  Widget build(BuildContext context) {
    final rating = vendor.ratingAverage;
    final imageUrl = vendor.imageUrl ?? vendorCoverImageUrl(vendor);
    final perGuest = formatVendorPricePerGuest(vendor, guestCount);
    final hasVideo = vendorPreviewVideoUrl(vendor) != null;

    return EosSurfaceCard(
      onTap: onTap,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: EosRadius.input,
            child: Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(coverColorStart), Color(coverColorEnd)],
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: EdgeInsets.all(context.eos.spacing.sm),
                      child: Text(
                        vendor.categoryLabel,
                        style: context.eosText.labelSmall?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasVideo)
                        _MediaChip(
                          icon: Icons.play_circle_outline,
                          label: 'Video',
                          onTap: onPlayVideo ?? onTap,
                        ),
                      if (hasVideo) const SizedBox(width: 4),
                      if (vendor.isVerified) const VerifiedVendorBadge(compact: true),
                    ],
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  right: 8,
                  child: Text(
                    vendor.businessName,
                    style: context.eosText.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                if (vendor.reviewCount != null)
                  Text(' · ${vendor.reviewCount} reviews', style: context.eosText.bodySmall),
              ],
            ],
          ),
          SizedBox(height: context.eos.spacing.xxs),
          Text(vendor.categoryLabel, style: context.eosText.labelSmall),
          if (priceLabel != null) ...[
            SizedBox(height: context.eos.spacing.xxs),
            Text(priceLabel!, style: context.eosText.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
          if (perGuest.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.xxs),
            Text(perGuest, style: context.eosText.bodySmall),
          ],
          if (vendor.city != null) ...[
            SizedBox(height: context.eos.spacing.xxs),
            Text(vendor.city!, style: context.eosText.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _MediaChip extends StatelessWidget {
  const _MediaChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
