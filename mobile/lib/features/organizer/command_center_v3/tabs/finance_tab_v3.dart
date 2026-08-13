import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/auth_notifier.dart';
import '../../../../core/utils/export_helper.dart';
import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../finance/organizer_finance_api.dart';
import '../../finance/organizer_finance_providers.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_finance_charts.dart';
import '../widgets/cc_v3_health_cards.dart';

class FinanceTabV3 extends ConsumerWidget {
  const FinanceTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final summary = ref.watch(organizerEventFinanceSummaryProvider(eventId));
    final txs = ref.watch(organizerEventFinanceTransactionsProvider(eventId));
    final refunds = ref.watch(organizerEventFinanceRefundsProvider(eventId));
    final payouts = ref.watch(organizerEventFinancePayoutsProvider(eventId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(eventCommandCenterV3Provider(eventId));
        invalidateEventFinance(ref, eventId);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Event financial operations', style: context.eosText.headlineSmall),
            ),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Gross, fees, net, escrow, refunds, and payouts from ticket commerce.',
              style: context.eosText.bodySmall,
            ),
            SizedBox(height: context.eos.spacing.lg),
            summary.when(
              loading: () => const _FinanceSkeleton(),
              error: (e, _) => EosAttentionBanner(
                headline: 'Finance summary unavailable',
                message: '$e',
                severity: 'WARNING',
                actionLabel: 'Retry',
                onAction: () => invalidateEventFinance(ref, eventId),
              ),
              data: (fin) => _FinancialSummarySection(fin: fin, eventId: eventId),
            ),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(
              title: 'Refunds',
              subtitle: 'Request status · approve · decline · complete',
            ),
            refunds.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text('$e', style: context.eosText.bodySmall),
              data: (items) => _RefundsSection(eventId: eventId, items: items),
            ),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(
              title: 'Payouts & escrow',
              subtitle: 'Pending · scheduled · paid · failed — honest status only',
            ),
            payouts.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text('$e', style: context.eosText.bodySmall),
              data: (items) => summary.when(
                data: (fin) => _PayoutsSection(eventId: eventId, fin: fin, items: items),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => _PayoutsSection(eventId: eventId, fin: null, items: items),
              ),
            ),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(
              title: 'Financial timeline',
              subtitle: 'Purchases · fees · refunds · payouts · complimentary',
            ),
            txs.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => EosSurfaceCard(
                child: Text('Timeline unavailable: $e', style: context.eosText.bodyMedium),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EosSurfaceCard(
                    child: Text(
                      'No financial activity yet. Ticket purchases and complimentary issues appear here.',
                      style: context.eosText.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final t in items)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                        child: EosSurfaceCard(
                          child: ListTile(
                            leading: Icon(_txIcon(t.type)),
                            title: Text(_txLabel(t.type)),
                            subtitle: Text(
                              [
                                t.status,
                                if (t.reason != null && t.reason!.isNotEmpty) t.reason,
                                DateTime.fromMillisecondsSinceEpoch(t.timestampMs).toLocal().toString().split('.').first,
                              ].join(' · '),
                            ),
                            trailing: Text(formatRevenue(int.tryParse(t.amountMinor) ?? 0)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(title: 'Export'),
            _ExportRow(eventId: eventId),
            SizedBox(height: context.eos.spacing.xl),
            snapAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (snap) {
                final chartData = BudgetChartData.fromSnapshot(snap);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CcV3SectionHeader(
                      title: 'Budget context',
                      subtitle: 'Celebration budget vs ticket finance (separate rails)',
                    ),
                    CcV3BudgetLandscapeChart(data: chartData),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _txLabel(String type) => switch (type) {
        'ticket_sale' => 'Purchase',
        'platform_fee' => 'Platform fee',
        'payout' => 'Payout',
        'refund_request' => 'Refund',
        'complimentary_issue' => 'Complimentary ticket',
        'vendor_payment' => 'Vendor payment',
        _ => type,
      };

  static IconData _txIcon(String type) => switch (type) {
        'payout' => Icons.payments_outlined,
        'refund_request' => Icons.undo_outlined,
        'complimentary_issue' => Icons.card_giftcard_outlined,
        'platform_fee' => Icons.percent_outlined,
        'vendor_payment' => Icons.storefront_outlined,
        _ => Icons.receipt_long_outlined,
      };
}

class _FinanceSkeleton extends StatelessWidget {
  const _FinanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: const EosSurfaceCard(
              child: SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
            ),
          ),
      ],
    );
  }
}

class _FinancialSummarySection extends StatelessWidget {
  const _FinancialSummarySection({required this.fin, required this.eventId});

  final OrganizerEventFinanceSummary fin;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final settlementLabel = switch (fin.settlementStatus) {
      'in_escrow' => 'In escrow',
      'partial' => 'Partial release',
      'clear' => 'Clear',
      _ => 'No settlements',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CcV3HealthCard(
          title: 'Event financial summary',
          progressPercent: fin.refundRatePct.clamp(0, 100),
          metrics: [
            CcV3MetricItem(label: 'Gross', value: formatRevenue(int.tryParse(fin.grossCollectedMinor) ?? 0)),
            CcV3MetricItem(label: 'Net', value: formatRevenue(int.tryParse(fin.netEarningsMinor) ?? 0)),
            CcV3MetricItem(label: 'Fees', value: formatRevenue(int.tryParse(fin.platformFeeMinor) ?? 0)),
            CcV3MetricItem(label: 'Tickets', value: '${fin.ticketsSold}'),
          ],
        ),
        SizedBox(height: context.eos.spacing.md),
        Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.md,
          children: [
            _kpi(context, 'Complimentary', '${fin.complimentaryTicketCount}', 'issued free / invite'),
            _kpi(
              context,
              'Refunds',
              formatRevenue(int.tryParse(fin.refundedTotalMinor) ?? 0),
              '${fin.refundRatePct.toStringAsFixed(1)}% rate · ${fin.openRefundRequests} open',
            ),
            _kpi(
              context,
              'Escrow held',
              formatRevenue(int.tryParse(fin.heldInEscrowMinor) ?? 0),
              fin.earliestEscrowReleaseAt != null
                  ? 'Next release ${fin.earliestEscrowReleaseAt!.split('T').first}'
                  : settlementLabel,
            ),
            _kpi(
              context,
              'Available payout',
              formatRevenue(int.tryParse(fin.availableForPayoutMinor) ?? 0),
              fin.payoutEligible
                  ? 'Eligible'
                  : (fin.payoutEligibilityReason ?? 'Not eligible'),
            ),
            _kpi(
              context,
              'Settlement',
              settlementLabel,
              '${fin.fulfilledOrderCount} fulfilled orders',
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpi(BuildContext context, String title, String value, String subtitle) {
    return SizedBox(
      width: 200,
      child: EosKpiCard(title: title, value: value, subtitle: subtitle, icon: Icons.account_balance_wallet_outlined),
    );
  }
}

class _RefundsSection extends ConsumerWidget {
  const _RefundsSection({required this.eventId, required this.items});

  final String eventId;
  final List<OrganizerRefundCase> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return EosSurfaceCard(
        child: Text(
          'No refund cases yet. Buyer or organizer requests appear here with status.',
          style: context.eosText.bodyMedium,
        ),
      );
    }
    return Column(
      children: [
        for (final r in items)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r.statusLabel} · ${formatRevenue(int.tryParse(r.amountMinor) ?? 0)}'),
                    subtitle: Text(
                      '${r.requesterEmail.isNotEmpty ? r.requesterEmail : 'Requester'}\n'
                      'Order ${r.ticketOrderId}\n${r.reason}',
                    ),
                    isThreeLine: true,
                    trailing: EosFinanceChip(label: r.statusLabel, compact: true),
                  ),
                  Wrap(
                    spacing: context.eos.spacing.xs,
                    children: [
                      if (r.status == 'requested' || r.status == 'under_review') ...[
                        FilledButton(
                          onPressed: () => _act(context, ref, r.id, 'approve'),
                          child: const Text('Approve'),
                        ),
                        OutlinedButton(
                          onPressed: () => _act(context, ref, r.id, 'reject'),
                          child: const Text('Decline'),
                        ),
                        TextButton(
                          onPressed: () => _act(context, ref, r.id, 'escalate'),
                          child: const Text('Escalate'),
                        ),
                      ],
                      if (r.status == 'approved')
                        FilledButton(
                          onPressed: () => _act(context, ref, r.id, 'approve'),
                          child: const Text('Mark completed'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String caseId, String action) async {
    try {
      await ref.read(organizerFinanceApiProvider).refundAction(
            eventId: eventId,
            caseId: caseId,
            action: action,
            session: ref.read(authSessionProvider),
          );
      invalidateEventFinance(ref, eventId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refund $action applied')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _PayoutsSection extends ConsumerWidget {
  const _PayoutsSection({required this.eventId, required this.fin, required this.items});

  final String eventId;
  final OrganizerEventFinanceSummary? fin;
  final List<OrganizerPayoutItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fin != null) ...[
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escrow: ${formatRevenue(int.tryParse(fin!.heldInEscrowMinor) ?? 0)} held · '
                  'Pending: ${formatRevenue(int.tryParse(fin!.pendingPayoutMinor) ?? 0)} · '
                  'Available: ${formatRevenue(int.tryParse(fin!.availableForPayoutMinor) ?? 0)}',
                  style: context.eosText.bodyMedium,
                ),
                if (fin!.payoutEligibilityReason != null) ...[
                  SizedBox(height: context.eos.spacing.xs),
                  Text(fin!.payoutEligibilityReason!, style: context.eosText.bodySmall),
                ],
                if (fin!.payoutEligible && (int.tryParse(fin!.availableForPayoutMinor) ?? 0) > 0) ...[
                  SizedBox(height: context.eos.spacing.md),
                  FilledButton.icon(
                    onPressed: () => _requestPayout(context, ref, fin!),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Request payout'),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
        ],
        if (items.isEmpty)
          EosSurfaceCard(
            child: Text('No payout records for this event yet.', style: context.eosText.bodyMedium),
          )
        else
          for (final p in items)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosSurfaceCard(
                child: ListTile(
                  leading: Icon(
                    p.status == 'failed' ? Icons.error_outline : Icons.payments_outlined,
                  ),
                  title: Text('${p.label} · ${formatRevenue(int.tryParse(p.amountMinor) ?? 0)}'),
                  subtitle: Text(
                    [
                      p.status,
                      if (p.failureMessage != null) p.failureMessage!,
                      if (p.createdAt != null) p.createdAt!.split('T').first,
                    ].join(' · '),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _requestPayout(
    BuildContext context,
    WidgetRef ref,
    OrganizerEventFinanceSummary fin,
  ) async {
    final available = int.tryParse(fin.availableForPayoutMinor) ?? 0;
    final session = ref.read(authSessionProvider);
    await ref.read(organizerPayoutControllerProvider.notifier).submit(
          organizerId: fin.organizerId,
          amountMinor: available.toString(),
          session: session,
        );
    final err = ref.read(organizerPayoutControllerProvider).error;
    invalidateEventFinance(ref, eventId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Payout requested')),
    );
  }
}

class _ExportRow extends ConsumerWidget {
  const _ExportRow({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: [
        for (final kind in ['summary', 'orders', 'transactions', 'refunds'])
          OutlinedButton.icon(
            onPressed: () => _export(context, ref, kind),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text('Export $kind'),
          ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, String kind) async {
    try {
      final bytes = await ref.read(organizerFinanceApiProvider).exportEventBytes(
            eventId: eventId,
            kind: kind,
            format: 'csv',
            session: ref.read(authSessionProvider),
          );
      final filename = 'owanbe-$kind-${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      final path = await ExportHelper.downloadBytes(filename, bytes, mimeType: 'text/csv; charset=utf-8');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path == null || path == filename
                  ? 'Downloaded $filename'
                  : 'Saved $filename → $path',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
