import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../widgets/alerts/alert_banner.dart';
import '../../../widgets/cards/kpi_card.dart';
import 'admin_finance_providers.dart';

class AdminFinanceDashboardScreen extends ConsumerWidget {
  const AdminFinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminSummaryProvider);
    final alerts = ref.watch(adminAlertsProvider);
    final resolvedTypes = ref.watch(resolvedAlertTypesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        summary.when(
          data: (s) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: 250, child: KpiCard(title: 'Total Volume', value: ngnFromMinor(s.totalVolumeMinor))),
              SizedBox(width: 250, child: KpiCard(title: 'Escrow Balance', value: ngnFromMinor(s.escrowBalanceMinor))),
              SizedBox(width: 250, child: KpiCard(title: 'Pending Payouts', value: ngnFromMinor(s.pendingPayoutMinor))),
              SizedBox(
                width: 250,
                child: KpiCard(
                  title: 'Under Review',
                  value: ngnFromMinor(s.underReviewMinor),
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(
                width: 250,
                child: KpiCard(
                  title: 'Failed Transactions',
                  value: '${s.failedCount} (${ngnFromMinor(s.failedMinor)})',
                  color: Colors.red,
                ),
              ),
            ],
          ),
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, st) => _ErrorCard(message: e.toString(), onRetry: () => ref.invalidate(adminSummaryProvider)),
        ),
        const SizedBox(height: 16),
        Text('Alerts / Issues', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        alerts.when(
          data: (items) {
            final visible = items
                .where((a) => !resolvedTypes.contains(a.type))
                .toList()
              ..sort((a, b) {
                final sa = _severityWeight(a.severity);
                final sb = _severityWeight(b.severity);
                if (sa != sb) return sb.compareTo(sa);
                return b.latestOccurrence.compareTo(a.latestOccurrence);
              });
            if (visible.isEmpty) {
              return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No active alerts')));
            }
            return Column(
              children: visible.take(8).map((a) {
                return AlertBanner(
                  severity: a.severity,
                  message:
                      '${a.type.replaceAll('_', ' ')} • ${a.count} items • ${a.latestOccurrence.toIso8601String()}',
                  onAction: () => _viewAlertDetails(context, a),
                  onResolve: () {
                    ref.read(resolvedAlertTypesProvider.notifier).state = {
                      ...ref.read(resolvedAlertTypesProvider),
                      a.type,
                    };
                  },
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          error: (e, st) => _ErrorCard(message: e.toString(), onRetry: () => ref.invalidate(adminAlertsProvider)),
        ),
      ],
    );
  }

  int _severityWeight(String s) => switch (s.toUpperCase()) {
        'CRITICAL' => 3,
        'WARNING' => 2,
        _ => 1,
      };

  Future<void> _viewAlertDetails(BuildContext context, dynamic alert) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Alert: ${alert.type}'),
        content: Text(
          'Severity: ${alert.severity}\nCount: ${alert.count}\nLatest: ${alert.latestOccurrence.toIso8601String()}',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(message),
        trailing: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}
