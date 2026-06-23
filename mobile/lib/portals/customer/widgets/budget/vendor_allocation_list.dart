import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../../../features/organizer/models/organizer_models.dart';
import '../../models/budget_dashboard_models.dart';

class VendorAllocationList extends StatelessWidget {
  const VendorAllocationList({super.key, required this.vendors});

  final List<VendorBudgetAllocation> vendors;

  Color _statusColor(VendorSlotStatus status) => switch (status) {
        VendorSlotStatus.approved => EosColors.success,
        VendorSlotStatus.pending || VendorSlotStatus.invited => EosColors.warning,
        VendorSlotStatus.rejected || VendorSlotStatus.suspended => EosColors.critical,
      };

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return EosSurfaceCard(
        child: Text(
          'No vendor allocations yet. Invite vendors from the command center.',
          style: context.eosText.bodyMedium,
        ),
      );
    }

    return Column(
      children: [
        for (final vendor in vendors)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: context.eosColors.primaryContainer,
                    child: Icon(Icons.storefront_outlined, color: context.eosColors.primary, size: 20),
                  ),
                  SizedBox(width: context.eos.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.businessName,
                          style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: context.eos.spacing.xxs),
                        Text(vendor.category.label, style: context.eosText.bodySmall),
                        SizedBox(height: context.eos.spacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Allocated', style: context.eosText.labelSmall),
                                  Text(
                                    formatRevenue(vendor.allocatedMinor),
                                    style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Committed', style: context.eosText.labelSmall),
                                  Text(
                                    formatRevenue(vendor.committedMinor),
                                    style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.eos.spacing.sm,
                      vertical: context.eos.spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(vendor.status).withValues(alpha: 0.12),
                      borderRadius: EosRadius.chip,
                    ),
                    child: Text(
                      vendorSlotStatusLabel(vendor.status),
                      style: context.eosText.labelSmall?.copyWith(
                        color: _statusColor(vendor.status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
