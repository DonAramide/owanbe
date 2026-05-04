import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import 'vendor_finance_models.dart';
import 'vendor_finance_providers.dart';

class VendorEarningsDashboardScreen extends ConsumerStatefulWidget {
  const VendorEarningsDashboardScreen({super.key});

  @override
  ConsumerState<VendorEarningsDashboardScreen> createState() => _VendorEarningsDashboardScreenState();
}

class _VendorEarningsDashboardScreenState extends ConsumerState<VendorEarningsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _tabs.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _ngn(String minor) {
    final n = BigInt.tryParse(minor) ?? BigInt.zero;
    final neg = n.isNegative;
    final abs = n.abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < abs.length; i++) {
      final idx = abs.length - i;
      b.write(abs[i]);
      if (idx > 1 && idx % 3 == 1) b.write(',');
    }
    return '${neg ? '-' : ''}₦$b';
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(vendorSummaryProvider);
    final txs = ref.watch(vendorTransactionsProvider);
    final withdraw = ref.watch(withdrawControllerProvider);
    final theme = Theme.of(context);

    ref.listen(withdrawControllerProvider, (prev, next) {
      if (next.lastSuccess != null && prev?.lastSuccess != next.lastSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawal queued (${next.lastSuccess!.payoutCount} payout unit(s))')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authSessionProvider.notifier).signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Transactions'), Tab(text: 'Payouts')],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vendorSummaryProvider);
          ref.invalidate(vendorTransactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summary.when(
              loading: _summarySkeleton,
              error: (e, _) => _errorCard(message: e.toString(), onRetry: () => ref.invalidate(vendorSummaryProvider)),
              data: (data) => _summarySection(data, theme, withdraw),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 420,
              child: TabBarView(
                controller: _tabs,
                children: [
                  txs.when(
                    loading: _txSkeleton,
                    error: (e, _) =>
                        _errorCard(message: e.toString(), onRetry: () => ref.invalidate(vendorTransactionsProvider)),
                    data: (d) => _txList(d.items.where((e) => e.type != 'payout').toList()),
                  ),
                  txs.when(
                    loading: _txSkeleton,
                    error: (e, _) =>
                        _errorCard(message: e.toString(), onRetry: () => ref.invalidate(vendorTransactionsProvider)),
                    data: (d) => _txList(d.items.where((e) => e.type == 'payout').toList()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summarySection(VendorSummaryResponse data, ThemeData theme, WithdrawState withdraw) {
    final t = data.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _BalanceCard(title: 'Available', value: _ngn(t.availableBalanceMinor))),
            const SizedBox(width: 12),
            Expanded(child: _BalanceCard(title: 'Pending', value: _ngn(t.pendingEarningsMinor))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _BalanceCard(title: 'Under Review', value: _ngn(t.underReviewAmountMinor))),
            const SizedBox(width: 12),
            Expanded(child: _BalanceCard(title: 'Total Earned', value: _ngn(t.totalEarningsMinor))),
          ],
        ),
        if ((BigInt.tryParse(t.underReviewAmountMinor) ?? BigInt.zero) > BigInt.zero) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Expanded(child: Text('Some funds are under review')),
                TextButton(onPressed: () {}, child: const Text('Learn more')),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Withdraw amount (minor units)',
            hintText: 'e.g. 150000',
            border: OutlineInputBorder(),
          ),
        ),
        if (withdraw.error != null) ...[
          const SizedBox(height: 8),
          Text(withdraw.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        if (withdraw.suggestionsMinor.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: withdraw.suggestionsMinor
                .map((s) => ActionChip(label: Text(_ngn(s)), onPressed: () => _amountCtrl.text = s))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: withdraw.loading
                ? null
                : () {
                    final v = _amountCtrl.text.trim();
                    if (v.isEmpty) return;
                    ref.read(withdrawControllerProvider.notifier).submit(amountMinor: v);
                  },
            child: Text(withdraw.loading ? 'Processing...' : 'Withdraw'),
          ),
        ),
      ],
    );
  }

  Widget _txList(List<VendorFinanceTransaction> items) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No transactions yet');
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final tx = items[i];
        final dt = DateTime.fromMillisecondsSinceEpoch(tx.timestampMs);
        return ListTile(
          leading: Icon(_iconForType(tx.type)),
          title: Text('${_ngn(tx.amountMinor)}  •  ${tx.bookingReference}'),
          subtitle: Text('${tx.type.toUpperCase()}  •  ${tx.reason ?? '-'}\n$dt'),
          isThreeLine: true,
          trailing: _StatusBadge(status: tx.status),
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'payout':
        return Icons.account_balance_wallet_outlined;
      case 'refund':
        return Icons.undo;
      case 'chargeback':
        return Icons.warning_amber_rounded;
      default:
        return Icons.attach_money;
    }
  }

  Widget _summarySkeleton() => const _SkeletonBox(height: 220);
  Widget _txSkeleton() => const _SkeletonBox(height: 360);

  Widget _errorCard({required String message, required VoidCallback onRetry}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final color = switch (s) {
      'pending' || 'processing' => Colors.orange,
      'completed' => Colors.green,
      'failed' => Colors.red,
      'under_review' => Colors.deepPurple,
      _ => Colors.grey,
    };
    final label = switch (s) {
      'processing' => 'Pending',
      'under_review' => 'Under Review',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
