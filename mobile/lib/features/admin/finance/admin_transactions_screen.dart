import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../widgets/tables/app_data_table.dart';
import 'admin_finance_providers.dart';
import 'admin_finance_models.dart';
import 'finance_status_chip.dart';

class AdminTransactionsScreen extends ConsumerWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(adminTransactionsProvider);
    final q = ref.watch(txQueryProvider);
    return tx.when(
      data: (page) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                value: q.type,
                hint: const Text('Type'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('all')),
                  DropdownMenuItem(value: 'payment', child: Text('payment')),
                  DropdownMenuItem(value: 'payout', child: Text('payout')),
                  DropdownMenuItem(value: 'refund', child: Text('refund')),
                  DropdownMenuItem(
                    value: 'chargeback',
                    child: Text('chargeback'),
                  ),
                ],
                onChanged: (v) => ref.read(txQueryProvider.notifier).setType(v),
              ),
              DropdownButton<String>(
                value: q.status,
                hint: const Text('Status'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('all')),
                  DropdownMenuItem(value: 'pending', child: Text('pending')),
                  DropdownMenuItem(
                    value: 'processing',
                    child: Text('processing'),
                  ),
                  DropdownMenuItem(value: 'failed', child: Text('failed')),
                  DropdownMenuItem(value: 'captured', child: Text('captured')),
                  DropdownMenuItem(value: 'posted', child: Text('posted')),
                ],
                onChanged: (v) =>
                    ref.read(txQueryProvider.notifier).setStatus(v),
              ),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final from = await showDatePicker(
                    context: context,
                    initialDate: q.fromDate ?? now,
                    firstDate: DateTime(2020),
                    lastDate: now,
                  );
                  if (!context.mounted) return;
                  if (from == null) return;
                  final to = await showDatePicker(
                    context: context,
                    initialDate: q.toDate ?? now,
                    firstDate: from,
                    lastDate: now,
                  );
                  if (!context.mounted) return;
                  ref.read(txQueryProvider.notifier).setRange(from, to);
                },
                child: const Text('Date filter'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final csv = _toCsv(page.items);
                  await Clipboard.setData(ClipboardData(text: csv));
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
                child: Text('No transactions found'),
              ),
            ),
          if (page.items.isNotEmpty)
            AppDataTable(
              columns: [
                DataColumn(
                  label: const Text('ID'),
                  onSort: (columnIndex, ascending) =>
                      ref.read(txQueryProvider.notifier).setSort('id'),
                ),
                DataColumn(
                  label: const Text('User'),
                  onSort: (columnIndex, ascending) =>
                      ref.read(txQueryProvider.notifier).setSort('user'),
                ),
                DataColumn(
                  label: const Text('Amount'),
                  numeric: true,
                  onSort: (columnIndex, ascending) =>
                      ref.read(txQueryProvider.notifier).setSort('amount'),
                ),
                DataColumn(
                  label: const Text('Type'),
                  onSort: (columnIndex, ascending) =>
                      ref.read(txQueryProvider.notifier).setSort('type'),
                ),
                DataColumn(
                  label: const Text('Status'),
                  onSort: (columnIndex, ascending) =>
                      ref.read(txQueryProvider.notifier).setSort('status'),
                ),
                DataColumn(
                  label: const Text('Date'),
                  onSort: (columnIndex, ascending) =>
                      ref.read(txQueryProvider.notifier).setSort('created_at'),
                ),
                const DataColumn(label: Text('Actions')),
              ],
              rows: page.items
                  .map(
                    (e) => DataRow(
                      cells: [
                        DataCell(Text(e.id)),
                        DataCell(Text(e.user)),
                        DataCell(Text(ngnFromMinor(e.amountMinor))),
                        DataCell(
                          FinanceStatusChip(label: e.type, compact: true),
                        ),
                        DataCell(
                          FinanceStatusChip(label: e.status, compact: true),
                        ),
                        DataCell(Text(e.createdAt.toIso8601String())),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _showDetails(context, ref, e),
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
            onChanged: (v) => ref.read(txQueryProvider.notifier).setPage(v),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text(e.toString())),
    );
  }

  Future<void> _showDetails(BuildContext context, WidgetRef ref, AdminTxItem tx) async {
    final paymentId = tx.type == 'payment' && tx.id.startsWith('payment_')
        ? tx.id.substring('payment_'.length)
        : null;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Transaction ${tx.id}'),
        content: Text(
          'Type: ${tx.type}\nStatus: ${tx.status}\nAmount: ${ngnFromMinor(tx.amountMinor)}\n'
          'User: ${tx.user}\nBooking: ${tx.bookingId ?? '-'}\nDate: ${tx.createdAt.toIso8601String()}',
        ),
        actions: [
          if (paymentId != null && tx.status == 'captured') ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await ref.read(adminFinanceApiProvider).refundPayment(
                      paymentId: paymentId,
                      reason: 'admin_manual_refund',
                    );
                ref.invalidate(adminTransactionsProvider);
                ref.invalidate(adminSummaryProvider);
              },
              child: const Text('Refund'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                if (tx.bookingId == null) return;
                await ref.read(adminFinanceApiProvider).applyChargeback(
                      paymentId: paymentId,
                      amountMinor: tx.amountMinor,
                      eventId: tx.bookingId!,
                    );
                ref.invalidate(adminTransactionsProvider);
                ref.invalidate(adminSummaryProvider);
              },
              child: const Text('Chargeback'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _toCsv(List<dynamic> items) {
    final lines = <String>[
      'id,user,amount_minor,type,status,created_at,booking_id',
    ];
    for (final i in items) {
      lines.add(
        '${i.id},${i.user},${i.amountMinor},${i.type},${i.status},${i.createdAt.toIso8601String()},${i.bookingId ?? ''}',
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
