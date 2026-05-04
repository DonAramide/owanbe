import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import 'dispute_providers.dart';

class ClientDisputesScreen extends ConsumerWidget {
  const ClientDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(myDisputesProvider);
    final bookingCtl = TextEditingController();
    final reasonCtl = TextEditingController();
    final descCtl = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Create Dispute', style: Theme.of(context).textTheme.titleLarge),
        TextField(controller: bookingCtl, decoration: const InputDecoration(labelText: 'Booking ID')),
        TextField(controller: reasonCtl, decoration: const InputDecoration(labelText: 'Reason')),
        TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            await ref.read(disputesApiProvider).create(
                  bookingId: bookingCtl.text.trim(),
                  reason: reasonCtl.text.trim(),
                  description: descCtl.text.trim(),
                );
            ref.invalidate(myDisputesProvider);
          },
          child: const Text('Submit Dispute'),
        ),
        const SizedBox(height: 16),
        disputes.when(
          data: (page) => page.items.isEmpty
              ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No disputes yet')))
              : Column(
                  children: page.items
                      .map(
                        (d) => Card(
                          child: ListTile(
                            title: Text(d.reason),
                            subtitle: Text('Status: ${d.status} • ${ngnFromMinor(d.amountClaimedMinor)}'),
                            trailing: Text(d.createdAt.toIso8601String()),
                          ),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text(e.toString()),
        ),
      ],
    );
  }
}
