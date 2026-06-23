import 'package:flutter/material.dart';

import '../../../eos/widgets/financial/eos_finance_chip.dart';

/// Legacy alias — prefer [EosFinanceChip] in new modules.
class FinanceStatusChip extends StatelessWidget {
  const FinanceStatusChip({
    super.key,
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => EosFinanceChip(label: label, compact: compact);
}
