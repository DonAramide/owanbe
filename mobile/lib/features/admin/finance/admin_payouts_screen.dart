import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../widgets/tables/app_data_table.dart';
import 'admin_finance_providers.dart';
import 'finance_status_chip.dart';

class AdminPayoutsScreen extends ConsumerStatefulWidget {
  const AdminPayoutsScreen({super.key});
  @override
  ConsumerState<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends ConsumerState<AdminPayoutsScreen> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final payouts = ref.watch(adminPayoutsProvider);
    final q = ref.watch(payoutQueryProvider);
    final action = ref.watch(payoutRowActionProvider);
    return payouts.when(
      data: (page) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: action.busy
                    ? null
                    : () async {
                        final ok = await _confirm(
                          context,
                          'Process payout batch now?',
                        );
                        if (!ok) return;
                        ref
                            .read(payoutRowActionProvider.notifier)
                            .setBusy(true);
                        await ref
                            .read(adminFinanceApiProvider)
                            .processPayoutBatch();
                        ref.invalidate(adminPayoutsProvider);
                        ref.invalidate(adminSummaryProvider);
                        ref
                            .read(payoutRowActionProvider.notifier)
                            .setBusy(false);
                      },
                child: action.busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Process Batch Payout'),
              ),
              FilledButton.tonal(
                onPressed: _selected.isEmpty
                    ? null
                    : () async {
                        final ok = await _confirm(
                          context,
                          'Retry ${_selected.length} selected payouts?',
                        );
                        if (!ok) return;
                        for (final id in _selected.toList()) {
                          ref.read(payoutRowActionProvider.notifier).start(id);
                          try {
                            await ref
                                .read(adminFinanceApiProvider)
                                .retryPayout(id);
                          } finally {
                            ref.read(payoutRowActionProvider.notifier).stop(id);
                          }
                        }
                        ref.invalidate(adminPayoutsProvider);
                        ref.invalidate(adminSummaryProvider);
                        setState(() => _selected.clear());
                      },
                child: const Text('Retry Selected'),
              ),
              DropdownButton<String>(
                value: q.status,
                hint: const Text('Status filter'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('all')),
                  DropdownMenuItem(value: 'pending', child: Text('pending')),
                  DropdownMenuItem(
                    value: 'processing',
                    child: Text('processing'),
                  ),
                  DropdownMenuItem(value: 'failed', child: Text('failed')),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('completed'),
                  ),
                ],
                onChanged: (v) =>
                    ref.read(payoutQueryProvider.notifier).setStatus(v),
              ),
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _toCsv(page.items)),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CSV copied to clipboard')),
                    );
                  }
                },
                child: const Text('Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (page.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No payouts found'),
              ),
            ),
          if (page.items.isNotEmpty)
            AppDataTable(
              columns: const [
                DataColumn(label: Text('Select')),
                DataColumn(label: Text('Payout ID')),
                DataColumn(label: Text('Vendor')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Actions')),
              ],
              rows: page.items
                  .map(
                    (p) => DataRow(
                      selected: _selected.contains(p.id),
                      cells: [
                        DataCell(
                          Checkbox(
                            value: _selected.contains(p.id),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(p.id);
                                } else {
                                  _selected.remove(p.id);
                                }
                              });
                            },
                          ),
                        ),
                        DataCell(Text(p.id)),
                        DataCell(Text(p.vendorId)),
                        DataCell(Text(ngnFromMinor(p.amountMinor))),
                        DataCell(
                          FinanceStatusChip(
                            label: p.underReview ? 'under_review' : p.status,
                            compact: true,
                          ),
                        ),
                        DataCell(Text(p.createdAt.toIso8601String())),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: action.loadingIds.contains(p.id)
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                onPressed: action.loadingIds.contains(p.id)
                                    ? null
                                    : () async {
                                        final ok = await _confirm(
                                          context,
                                          'Retry payout ${p.id} for ${ngnFromMinor(p.amountMinor)} (${p.vendorId})?',
                                        );
                                        if (!ok) return;
                                        ref
                                            .read(
                                              payoutRowActionProvider.notifier,
                                            )
                                            .start(p.id);
                                        try {
                                          await ref
                                              .read(adminFinanceApiProvider)
                                              .retryPayout(p.id);
                                          ref.invalidate(adminPayoutsProvider);
                                          ref.invalidate(adminSummaryProvider);
                                        } finally {
                                          ref
                                              .read(
                                                payoutRowActionProvider
                                                    .notifier,
                                              )
                                              .stop(p.id);
                                        }
                                      },
                              ),
                              IconButton(
                                onPressed: () => _showDetails(context, p),
                                icon: const Icon(Icons.visibility),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 8),
          _Pager(
            page: page.page,
            totalPages: page.totalPages,
            onChanged: (v) => ref.read(payoutQueryProvider.notifier).setPage(v),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text(e.toString())),
    );
  }

  Future<void> _showDetails(BuildContext context, dynamic p) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Payout ${p.id}'),
        content: Text(
          'Vendor: ${p.vendorId}\nAmount: ${ngnFromMinor(p.amountMinor)} ${p.currency ?? ''}\n'
          'Status: ${p.status}\nBooking: ${p.bookingId ?? '-'}\nPayment: ${p.paymentId ?? '-'}\n'
          'Failure: ${p.failureMessage ?? p.failureCode ?? '-'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _toCsv(List<dynamic> items) {
    final lines = <String>[
      'id,vendor_id,amount_minor,status,booking_id,payment_id,created_at',
    ];
    for (final i in items) {
      lines.add(
        '${i.id},${i.vendorId},${i.amountMinor},${i.status},${i.bookingId ?? ''},${i.paymentId ?? ''},${i.createdAt.toIso8601String()}',
      );
    }
    return lines.join('\n');
  }

  Future<bool> _confirm(BuildContext context, String prompt) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm action'),
        content: Text(prompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return res == true;
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });
  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          child: const Text('Prev'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Page $page / $totalPages'),
        ),
        OutlinedButton(
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
