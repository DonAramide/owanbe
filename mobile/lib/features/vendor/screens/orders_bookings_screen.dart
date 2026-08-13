import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../../../portals/customer/widgets/vendor_crm/vendor_stage_badge.dart';
import '../providers/vendor_event_workspace_nav.dart';
import '../providers/vendor_providers.dart';

/// OMS surface — CRM jobs only. No fabricated commerce orders.
class OrdersBookingsScreen extends ConsumerWidget {
  const OrdersBookingsScreen({super.key});

  void _openWorkspace(WidgetRef ref, BuildContext context, VendorRequest r) {
    ref.read(vendorEventWorkspaceNavProvider.notifier).open(
          eventId: r.eventExternalRef ?? r.eventId,
          eventUuid: r.eventId,
          requestId: r.id,
          initialTabIndex: 0,
        );
    ref.read(vendorShellTabProvider.notifier).select(1);
    context.go('/vendor');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorIdAsync = ref.watch(canonicalVendorIdProvider);

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
          title: Text(
            'Jobs & bookings',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: vendorIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
          data: (vendorId) {
            final inbox = ref.watch(vendorInboxProvider(vendorId));
            return inbox.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('CRM jobs unavailable', style: context.eosText.titleMedium?.copyWith(color: Colors.white)),
                  Text('$e', style: const TextStyle(color: Colors.white70)),
                  TextButton(
                    onPressed: () {
                      refreshVendorCrm(ref);
                      ref.invalidate(vendorInboxProvider(vendorId));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (snap) {
                if (snap.items.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('No CRM jobs yet', style: context.eosText.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text(
                        'When organizers request you from the marketplace, jobs appear here from vendor_event_requests. '
                        'Ticket-commerce OMS and escrow boards are not wired — shown unavailable rather than mocked.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Canonical CRM jobs — tap a job to open Event Operations workspace',
                      style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    for (final r in snap.items)
                      Card(
                        color: const Color(0xFF241B3F),
                        child: ListTile(
                          title: Text(r.eventTitle ?? 'Event', style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            [
                              r.organizerName ?? 'Organizer',
                              r.serviceLabel ?? 'Service',
                              if (r.latestOfferMinor != null) formatRevenue(r.latestOfferMinor!),
                              'Contract: ${vendorCrmContractLabels[r.contractStatus] ?? r.contractStatus}',
                            ].join(' · '),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VendorStageBadge(stage: r.stage),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: Colors.white54),
                            ],
                          ),
                          onTap: () => _openWorkspace(ref, context, r),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Escrow / deliverable OMS board is not in this phase — job detail lives in Event Ops workspace.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
