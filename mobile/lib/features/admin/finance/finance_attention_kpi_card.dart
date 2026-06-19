import 'package:flutter/material.dart';

import '../../../eos/widgets/cards/eos_kpi_card.dart';
import 'finance_attention_copy.dart';

export 'finance_attention_copy.dart' show attentionLevelFromString, humanizeFinanceToken, formatAttentionAge, FinanceAttentionLevel;

/// Legacy wrapper — new code should use [EosKpiCard] directly.
class FinanceAttentionKpiCard extends StatelessWidget {
  const FinanceAttentionKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.attentionSummary,
    this.attentionLevel = FinanceAttentionLevel.none,
    this.icon,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final String? attentionSummary;
  final FinanceAttentionLevel attentionLevel;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onTap;

  EosKpiAttention _mapAttention() => switch (attentionLevel) {
        FinanceAttentionLevel.critical => EosKpiAttention.critical,
        FinanceAttentionLevel.warning => EosKpiAttention.warning,
        FinanceAttentionLevel.info => EosKpiAttention.info,
        FinanceAttentionLevel.none => EosKpiAttention.none,
      };

  @override
  Widget build(BuildContext context) {
    return EosKpiCard(
      title: title,
      value: value,
      subtitle: subtitle,
      attentionSummary: attentionSummary,
      attention: _mapAttention(),
      icon: icon,
      actionLabel: actionLabel,
      onTap: onTap,
    );
  }
}
