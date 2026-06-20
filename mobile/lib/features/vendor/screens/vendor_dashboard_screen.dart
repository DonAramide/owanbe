import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vendorProfileProvider);
    final stats = ref.watch(vendorDashboardStatsProvider);
    final orders = ref.watch(vendorOrdersProvider);
    final participations = ref.watch(vendorParticipationsProvider);

    return EosPageScaffold(
      title: 'Merchant dashboard',
      subtitle: profile.businessName,
      body: stats.when(
        data: (s) => _buildBody(context, ref, profile, s, orders, participations),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    VendorProfile profile,
    VendorDashboardStats stats,
    AsyncValue<List<VendorOrder>> orders,
    AsyncValue<List<VendorEventParticipation>> participations,
  ) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stats.pendingPayoutsMinor > 0)
            EosAttentionBanner(
              headline: 'Pending payout in progress',
              message: '${formatVendorMoney(stats.pendingPayoutsMinor)} is awaiting transfer to your bank.',
              severity: 'WARNING',
              actionLabel: 'View payouts',
              onAction: () => ref.read(vendorShellTabProvider.notifier).select(5),
            ),
          EosSurfaceCard(
            elevated: true,
            onTap: () => ref.read(vendorShellTabProvider.notifier).select(4),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(context.eos.spacing.lg),
              decoration: BoxDecoration(
                borderRadius: context.eos.radius.card,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [EosColors.plumDark, EosColors.plum],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wallet balance', style: context.eosText.labelLarge?.copyWith(color: Colors.white70)),
                  SizedBox(height: context.eos.spacing.xs),
                  VendorMoneyText(minor: stats.walletBalanceMinor, color: Colors.white),
                  if (stats.pendingSettlementMinor > 0) ...[
                    SizedBox(height: context.eos.spacing.sm),
                    Text(
                      '${formatVendorMoney(stats.pendingSettlementMinor)} pending settlement',
                      style: context.eosText.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
          Wrap(
            spacing: context.eos.spacing.md,
            runSpacing: context.eos.spacing.md,
            children: [
              _kpi(context, 'Active events', '${stats.activeEvents}', Icons.celebration_outlined,
                  stats.activeEvents > 0 ? EosKpiAttention.info : EosKpiAttention.none),
              _kpi(context, 'Bookings', '${stats.totalBookings}', Icons.receipt_long_outlined,
                  EosKpiAttention.none),
              _kpiMoney(context, 'Revenue', stats.revenueMinor, Icons.payments_outlined),
              _kpiMoney(context, 'Pending payouts', stats.pendingPayoutsMinor, Icons.account_balance_outlined,
                  attention: stats.pendingPayoutsMinor > 0 ? EosKpiAttention.warning : EosKpiAttention.none),
              _kpi(
                context,
                'Customer rating',
                stats.customerRating.toStringAsFixed(1),
                Icons.star_outline,
                EosKpiAttention.none,
                subtitle: '${profile.completedEvents} events',
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.xl),
          EosSection(
            title: 'Recent bookings',
            trailing: TextButton(
              onPressed: () => ref.read(vendorShellTabProvider.notifier).select(3),
              child: const Text('All orders'),
            ),
            child: orders.when(
              data: (list) {
                final recent = list.take(3).toList();
                if (recent.isEmpty) {
                  return EosSurfaceCard(child: Text('No bookings yet', style: context.eosText.bodyMedium));
                }
                return Column(
                  children: [
                    for (final o in recent)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                        child: VendorOrderCard(order: o),
                      ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
          EosSection(
            title: 'Participation',
            trailing: TextButton(
              onPressed: () => ref.read(vendorShellTabProvider.notifier).select(1),
              child: const Text('Lifecycle'),
            ),
            child: participations.when(
              data: (list) {
                final approved = list
                    .where((p) => p.lifecycleStage == ParticipationLifecycle.approved)
                    .take(2)
                    .toList();
                if (approved.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('Browse invited events to grow your calendar', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: [
                    for (final p in approved)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                        child: VendorParticipationCard(participation: p),
                      ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    EosKpiAttention attention, {
    String? subtitle,
  }) {
    return SizedBox(
      width: 200,
      child: EosKpiCard(
        title: title,
        value: value,
        subtitle: subtitle,
        icon: icon,
        attention: attention,
      ),
    );
  }

  Widget _kpiMoney(
    BuildContext context,
    String title,
    int minor,
    IconData icon, {
    EosKpiAttention attention = EosKpiAttention.none,
  }) {
    return SizedBox(
      width: 200,
      child: EosKpiCard(
        title: title,
        value: formatVendorMoney(minor),
        icon: icon,
        attention: attention,
      ),
    );
  }
}
