import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

class VendorWalletScreen extends ConsumerWidget {
  const VendorWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(vendorWalletProvider);
    final entries = ref.watch(vendorWalletEntriesProvider);
    final stats = ref.watch(vendorDashboardStatsProvider);

    return EosPageScaffold(
      title: 'Wallet',
      subtitle: 'Balances and transaction history',
      actions: [
        OutlinedButton(
          onPressed: () => ref.read(vendorShellTabProvider.notifier).select(5),
          child: const Text('Request payout'),
        ),
      ],
      body: stats.when(
        data: (statsData) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            wallet.when(
            data: (snap) => Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                SizedBox(
                  width: 240,
                  child: EosKpiCard(
                    title: 'Available balance',
                    value: formatVendorMoney(snap.availableMinor),
                    icon: Icons.account_balance_wallet_outlined,
                    attention: EosKpiAttention.info,
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: EosKpiCard(
                    title: 'Pending settlement',
                    value: formatVendorMoney(snap.pendingMinor),
                    subtitle: 'Clearing to available',
                    icon: Icons.hourglass_empty,
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: EosKpiCard(
                    title: 'Lifetime revenue',
                    value: formatVendorMoney(snap.totalEarnedMinor),
                    icon: Icons.trending_up,
                  ),
                ),
                if (snap.underReviewMinor > 0)
                  SizedBox(
                    width: 240,
                    child: EosKpiCard(
                      title: 'Under review',
                      value: formatVendorMoney(snap.underReviewMinor),
                      attention: EosKpiAttention.warning,
                      icon: Icons.fact_check_outlined,
                    ),
                  ),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          if (statsData.pendingPayoutsMinor > 0) ...[
            SizedBox(height: context.eos.spacing.md),
            EosAttentionBanner(
              headline: 'Pending payouts',
              message: '${formatVendorMoney(statsData.pendingPayoutsMinor)} in payout requests processing.',
              severity: 'WARNING',
              actionLabel: 'View payouts',
              onAction: () => ref.read(vendorShellTabProvider.notifier).select(5),
            ),
          ],
          if (wallet.valueOrNull != null && wallet.value!.underReviewMinor > 0) ...[
            SizedBox(height: context.eos.spacing.md),
            EosAttentionBanner(
              headline: 'Funds under review',
              message: 'Some earnings are being verified before they become available for payout.',
              severity: 'INFO',
            ),
          ],
          SizedBox(height: context.eos.spacing.xl),
          EosSection(
            title: 'Activity',
            subtitle: 'Recent wallet movements',
            child: entries.when(
              data: (list) {
                if (list.isEmpty) {
                  return EosSurfaceCard(child: Text('No activity yet', style: context.eosText.bodyMedium));
                }
                return Column(
                  children: [
                    for (final e in list)
                      EosFeedItem(
                        title: e.label,
                        subtitle: '${_typeLabel(e.type)} · ${e.reference}',
                        timestamp: _relative(e.timestamp),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: context.eosColors.primaryContainer,
                          child: Icon(_iconFor(e.type), size: 18, color: context.eosColors.primary),
                        ),
                        trailing: VendorMoneyText(
                          minor: e.amountMinor.abs(),
                          compact: true,
                          color: e.amountMinor >= 0 ? EosColors.success : EosColors.critical,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => Text('$err'),
            ),
          ),
        ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  String _typeLabel(VendorWalletEntryType type) => switch (type) {
        VendorWalletEntryType.earning => 'Earning',
        VendorWalletEntryType.refund => 'Refund',
        VendorWalletEntryType.payout => 'Payout',
        VendorWalletEntryType.adjustment => 'Adjustment',
      };

  IconData _iconFor(VendorWalletEntryType type) => switch (type) {
        VendorWalletEntryType.payout => Icons.payments_outlined,
        VendorWalletEntryType.refund => Icons.undo,
        _ => Icons.attach_money,
      };

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
