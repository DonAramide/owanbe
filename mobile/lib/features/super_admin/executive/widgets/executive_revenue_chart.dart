import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';

class ExecutiveRevenueChart extends StatelessWidget {
  const ExecutiveRevenueChart({super.key, required this.points});

  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    final chartPoints = points
        .map(
          (p) => EosTimeSeriesPoint(
            label: '${p['label']}',
            values: {
              'ticket': (p['ticket'] as num).toDouble(),
              'booking': (p['booking'] as num).toDouble(),
              'fees': (p['fees'] as num).toDouble(),
              'refunds': (p['refunds'] as num).toDouble(),
              'payouts': (p['payouts'] as num).toDouble(),
            },
          ),
        )
        .toList();

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('30-day revenue', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.xxs),
          Text(
            'Daily distribution from platform finance totals weighted by audit activity',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.lg),
          EosTimeSeriesChart(
            points: chartPoints,
            height: 300,
            valueFormatter: (v) => formatRevenue(v.round()),
            series: const [
              EosTimeSeriesSeries(key: 'ticket', label: 'Ticket revenue', color: EosColors.plum),
              EosTimeSeriesSeries(key: 'booking', label: 'Booking revenue', color: EosColors.champagne),
              EosTimeSeriesSeries(key: 'fees', label: 'Platform fees', color: EosColors.success),
              EosTimeSeriesSeries(key: 'refunds', label: 'Refunds', color: EosColors.warning),
              EosTimeSeriesSeries(key: 'payouts', label: 'Payouts', color: EosColors.info),
            ],
          ),
        ],
      ),
    );
  }
}
