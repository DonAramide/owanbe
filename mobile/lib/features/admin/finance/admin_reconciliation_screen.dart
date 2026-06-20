import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../widgets/tables/app_data_table.dart';
import 'admin_finance_providers.dart';
import 'finance_status_chip.dart';

class AdminReconciliationScreen extends ConsumerWidget {
  const AdminReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recon = ref.watch(adminReconciliationProvider);
    final q = ref.watch(reconQueryProvider);
    final action = ref.watch(reconRowActionProvider);
    return recon.when(
      data: (page) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                value: q.status,
                hint: const Text('Status filter'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('all')),
                  DropdownMenuItem(value: 'open', child: Text('open')),
                  DropdownMenuItem(
                    value: 'escalated',
                    child: Text('escalated'),
                  ),
                  DropdownMenuItem(value: 'resolved', child: Text('resolved')),
                ],
                onChanged: (v) =>
                    ref.read(reconQueryProvider.notifier).setStatus(v),
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
              FilledButton.tonal(
                onPressed: action.busy
                    ? null
                    : () async {
                        ref.read(reconRowActionProvider.notifier).setBusy(true);
                        try {
                          await ref.read(adminFinanceApiProvider).runReconciliation();
                          ref.invalidate(adminReconciliationProvider);
                          ref.invalidate(adminSummaryProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reconciliation job completed')),
                            );
                          }
                        } finally {
                          ref.read(reconRowActionProvider.notifier).setBusy(false);
                        }
                      },
                child: action.busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Run reconciliation'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (page.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No reconciliation issues found'),
              ),
            ),
          if (page.items.isNotEmpty)
            AppDataTable(
              columns: const [
                DataColumn(label: Text('Report ID')),
                DataColumn(label: Text('Mismatch Type')),
                DataColumn(label: Text('Expected')),
                DataColumn(label: Text('Actual')),
                DataColumn(label: Text('Difference')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: page.items
                  .map(
                    (r) => DataRow(
                      cells: [
                        DataCell(Text(r.reportId)),
                        DataCell(
                          FinanceStatusChip(label: r.issueKind, compact: true),
                        ),
                        DataCell(Text(ngnFromMinor(r.expectedAmount))),
                        DataCell(Text(ngnFromMinor(r.actualAmount))),
                        DataCell(Text(ngnFromMinor(r.difference))),
                        DataCell(
                          FinanceStatusChip(label: r.status, compact: true),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                onPressed:
                                    r.paymentId == null ||
                                        action.loadingIds.contains(r.reportId)
                                    ? null
                                    : () async {
                                        ref
                                            .read(
                                              reconRowActionProvider.notifier,
                                            )
                                            .start(r.reportId);
                                        try {
                                          await ref
                                              .read(adminFinanceApiProvider)
                                              .recoverReconciliation(
                                                r.paymentId!,
                                              );
                                          ref.invalidate(
                                            adminReconciliationProvider,
                                          );
                                        } finally {
                                          ref
                                              .read(
                                                reconRowActionProvider.notifier,
                                              )
                                              .stop(r.reportId);
                                        }
                                      },
                                icon: action.loadingIds.contains(r.reportId)
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                              ),
                              IconButton(
                                onPressed: () => _showDetails(context, r),
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
            onChanged: (v) => ref.read(reconQueryProvider.notifier).setPage(v),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text(e.toString())),
    );
  }

  Future<void> _showDetails(BuildContext context, dynamic r) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reconciliation ${r.reportId}'),
        content: Text(
          'Issue: ${r.issueKind}\nSeverity: ${r.severity}\nExpected: ${ngnFromMinor(r.expectedAmount)}\n'
          'Actual: ${ngnFromMinor(r.actualAmount)}\nDifference: ${ngnFromMinor(r.difference)}\n'
          'Status: ${r.status}\nPayment: ${r.paymentId ?? '-'}\nBooking: ${r.bookingId ?? '-'}',
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
      'report_id,issue_kind,severity,expected,actual,difference,status,payment_id,booking_id',
    ];
    for (final i in items) {
      lines.add(
        '${i.reportId},${i.issueKind},${i.severity},${i.expectedAmount},${i.actualAmount},${i.difference},${i.status},${i.paymentId ?? ''},${i.bookingId ?? ''}',
      );
    }
    return lines.join('\n');
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
