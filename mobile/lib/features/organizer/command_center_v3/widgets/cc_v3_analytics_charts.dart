import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../models/event_command_center_v3_models.dart';

class CcV3AnalyticsOverviewCharts extends StatelessWidget {
  const CcV3AnalyticsOverviewCharts({super.key, required this.snap});

  final EventCommandCenterV3Snapshot snap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snap.isPrivate) ...[
          CcV3RsvpFunnelChart(guest: snap.guestHealth),
          SizedBox(height: context.eos.spacing.lg),
          CcV3BudgetUtilizationChart(financial: snap.financial),
          SizedBox(height: context.eos.spacing.lg),
          CcV3VendorPipelineChart(vendor: snap.vendorHealth),
        ] else if (snap.publicMetrics != null) ...[
          CcV3TicketPerformanceChart(metrics: snap.publicMetrics!),
          SizedBox(height: context.eos.spacing.lg),
          CcV3VendorPipelineChart(vendor: snap.vendorHealth),
        ],
        SizedBox(height: context.eos.spacing.lg),
        CcV3PlanningProgressChart(
          progress: snap.planningProgress,
          daysUntil: snap.daysUntilEvent,
        ),
      ],
    );
  }
}

class CcV3RsvpFunnelChart extends StatelessWidget {
  const CcV3RsvpFunnelChart({super.key, required this.guest});

  final GuestHealthSnapshot guest;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _FunnelStep('Invited', guest.invited, EosColors.plum.withValues(alpha: 0.35)),
      _FunnelStep('Accepted', guest.rsvpAccepted, EosColors.plum),
      _FunnelStep('Pending', guest.rsvpPending, EosColors.warning),
      _FunnelStep('Checked in', guest.checkedIn, EosColors.champagne),
    ];
    final max = math.max(1, guest.invited);

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Guest RSVP funnel', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.xs),
          Text('${guest.responsePercent.round()}% response rate', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.lg),
          for (final step in steps) ...[
            _FunnelBar(step: step, max: max),
            SizedBox(height: context.eos.spacing.sm),
          ],
        ],
      ),
    );
  }
}

class CcV3BudgetUtilizationChart extends StatelessWidget {
  const CcV3BudgetUtilizationChart({super.key, required this.financial});

  final FinancialHealthSnapshot financial;

