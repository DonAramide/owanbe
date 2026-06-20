import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/public_models.dart';
import '../providers/public_providers.dart';
import '../providers/ticket_commerce_providers.dart';
import '../widgets/public_shell_mixin.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  ConsumerState<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTickets());
  }

  void _syncTickets() {
    if (_synced) return;
    final entitlements = ref.read(checkoutEntitlementsProvider);
    if (entitlements.isEmpty) return;
    final tickets = entitlements
        .map(
          (e) => AttendeeTicket(
            id: e.id,
            eventId: e.eventId,
            eventTitle: e.eventTitle,
            tierName: e.tierName,
            venue: e.eventVenue,
            city: e.eventCity,
            startsAt: e.startsAt,
            qrPayload: e.qrPayload,
            purchasedAt: DateTime.now(),
          ),
        )
        .toList();
    ref.read(attendeeTicketsProvider.notifier).addAll(tickets);
    _synced = true;
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = ref.watch(checkoutEntitlementsProvider);

    return buildPublicShell(
      context: context,
      ref: ref,
      compact: true,
      child: Center(
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
                  SizedBox(height: context.eos.spacing.lg),
                  FilledButton(
                    onPressed: () => context.go('/attendee'),
                    child: const Text('View my tickets'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/events'),
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
