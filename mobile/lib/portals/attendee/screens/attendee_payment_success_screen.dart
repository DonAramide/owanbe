import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/ticket_commerce_providers.dart';
import '../commerce/purchase_notifications_provider.dart';
import '../navigation/attendee_routes.dart';
import '../widgets/attendee_flow_scaffold.dart';

/// Payment success inside the Attendee Workspace.
class AttendeePaymentSuccessScreen extends ConsumerStatefulWidget {
  const AttendeePaymentSuccessScreen({super.key});

  @override
  ConsumerState<AttendeePaymentSuccessScreen> createState() => _AttendeePaymentSuccessScreenState();
}

class _AttendeePaymentSuccessScreenState extends ConsumerState<AttendeePaymentSuccessScreen> {
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTickets());
  }

  Future<void> _syncTickets() async {
    if (_synced) return;
    _synced = true;
    // Invalidate sync provider so My Tickets refreshes without a manual pull.
    ref.invalidate(attendeeTicketsSyncProvider);
    try {
      await ref.read(attendeeTicketsSyncProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = ref.watch(checkoutEntitlementsProvider);
    final notices = ref.watch(purchaseNotificationsProvider).take(4).toList();

    return AttendeeFlowScaffold(
      backLabel: 'Back to tickets',
      onBack: () => context.go(AttendeeRoutes.dashboard),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(context.eos.spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EosSurfaceCard(
              elevated: true,
              accentColor: EosColors.success,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: EosColors.success, size: 56),
                  SizedBox(height: context.eos.spacing.md),
                  Text('Payment successful', style: context.eosText.headlineSmall),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    entitlements.isNotEmpty
                        ? '${entitlements.length} ticket(s) issued. Show the QR code at entry.'
                        : 'Payment recorded — tickets will appear on your dashboard.',
                    style: context.eosText.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (notices.isNotEmpty) ...[
                    SizedBox(height: context.eos.spacing.md),
                    for (final n in notices)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('• ${n.title}: ${n.body}', style: context.eosText.bodySmall),
                        ),
                      ),
                  ],
                  SizedBox(height: context.eos.spacing.lg),
                  FilledButton(
                    onPressed: () => context.go(AttendeeRoutes.dashboard),
                    child: const Text('View my tickets'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AttendeeRoutes.orders),
                    child: const Text('View purchase history'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AttendeeRoutes.dashboard),
                    child: const Text('Discover more events'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
