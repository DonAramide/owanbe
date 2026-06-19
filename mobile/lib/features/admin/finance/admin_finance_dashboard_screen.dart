import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../widgets/alerts/alert_banner.dart';
import 'admin_finance_models.dart';
import 'admin_finance_providers.dart';
import 'finance_attention_copy.dart';

class AdminFinanceDashboardScreen extends ConsumerWidget {
  const AdminFinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminSummaryProvider);
    final alerts = ref.watch(adminAlertsProvider);
    final resolvedTypes = ref.watch(resolvedAlertTypesProvider);
    return EosPageScaffold(
      title: 'Finance overview',
      subtitle: 'Amounts plus why each area needs attention',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary.when(
            data: (s) => _KpiGrid(summary: s, onNavigate: (action) => _handleKpiAction(ref, action)),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, st) => _ErrorCard(message: e.toString(), onRetry: () => ref.invalidate(adminSummaryProvider)),
          ),
          EosSection(
            title: 'Alerts / Issues',
            child: alerts.when(
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
                  headline: a.headline,
                  message: a.summary.isNotEmpty
                      ? a.summary
                      : '${a.count} items need attention',
                  onAction: () => _viewAlertDetails(context, ref, a),
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
          ),
        ],
      ),
    );
  }

  void _handleKpiAction(WidgetRef ref, _KpiNavAction action) {
    switch (action) {
      case _KpiNavAction.payoutsPending:
        ref.read(payoutQueryProvider.notifier).setStatus('processing');
        ref.read(adminShellTabProvider.notifier).select(2);
      case _KpiNavAction.underReview:
        ref.read(adminShellTabProvider.notifier).select(3);
      case _KpiNavAction.failed:
        ref.read(payoutQueryProvider.notifier).setStatus('failed');
        ref.read(adminShellTabProvider.notifier).select(2);
      case _KpiNavAction.reconciliation:
        ref.read(reconQueryProvider.notifier).setStatus('open');
        ref.read(adminShellTabProvider.notifier).select(4);
      case _KpiNavAction.transactions:
        ref.read(adminShellTabProvider.notifier).select(1);
    }
  }

  int _severityWeight(String s) => switch (s.toUpperCase()) {
        'CRITICAL' => 3,
        'WARNING' => 2,
        _ => 1,
      };

  Future<void> _viewAlertDetails(BuildContext context, WidgetRef ref, AdminAlertItem alert) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(alert.headline),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.summary),
            const SizedBox(height: 12),
            Text('Severity: ${alert.severity}'),
            Text('Count: ${alert.count}'),
            Text('Latest: ${alert.latestOccurrence.toLocal()}'),
            if (alert.suggestedAction != null) ...[
              const SizedBox(height: 12),
              Text(alert.suggestedAction!, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openAlertTab(ref, alert.type);
            },
            child: const Text('Open queue'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _openAlertTab(WidgetRef ref, String type) {
    switch (type) {
      case 'reconciliation_issue':
        ref.read(reconQueryProvider.notifier).setStatus('open');
        ref.read(adminShellTabProvider.notifier).select(4);
      case 'payout_failure':
        ref.read(payoutQueryProvider.notifier).setStatus('failed');
        ref.read(adminShellTabProvider.notifier).select(2);
      case 'payment_under_review':
        ref.read(adminShellTabProvider.notifier).select(3);
      default:
        ref.read(adminShellTabProvider.notifier).select(0);
    }
  }
}

enum _KpiNavAction { payoutsPending, underReview, failed, reconciliation, transactions }

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary, required this.onNavigate});

  final AdminFinanceSummary summary;
  final void Function(_KpiNavAction action) onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final att = s.attention;
    final openRecon = int.tryParse(s.openReconciliationCount) ?? 0;
    final pendingCount = int.tryParse(s.pendingPayoutCount) ?? 0;
    final failedCount = int.tryParse(s.failedCount) ?? 0;
    final underReviewParts = s.underReviewCount.split('/');
    final reviewTotal =
        (int.tryParse(underReviewParts.elementAtOrNull(0) ?? '0') ?? 0) +
        (int.tryParse(underReviewParts.elementAtOrNull(1) ?? '0') ?? 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = EosResponsive.columnsFor(context).clamp(1, 3);
        final width = (constraints.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: width.clamp(260, 360), child: _volumeCard(s, att)),
            SizedBox(width: width.clamp(260, 360), child: _escrowCard(s, att)),
            SizedBox(width: width.clamp(260, 360), child: _pendingCard(s, att, pendingCount)),
            SizedBox(width: width.clamp(260, 360), child: _reviewCard(s, att, reviewTotal)),
            SizedBox(width: width.clamp(260, 360), child: _failedCard(s, att, failedCount)),
            if (openRecon > 0)
              SizedBox(width: width.clamp(260, 360), child: _reconCard(att, openRecon)),
          ],
        );
      },
    );
  }

  Widget _volumeCard(AdminFinanceSummary s, AdminFinanceSummaryAttention att) => EosKpiCard(
        title: 'Total Volume',
        value: ngnFromMinor(s.totalVolumeMinor),
        subtitle: att.volume.detail,
        icon: Icons.trending_up,
      );

  Widget _escrowCard(AdminFinanceSummary s, AdminFinanceSummaryAttention att) => EosKpiCard(
        title: 'Escrow Balance',
        value: ngnFromMinor(s.escrowBalanceMinor),
        subtitle: att.escrow.detail,
        icon: Icons.account_balance_wallet_outlined,
      );

  Widget _pendingCard(AdminFinanceSummary s, AdminFinanceSummaryAttention att, int pendingCount) => EosKpiCard(
        title: 'Pending Payouts',
        value: '$pendingCount (${ngnFromMinor(s.pendingPayoutMinor)})',
        subtitle: pendingCount > 0 ? 'Awaiting vendor release' : att.pendingPayouts.detail,
        attentionSummary: att.pendingPayouts.summary,
        attention: attentionLevelFromString(att.pendingPayouts.level) == FinanceAttentionLevel.warning
            ? EosKpiAttention.warning
            : attentionLevelFromString(att.pendingPayouts.level) == FinanceAttentionLevel.info
                ? EosKpiAttention.info
                : EosKpiAttention.none,
        icon: Icons.payments_outlined,
        actionLabel: pendingCount > 0 ? 'View payouts →' : null,
        onTap: pendingCount > 0 ? () => onNavigate(_KpiNavAction.payoutsPending) : null,
      );

  Widget _reviewCard(AdminFinanceSummary s, AdminFinanceSummaryAttention att, int reviewTotal) => EosKpiCard(
        title: 'Under Review',
        value: '$reviewTotal (${ngnFromMinor(s.underReviewMinor)})',
        subtitle: reviewTotal > 0 ? 'Blocked from automation' : att.underReview.detail,
        attentionSummary: att.underReview.summary,
        attention: _eosAttention(att.underReview.level),
        icon: Icons.fact_check_outlined,
        actionLabel: reviewTotal > 0 ? 'Open review queue →' : null,
        onTap: reviewTotal > 0 ? () => onNavigate(_KpiNavAction.underReview) : null,
      );

  Widget _failedCard(AdminFinanceSummary s, AdminFinanceSummaryAttention att, int failedCount) => EosKpiCard(
        title: 'Failed Transactions',
        value: '$failedCount (${ngnFromMinor(s.failedMinor)})',
        subtitle: failedCount > 0 ? 'Needs retry or investigation' : att.failed.detail,
        attentionSummary: att.failed.summary,
        attention: _eosAttention(att.failed.level),
        icon: Icons.error_outline,
        actionLabel: failedCount > 0 ? 'View failed payouts →' : null,
        onTap: failedCount > 0 ? () => onNavigate(_KpiNavAction.failed) : null,
      );

  Widget _reconCard(AdminFinanceSummaryAttention att, int openRecon) => EosKpiCard(
        title: 'Reconciliation',
        value: '$openRecon open',
        subtitle: att.reconciliation.detail,
        attentionSummary: att.reconciliation.summary,
        attention: _eosAttention(att.reconciliation.level),
        icon: Icons.rule_folder_outlined,
        actionLabel: 'Open reconciliation →',
        onTap: () => onNavigate(_KpiNavAction.reconciliation),
      );

  EosKpiAttention _eosAttention(String level) => switch (attentionLevelFromString(level)) {
        FinanceAttentionLevel.critical => EosKpiAttention.critical,
        FinanceAttentionLevel.warning => EosKpiAttention.warning,
        FinanceAttentionLevel.info => EosKpiAttention.info,
        FinanceAttentionLevel.none => EosKpiAttention.none,
      };
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