  @override
  Widget build(BuildContext context) {
    final budget = financial.budgetMinor > 0 ? financial.budgetMinor : 1;
    final spent = financial.fundsReleasedMinor + financial.fundsReservedMinor;
    final segments = [
      (spent / budget, EosColors.plum),
      (financial.remainingBudgetMinor / budget, context.eosColors.outlineVariant),
    ];

    return EosSurfaceCard(
      elevated: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _AnalyticsDonutPainter(
                segments: segments,
                strokeWidth: 12,
                centerLabel: '${financial.utilizationPercent.round()}%',
                centerSubLabel: 'used',
                textColor: context.eosColors.onSurface,
                subColor: context.eosColors.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(width: context.eos.spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Budget utilization', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.md),
                _MetricRow(label: 'Budget', value: formatRevenue(financial.budgetMinor)),
                _MetricRow(label: 'Spent', value: formatRevenue(spent)),
                _MetricRow(label: 'Remaining', value: formatRevenue(financial.remainingBudgetMinor)),
                _MetricRow(label: 'Reserved', value: formatRevenue(financial.fundsReservedMinor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CcV3VendorPipelineChart extends StatelessWidget {
  const CcV3VendorPipelineChart({super.key, required this.vendor});

  final VendorHealthSnapshot vendor;

  @override
  Widget build(BuildContext context) {
    final bars = [
      _FunnelStep('Requested', vendor.requested, const Color(0xFF64748B)),
      _FunnelStep('Negotiating', vendor.negotiating, EosColors.warning),
      _FunnelStep('Confirmed', vendor.confirmed, EosColors.plum),
      _FunnelStep('Completed', vendor.completed, EosColors.champagne),
    ];
    final max = math.max(
      1,
      [vendor.requested, vendor.negotiating, vendor.confirmed, vendor.completed].reduce(math.max),
    );

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vendor pipeline', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.xs),
          Text('${vendor.progressPercent.round()}% vendors confirmed', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.lg),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _GroupedBarPainter(
                bars: bars
                    .map((b) => _BarGroup(b.label, b.count, b.color))
                    .toList(),
                maxValue: max.toDouble(),
                labelColor: context.eosColors.onSurfaceVariant,
                valueColor: context.eosColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CcV3TicketPerformanceChart extends StatelessWidget {
  const CcV3TicketPerformanceChart({super.key, required this.metrics});

  final PublicEventMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final capacity = metrics.totalCapacity > 0 ? metrics.totalCapacity : 1;
    final soldFrac = metrics.ticketsSold / capacity;
    final remainFrac = (capacity - metrics.ticketsSold) / capacity;

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ticket sales', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.lg),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _AnalyticsDonutPainter(
                    segments: [
                      (soldFrac, EosColors.plum),
                      (remainFrac, context.eosColors.outlineVariant),
                    ],
                    strokeWidth: 12,
                    centerLabel: '${metrics.conversionPercent.round()}%',
                    centerSubLabel: 'sold',
                    textColor: context.eosColors.onSurface,
                    subColor: context.eosColors.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(width: context.eos.spacing.lg),
              Expanded(
                child: Column(
                  children: [
                    _MetricRow(label: 'Sold', value: '${metrics.ticketsSold}'),
                    _MetricRow(label: 'Capacity', value: '${metrics.totalCapacity}'),
                    _MetricRow(label: 'Revenue', value: formatRevenue(metrics.revenueMinor)),
                    _MetricRow(label: 'Attendees', value: '${metrics.attendees}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CcV3PlanningProgressChart extends StatelessWidget {
  const CcV3PlanningProgressChart({
    super.key,
    required this.progress,
    required this.daysUntil,
  });

  final double progress;
  final int daysUntil;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Planning momentum', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: context.eosColors.surfaceContainerHighest,
              color: EosColors.champagne,
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).round()}% setup complete', style: context.eosText.bodySmall),
              Text(
                daysUntil > 0 ? '$daysUntil days to event' : 'Event window',
                style: context.eosText.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FunnelStep {
  const _FunnelStep(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({required this.step, required this.max});

  final _FunnelStep step;
  final int max;

  @override
  Widget build(BuildContext context) {
    final frac = step.count / max;
    return Row(
      children: [
        SizedBox(width: 88, child: Text(step.label, style: context.eosText.labelSmall)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac.clamp(0.0, 1.0),
              minHeight: 18,
              backgroundColor: context.eosColors.surfaceContainerHighest,
              color: step.color,
            ),
          ),
        ),
        SizedBox(width: context.eos.spacing.sm),
        SizedBox(
          width: 28,
          child: Text('${step.count}', style: context.eosText.labelMedium, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.eosText.bodySmall),
          Text(value, style: context.eosText.labelMedium),
        ],
      ),
    );
  }
}

class _BarGroup {
  const _BarGroup(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _AnalyticsDonutPainter extends CustomPainter {
  _AnalyticsDonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.centerLabel,
    required this.centerSubLabel,
    required this.textColor,
    required this.subColor,
  });

  final List<(double, Color)> segments;
  final double strokeWidth;
  final String centerLabel;
  final String centerSubLabel;
  final Color textColor;
  final Color subColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    var start = -math.pi / 2;

    for (final (fraction, color) in segments) {
      if (fraction <= 0) continue;
      final sweep = fraction * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }

    _drawCenteredText(
      canvas,
      center,
      centerLabel,
      TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800),
      dy: -6,
    );
    _drawCenteredText(
      canvas,
      center,
      centerSubLabel,
      TextStyle(color: subColor, fontSize: 9),
      dy: 10,
    );
  }

  void _drawCenteredText(Canvas canvas, Offset center, String text, TextStyle style, {required double dy}) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 + dy));
  }

  @override
  bool shouldRepaint(covariant _AnalyticsDonutPainter old) => old.segments != segments;
}

class _GroupedBarPainter extends CustomPainter {
  _GroupedBarPainter({
    required this.bars,
    required this.maxValue,
    required this.labelColor,
    required this.valueColor,
  });

  final List<_BarGroup> bars;
  final double maxValue;
  final Color labelColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 36.0;
    const topPad = 16.0;
    final chartH = size.height - bottomPad - topPad;
    final groupW = size.width / bars.length;
    final barW = groupW * 0.45;

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final fraction = maxValue == 0 ? 0.0 : bar.value / maxValue;
      final h = chartH * fraction.clamp(0.0, 1.0);
      final cx = groupW * i + groupW / 2;
      final left = cx - barW / 2;
      final top = topPad + chartH - h;

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, barW, math.max(h, 4)), const Radius.circular(8)),
        Paint()..color = bar.color,
      );

      final valTp = TextPainter(
        text: TextSpan(
          text: '${bar.value}',
          style: TextStyle(color: valueColor, fontSize: 11, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupW);
      valTp.paint(canvas, Offset(cx - valTp.width / 2, top - 14));

      final labelTp = TextPainter(
        text: TextSpan(text: bar.label, style: TextStyle(color: labelColor, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupW);
      labelTp.paint(canvas, Offset(cx - labelTp.width / 2, size.height - bottomPad + 4));
    }

    canvas.drawLine(
      Offset(0, topPad + chartH),
      Offset(size.width, topPad + chartH),
      Paint()..color = labelColor.withValues(alpha: 0.25)..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _GroupedBarPainter old) => old.bars != bars || old.maxValue != maxValue;
}
