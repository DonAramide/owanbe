import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dispute_providers.dart';

class VendorDisputesScreen extends ConsumerWidget {
  const VendorDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(myDisputesProvider);
    return disputes.when(
      data: (page) => page.items.isEmpty
          ? const Center(child: Text('No assigned disputes'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: page.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final d = page.items[index];
                return Card(
                  child: ListTile(
                    title: Text(d.reason),
                    subtitle: Text('Status: ${d.status} • Booking: ${d.bookingId}'),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        await ref.read(disputesApiProvider).addMessage(
                              d.id,
                              'Vendor response: acknowledged and working on resolution',
                            );
                        ref.invalidate(myDisputesProvider);
                      },
                      child: const Text('Respond'),
                    ),
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text(e.toString())),
    );
  }
}
