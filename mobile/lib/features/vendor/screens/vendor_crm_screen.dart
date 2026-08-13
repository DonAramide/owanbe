import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/vendor_inbox_integration.dart';
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
        body: inbox.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
          data: (snap) {
            if (snap.items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No CRM requests yet. Organizer marketplace requests appear here from vendor_event_requests.\n\n'
                  'Mock lead boards were removed — notes live on request timeline messages.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Canonical hire pipeline shared with organizers',
                  style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                VendorIncomingRequestsPanel(snapshot: snap),
              ],
            );
          },
        ),
      ),
    );
  }
}
