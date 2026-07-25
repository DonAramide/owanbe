import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/widgets/ticket_tier_card.dart';
import '../navigation/attendee_routes.dart';
import '../widgets/attendee_flow_scaffold.dart';

/// Ticket tier selection inside the Attendee Workspace.
class AttendeeTicketSelectScreen extends ConsumerStatefulWidget {
  const AttendeeTicketSelectScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AttendeeTicketSelectScreen> createState() => _AttendeeTicketSelectScreenState();
}

class _AttendeeTicketSelectScreenState extends ConsumerState<AttendeeTicketSelectScreen> {
  final Map<String, int> _qty = {};

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(publicEventProvider(widget.eventId));

    return AttendeeFlowScaffold(
      backLabel: 'Back to event',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.eventDetail(widget.eventId)),
      body: eventAsync.when(
        data: (event) {
          if (event == null) return const Center(child: Text('Event not found'));
          final totalQty = _qty.values.fold(0, (a, b) => a + b);
          var totalMinor = 0;
          final lines = <_OrderLine>[];
          for (final tier in event.ticketTiers) {
            final q = _qty[tier.id] ?? 0;
            if (q > 0) {
              lines.add(_OrderLine(tier: tier, quantity: q));
              totalMinor += tier.priceMinor * q;
            }
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
                      if (lines.isNotEmpty) ...[
                        SizedBox(height: context.eos.spacing.lg),
                        EosSection(
                          title: 'Order summary',
                          child: EosSurfaceCard(
                            child: Column(
                              children: [
                                for (var i = 0; i < lines.length; i++) ...[
                                  if (i > 0) Divider(height: context.eos.spacing.md),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${lines[i].tier.name} × ${lines[i].quantity}',
                                          style: context.eosText.bodyMedium,
                                        ),
                                      ),
                                      Text(
                                        ngnFromMinor(
                                          (lines[i].tier.priceMinor * lines[i].quantity).toString(),
                                        ),
                                        style: context.eosText.labelLarge,
                                      ),
                                    ],
                                  ),
                                ],
                                Divider(height: context.eos.spacing.lg),
                                Row(
                                  children: [
                                    Text('Total', style: context.eosText.titleSmall),
                                    const Spacer(),
                                    Text(
                                      ngnFromMinor(totalMinor.toString()),
                                      style: EosTypography.metric(context.eosColors, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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
    cart.clear();
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
    context.push(AttendeeRoutes.checkout);
  }
}

class _OrderLine {
  const _OrderLine({required this.tier, required this.quantity});

  final TicketTier tier;
  final int quantity;
}
