import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_typography.dart';

class EosMoneyText extends StatelessWidget {
  const EosMoneyText({
    super.key,
    required this.amount,
    this.currency = 'NGN',
    this.compact = false,
    this.color,
  });

  final String amount;
  final String currency;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = (compact ? EosTypography.metric(context.eosColors, size: 20) : EosTypography.metric(context.eosColors))
        .copyWith(color: color);
    return Semantics(
      label: '$currency $amount',
      child: Text('$currency $amount', style: style),
    );
  }
}
