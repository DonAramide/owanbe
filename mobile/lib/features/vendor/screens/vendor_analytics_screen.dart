import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

class VendorAnalyticsScreen extends ConsumerWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(vendorAnalyticsProvider);
    final profile = ref.watch(vendorProfileProvider);

    return EosPageScaffold(
      title: 'Vendor analytics',
      subtitle: '${profile.businessName} · performance insights',
      body: analytics.when(
        data: (snap) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                SizedBox(
                  width: 220,
                  child: EosKpiCard(
                    title: 'Revenue',
                    value: formatVendorMoney(snap.revenueMinor),
                    icon: Icons.payments_outlined,
                    trend: const EosTrendBadge(deltaPercent: 8.2),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: EosKpiCard(
                    title: 'Orders',
                    value: '${snap.ordersCount}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: EosKpiCard(
                    title: 'Fulfillment rate',
                    value: '${(snap.fulfillmentRate * 100).toStringAsFixed(0)}%',
                    icon: Icons.check_circle_outline,
                    attention: snap.fulfillmentRate >= 0.8 ? EosKpiAttention.info : EosKpiAttention.warning,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: EosKpiCard(
                    title: 'Avg order',
                    value: formatVendorMoney(snap.avgOrderMinor),
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.eos.spacing.xl),
            EosSection(
              title: 'Revenue trend (7 days)',
              child: EosSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EosSparkline(values: snap.revenueTrend, height: 56),
                    SizedBox(height: context.eos.spacing.sm),
                    EosChartLegend(
                      items: [
                        EosLegendItem(label: 'Cumulative revenue', color: context.eosColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            EosSection(
              title: 'Orders by event',
              child: snap.ordersByEvent.isEmpty
                  ? EosSurfaceCard(child: Text('No event breakdown yet', style: context.eosText.bodyMedium))
                  : Column(
                      children: [
                        for (final entry in snap.ordersByEvent.entries)
                          Padding(
                            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                            child: EosSurfaceCard(
                              child: Row(
                                children: [
                                  Expanded(child: Text(entry.key, style: context.eosText.titleSmall)),
                                  Text('${entry.value} orders', style: context.eosText.bodySmall),
                                  SizedBox(width: context.eos.spacing.md),
                                  SizedBox(
                                    width: 120,
                                    child: LinearProgressIndicator(
                                      value: entry.value / snap.ordersCount,
                                      backgroundColor: context.eosColors.outlineVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}
