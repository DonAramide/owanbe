import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../widgets/cards/review_card.dart';
import 'admin_finance_providers.dart';

class AdminReviewScreen extends ConsumerStatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  ConsumerState<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends ConsumerState<AdminReviewScreen> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(adminReviewsProvider);
    final action = ref.watch(reviewRowActionProvider);
    return reviews.when(
      data: (page) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _selected.isEmpty ? null : () => _bulkAction(context, 'approve'),
                child: const Text('Approve Selected'),
              ),
              OutlinedButton(
                onPressed: _selected.isEmpty ? null : () => _bulkAction(context, 'reject'),
                child: const Text('Reject Selected'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (page.items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No under-review items'))),
          ...page.items.map((r) {
            final loading = action.loadingIds.contains(r.paymentId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Checkbox(
                    value: _selected.contains(r.paymentId),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(r.paymentId);
                        } else {
                          _selected.remove(r.paymentId);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: ReviewCard(
                      title: 'Payment ${r.paymentId} • ${ngnFromMinor(r.amountMinor)}',
                      subtitle: 'Reason: ${r.reason} • Booking: ${r.bookingId}',
                      onApprove: loading ? () {} : () => _action(context, r.paymentId, 'approve'),
                      onReject: loading ? () {} : () => _action(context, r.paymentId, 'reject'),
                      onEscalate: loading ? () {} : () => _action(context, r.paymentId, 'escalate'),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showDetails(context, r),
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.visibility),
                  ),
                ],
              ),
            );
          }),
          _Pager(
            page: page.page,
            totalPages: page.totalPages,
            onChanged: (v) => ref.read(reviewQueryProvider.notifier).setPage(v),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text(e.toString())),
    );
  }

  Future<void> _bulkAction(BuildContext context, String action) async {
    final ok = await _confirm(context, 'Apply "$action" to ${_selected.length} selected reviews?');
    if (!ok) return;
    final api = ref.read(adminFinanceApiProvider);
    final notifier = ref.read(reviewRowActionProvider.notifier);
    for (final id in _selected.toList()) {
      notifier.start(id);
      try {
        await api.reviewAction(id, action);
      } finally {
        notifier.stop(id);
      }
    }
    ref.invalidate(adminReviewsProvider);
    ref.invalidate(adminSummaryProvider);
    setState(() => _selected.clear());
  }

  Future<void> _action(BuildContext context, String id, String action) async {
    final api = ref.read(adminFinanceApiProvider);
    final notifier = ref.read(reviewRowActionProvider.notifier);
    final ok = await _confirm(context, 'Proceed with "$action" for payment $id?');
    if (!ok) return;
    notifier.start(id);
    try {
      await api.reviewAction(id, action);
      ref.invalidate(adminReviewsProvider);
      ref.invalidate(adminSummaryProvider);
    } finally {
      notifier.stop(id);
    }
  }

  Future<bool> _confirm(BuildContext context, String prompt) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm manual review action'),
        content: Text(prompt),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showDetails(BuildContext context, dynamic r) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Review ${r.paymentId}'),
        content: Text(
          'Amount: ${ngnFromMinor(r.amountMinor)}\nReason: ${r.reason}\nBooking: ${r.bookingId}',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.totalPages, required this.onChanged});
  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton(onPressed: page > 1 ? () => onChanged(page - 1) : null, child: const Text('Prev')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Page $page / $totalPages'),
        ),
        OutlinedButton(onPressed: page < totalPages ? () => onChanged(page + 1) : null, child: const Text('Next')),
      ],
    );
  }
}
