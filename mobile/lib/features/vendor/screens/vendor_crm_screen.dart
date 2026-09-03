import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../portals/customer/providers/rentals_providers.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../providers/vendor_inbox_integration.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_incoming_requests_panel.dart';

/// Vendor CRM workspace — live inbox only (no mock leads).
class VendorCrmScreen extends ConsumerWidget {
  const VendorCrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(vendorInboxSnapshotProvider);

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1333),
        cardColor: const Color(0xFF241B3F),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1333),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Vendor CRM Inbox',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => context.go('/vendor'),
              child: const Text('Dashboard', style: TextStyle(color: EosColors.champagne)),
            ),
          ],
        ),
        body: inbox.whenStable(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
          data: (snap) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Canonical hire pipeline shared with organizers',
                  style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                if (snap.items.isEmpty)
                  const Text(
                    'No incoming CRM requests yet. Organizer marketplace requests appear here from vendor_event_requests.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  VendorIncomingRequestsPanel(snapshot: snap),
                const SizedBox(height: 24),
                Text(
                  'Outgoing (you as buyer)',
                  style: context.eosText.titleSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                const _OutgoingBuyerHistory(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutgoingBuyerHistory extends ConsumerWidget {
  const _OutgoingBuyerHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorId = ref.watch(canonicalVendorIdProvider).valueOrNull;
    final rentals = ref.watch(myRentalBookingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vendorId == null || vendorId.isEmpty)
          const Text('Vendor identity not resolved.', style: TextStyle(color: Colors.white54))
        else
          ref.watch(vendorOutgoingCrmProvider(vendorId)).when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e', style: const TextStyle(color: Colors.white54)),
                data: (out) {
                  if (out.items.isEmpty) {
                    return const Text(
                      'No outgoing service requests yet.',
                      style: TextStyle(color: Colors.white54),
                    );
                  }
                  return Column(
                    children: [
                      for (final r in out.items.take(20))
                        ListTile(
                          title: Text(r.serviceLabel ?? 'Service', style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            '${r.eventTitle ?? 'Event'} · ${r.vendorName ?? 'Provider'} · ${r.stage}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ),
                    ],
                  );
                },
              ),
        const SizedBox(height: 16),
        Text('Rental bookings', style: context.eosText.titleSmall?.copyWith(color: Colors.white)),
        rentals.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e', style: const TextStyle(color: Colors.white54)),
          data: (rows) {
            if (rows.isEmpty) {
              return const Text('No rental bookings as buyer yet.', style: TextStyle(color: Colors.white54));
            }
            return Column(
              children: [
                for (final b in rows.take(20))
                  ListTile(
                    title: Text(b.itemName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      '${b.eventTitle} · ${b.vendorName} · ${b.status}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

