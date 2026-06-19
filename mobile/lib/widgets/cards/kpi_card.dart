import 'package:flutter/material.dart';

import '../../eos/widgets/cards/eos_kpi_card.dart';

/// Legacy KPI card — use [EosKpiCard] in new modules.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.color,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return EosKpiCard(
      title: title,
      value: value,
      subtitle: subtitle,
      attention: color != null ? EosKpiAttention.warning : EosKpiAttention.none,
    );
  }
}
