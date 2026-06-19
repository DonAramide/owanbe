import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/public_models.dart';

class TicketTierCard extends StatelessWidget {
  const TicketTierCard({
    super.key,
    required this.tier,
    required this.quantity,
    required this.onQuantityChanged,
    required this.eventTitle,
  });

  final TicketTier tier;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final String eventTitle;

  @override
  Widget build(BuildContext context) {
    final soldOut = tier.remaining <= 0;
    return EosSurfaceCard(
      accentColor: quantity > 0 ? context.eosColors.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tier.name, style: context.eosText.titleMedium),
                    SizedBox(height: context.eos.spacing.xxs),
                    Text(tier.description, style: context.eosText.bodySmall),
                  ],
                ),
              ),
              EosMoneyText(
                amount: ngnFromMinor(tier.priceMinor.toString()).replaceFirst('₦', ''),
                currency: '₦',
                compact: true,
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              Text(
                soldOut ? 'Sold out' : '${tier.remaining} left',
                style: context.eosText.labelSmall?.copyWith(
                  color: soldOut ? EosColors.critical : context.eosColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: soldOut || quantity <= 0 ? null : () => onQuantityChanged(quantity - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$quantity', style: context.eosText.titleMedium),
              IconButton(
                onPressed: soldOut || quantity >= tier.remaining
                    ? null
                    : () => onQuantityChanged(quantity + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
