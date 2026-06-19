import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/public_models.dart';
import '../providers/public_providers.dart';
import '../widgets/public_shell_mixin.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  ConsumerState<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  bool _issued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _issueTickets());
  }

  Future<void> _issueTickets() async {
    if (_issued) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final catalog = ref.read(publicCatalogProvider);
    final tickets = <AttendeeTicket>[];
    final now = DateTime.now();

    for (final line in cart) {
      final event = await catalog.getEvent(line.eventId);
      if (event == null) continue;
      for (var i = 0; i < line.quantity; i++) {
        tickets.add(
          AttendeeTicket(
            id: 'tkt_${line.tierId}_${now.millisecondsSinceEpoch}_$i',
            eventId: event.id,
            eventTitle: event.title,
            tierName: line.tierName,
            venue: event.venue,
            city: event.city,
            startsAt: event.startsAt,
            qrPayload: 'OWANBE:${event.id}:${line.tierId}:$i',
            purchasedAt: now,
          ),
        );
      }
    }

    ref.read(attendeeTicketsProvider.notifier).addAll(tickets);
    ref.read(cartProvider.notifier).clear();
    setState(() => _issued = true);
  }

  @override
  Widget build(BuildContext context) {
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
                    'Your tickets are ready. Show the QR code at entry.',
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
