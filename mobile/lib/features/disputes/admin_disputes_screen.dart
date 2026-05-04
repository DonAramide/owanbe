import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import '../../widgets/tables/app_data_table.dart';
import 'dispute_providers.dart';

class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageData = ref.watch(adminDisputesProvider);
    final detail = ref.watch(adminDisputeDetailProvider);
    return Row(
      children: [
        Expanded(
          child: pageData.when(
            data: (page) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppDataTable(
                  columns: const [
                    DataColumn(label: Text('Dispute ID')),
                    DataColumn(label: Text('Booking')),
                    DataColumn(label: Text('Payment')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: page.items
                      .map(
                        (d) => DataRow(
                          cells: [
                            DataCell(Text(d.id)),
                            DataCell(Text(d.bookingId)),
                            DataCell(Text(d.paymentId)),
                            DataCell(Text(ngnFromMinor(d.amountClaimedMinor))),
                            DataCell(Text('${d.status} / ${d.outcome}')),
                            DataCell(Text(d.createdAt.toIso8601String())),
                            DataCell(
                              FilledButton.tonal(
                                onPressed: () => ref.read(selectedAdminDisputeIdProvider.notifier).state = d.id,
                                child: const Text('Open'),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: page.page > 1
                          ? () => ref.read(adminDisputesPageProvider.notifier).state = page.page - 1
                          : null,
                      child: const Text('Prev'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Page ${page.page} / ${page.totalPages}'),
                    ),
                    OutlinedButton(
                      onPressed: page.page < page.totalPages
                          ? () => ref.read(adminDisputesPageProvider.notifier).state = page.page + 1
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text(e.toString())),
          ),
        ),
        Container(width: 1, color: Theme.of(context).dividerColor),
        SizedBox(
          width: 420,
          child: detail.when(
            data: (d) => d == null
                ? const Center(child: Text('Select a dispute'))
                : _DisputeDetailPanel(dispute: d),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text(e.toString())),
          ),
        ),
      ],
    );
  }
}

class _DisputeDetailPanel extends ConsumerWidget {
  const _DisputeDetailPanel({required this.dispute});
  final dynamic dispute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgCtl = TextEditingController();
    final evidenceCtl = TextEditingController();
    final refundCtl = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dispute ${dispute.item.id}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Booking: ${dispute.item.bookingId}\nPayment: ${dispute.item.paymentId}'),
        const SizedBox(height: 12),
        Text('Chat', style: Theme.of(context).textTheme.titleMedium),
        ...dispute.messages.map<Widget>(
          (m) => ListTile(
            dense: true,
            title: Text(m.message),
            subtitle: Text('${m.senderType} • ${m.createdAt.toIso8601String()}'),
          ),
        ),
        TextField(controller: msgCtl, decoration: const InputDecoration(labelText: 'Reply message')),
        FilledButton.tonal(
          onPressed: () async {
            await ref.read(disputesApiProvider).addMessage(dispute.item.id, msgCtl.text.trim());
            ref.invalidate(adminDisputeDetailProvider);
          },
          child: const Text('Send'),
        ),
        const SizedBox(height: 12),
        Text('Evidence', style: Theme.of(context).textTheme.titleMedium),
        ...dispute.evidence.map<Widget>(
          (e) => ListTile(
            dense: true,
            title: Text(e.type),
            subtitle: Text(e.url),
          ),
        ),
        TextField(controller: evidenceCtl, decoration: const InputDecoration(labelText: 'Evidence URL')),
        FilledButton.tonal(
          onPressed: () async {
            await ref
                .read(disputesApiProvider)
                .addEvidence(dispute.item.id, type: 'document', url: evidenceCtl.text.trim());
            ref.invalidate(adminDisputeDetailProvider);
          },
          child: const Text('Upload Evidence'),
        ),
        const SizedBox(height: 16),
        TextField(controller: refundCtl, decoration: const InputDecoration(labelText: 'Partial refund amount (minor)')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () async {
                await ref.read(disputesApiProvider).resolve(
                      dispute.item.id,
                      resolution: 'client_win',
                      note: 'admin_resolution_client_win',
                    );
                ref.invalidate(adminDisputesProvider);
                ref.invalidate(adminDisputeDetailProvider);
              },
              child: const Text('Refund Client'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                await ref.read(disputesApiProvider).resolve(
                      dispute.item.id,
                      resolution: 'vendor_win',
                      releaseVendorPayout: true,
                      note: 'admin_resolution_vendor_win',
                    );
                ref.invalidate(adminDisputesProvider);
                ref.invalidate(adminDisputeDetailProvider);
              },
              child: const Text('Pay Vendor'),
            ),
            OutlinedButton(
              onPressed: () async {
                await ref.read(disputesApiProvider).resolve(
                      dispute.item.id,
                      resolution: 'partial',
                      refundAmountMinor: refundCtl.text.trim(),
                      releaseVendorPayout: true,
                      note: 'admin_resolution_partial',
                    );
                ref.invalidate(adminDisputesProvider);
                ref.invalidate(adminDisputeDetailProvider);
              },
              child: const Text('Partial Refund'),
            ),
          ],
        ),
      ],
    );
  }
}
