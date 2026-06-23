import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../models/ai_planner_models.dart';
import '../../router/customer_routes.dart';

class PlannerRecommendedVendors extends StatelessWidget {
  const PlannerRecommendedVendors({
    super.key,
    required this.vendors,
  });

  final List<PlannerRecommendedVendor> vendors;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return EosSurfaceCard(
        child: Text(
          'No vendor matches yet. Browse the marketplace to find partners.',
          style: context.eosText.bodyMedium,
        ),
      );
    }

    return Column(
      children: [
        for (final item in vendors)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              elevated: true,
              onTap: () => context.push(CustomerRoutes.vendorDetail(item.vendor.id)),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: EosRadius.input,
                      gradient: LinearGradient(
                        colors: [Color(item.coverColorStart), Color(item.coverColorEnd)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.matchScore}%',
                      style: context.eosText.labelSmall?.copyWith(
                        color: Colors.white,
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
                          item.vendor.businessName,
                          style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.vendor.categoryLabel,
                          style: context.eosText.labelSmall?.copyWith(
                            color: context.eosColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          item.reason,
                          style: context.eosText.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.vendor.priceFromMinor != null)
                          Text(
                            'From ${formatRevenue(item.vendor.priceFromMinor!)}',
                            style: context.eosText.labelSmall?.copyWith(
                              color: context.eosColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
