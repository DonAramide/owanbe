import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../widgets/cards/review_card.dart';
import 'admin_finance_models.dart';
import 'admin_finance_providers.dart';

class AdminTicketRefundsPanel extends ConsumerStatefulWidget {
  const AdminTicketRefundsPanel({super.key});

  @override
  ConsumerState<AdminTicketRefundsPanel> createState() => _AdminTicketRefundsPanelState();
}

class _AdminTicketRefundsPanelState extends ConsumerState<AdminTicketRefundsPanel> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final refunds = ref.watch(adminTicketRefundsProvider(_statusFilter));
    final action = ref.watch(ticketRefundRowActionProvider);
    return refunds.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                value: _statusFilter,
                hint: const Text('Status'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('open queue')),
                  DropdownMenuItem(value: 'requested', child: Text('requested')),
                  DropdownMenuItem(value: 'under_review', child: Text('under_review')),
                  DropdownMenuItem(value: 'approved', child: Text('approved')),
                  DropdownMenuItem(value: 'completed', child: Text('completed')),
                  DropdownMenuItem(value: 'rejected', child: Text('rejected')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v == '' ? null : v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No ticket refund cases'))),
          ...items.map((r) {
            final loading = action.loadingIds.contains(r.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReviewCard(
                title: '${r.eventTitle ?? 'Event'} • ${ngnFromMinor(r.amountMinor)}',
                subtitle: 'Order ${r.ticketOrderId} • ${r.status} • ${r.requesterEmail ?? 'buyer'}',
                onApprove: loading ? () {} : () => _action(r.id, 'approve'),
                onReject: loading ? () {} : () => _action(r.id, 'reject'),
                onEscalate: loading ? () {} : () => _action(r.id, 'escalate'),
              ),
            );
          }),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Future<void> _action(String caseId, String action) async {
    final api = ref.read(adminFinanceApiProvider);
    final notifier = ref.read(ticketRefundRowActionProvider.notifier);
    notifier.start(caseId);
    try {
      await api.ticketRefundAction(caseId, action);
      ref.invalidate(adminTicketRefundsProvider(_statusFilter));
    } finally {
      notifier.stop(caseId);
    }
  }
}

final adminTicketRefundsProvider =
    FutureProvider.autoDispose.family<List<AdminTicketRefundItem>, String?>((ref, status) async {
  return ref.read(adminFinanceApiProvider).getTicketRefunds(status: status);
});

final ticketRefundRowActionProvider =
    NotifierProvider<RowActionController, RowActionState>(RowActionController.new);
