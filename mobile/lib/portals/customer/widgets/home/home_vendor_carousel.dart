import 'package:flutter/material.dart';

import '../../../../core/api/vendors_api.dart';
import '../../../../eos/eos.dart';
import '../../models/marketplace_models.dart';
import '../marketplace/premium_vendor_card.dart';

/// Horizontal vendor discovery carousel for the home hub.
class HomeVendorCarousel extends StatelessWidget {
  const HomeVendorCarousel({
    super.key,
    required this.vendors,
    this.onVendorTap,
  });

  final List<MarketplaceVendor> vendors;
  final ValueChanged<MarketplaceVendor>? onVendorTap;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return EosSurfaceCard(
        child: Text(
          'Vendors will appear here as the marketplace grows.',
          style: context.eosText.bodyMedium,
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vendors.length,
        separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.md),
        itemBuilder: (context, index) {
          final vendor = vendors[index];
          final profile = buildVendorProfile(vendor);
          return SizedBox(
            width: EosResponsive.isMobile(context) ? 280 : 300,
            child: PremiumVendorCard(
              vendor: profile.vendor,
              coverColorStart: profile.coverColorStart,
              coverColorEnd: profile.coverColorEnd,
              onTap: onVendorTap != null ? () => onVendorTap!(vendor) : null,
            ),
          );
        },
      ),
    );
  }
}
