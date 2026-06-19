import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/public_models.dart';
import '../providers/public_providers.dart';
import '../widgets/public_shell_mixin.dart';
import '../widgets/ticket_tier_card.dart';

class TicketSelectScreen extends ConsumerStatefulWidget {
  const TicketSelectScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketSelectScreen> createState() => _TicketSelectScreenState();
}

class _TicketSelectScreenState extends ConsumerState<TicketSelectScreen> {
  final Map<String, int> _qty = {};

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(publicEventProvider(widget.eventId));

    return buildPublicShell(
      context: context,
      ref: ref,
      compact: true,
      child: eventAsync.when(
        data: (event) {
          if (event == null) return const Center(child: Text('Event not found'));
          final totalQty = _qty.values.fold(0, (a, b) => a + b);
          var totalMinor = 0;
          for (final tier in event.ticketTiers) {
            totalMinor += (tier.priceMinor * (_qty[tier.id] ?? 0));
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.eos.spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select tickets', style: context.eosText.headlineMedium),
                      SizedBox(height: context.eos.spacing.xxs),
                      Text(event.title, style: context.eosText.bodyMedium),
                      SizedBox(height: context.eos.spacing.lg),
                      for (final tier in event.ticketTiers) ...[
                        TicketTierCard(
                          tier: tier,
                          eventTitle: event.title,
                          quantity: _qty[tier.id] ?? 0,
                          onQuantityChanged: (q) => setState(() => _qty[tier.id] = q),
                        ),
                        SizedBox(height: context.eos.spacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
              Material(
                elevation: 8,
                child: Padding(
                  padding: EdgeInsets.all(context.eos.spacing.lg),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$totalQty ticket${totalQty == 1 ? '' : 's'}', style: context.eosText.labelMedium),
                          Text(
                            ngnFromMinor(totalMinor.toString()),
                            style: EosTypography.metric(context.eosColors, size: 22),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: totalQty > 0 ? () => _addToCart(event) : null,
                        child: const Text('Continue to checkout'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  void _addToCart(PublicEvent event) {
    final cart = ref.read(cartProvider.notifier);
    for (final tier in event.ticketTiers) {
      final q = _qty[tier.id] ?? 0;
      if (q <= 0) continue;
      cart.addOrUpdate(
        CartLine(
          eventId: event.id,
          eventTitle: event.title,
          tierId: tier.id,
          tierName: tier.name,
          unitPriceMinor: tier.priceMinor,
          currency: tier.currency,
          quantity: q,
        ),
      );
    }
    context.push('/checkout');
  }
}
