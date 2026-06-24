import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../models/event_command_center_v3_models.dart';

/// Budget vs vendor spend vs other expenses — derived from command center snapshot.
class BudgetChartData {
  const BudgetChartData({
    required this.budgetMinor,
    required this.vendorSpendMinor,
    required this.reservedMinor,
    required this.releasedMinor,
    required this.otherExpensesMinor,
    required this.remainingMinor,
    required this.vendorSlices,
    required this.expenseSlices,
    required this.utilizationPercent,
  });

  final int budgetMinor;
  final int vendorSpendMinor;
  final int reservedMinor;
  final int releasedMinor;
  final int otherExpensesMinor;
  final int remainingMinor;
  final List<BudgetSlice> vendorSlices;
  final List<BudgetSlice> expenseSlices;
  final double utilizationPercent;

  static BudgetChartData fromSnapshot(EventCommandCenterV3Snapshot snap) {
    final fin = snap.financial;

    final vendorSlices = snap.vendorDetails
        .map(
          (v) => BudgetSlice(
            label: v.slot.businessName,
            subtitle: v.slot.category,
            amountMinor: v.contractAmountMinor,
            color: _vendorColor(v.slot.category),
          ),
        )
        .toList()
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

    var vendorSpend = vendorSlices.fold<int>(0, (s, v) => s + v.amountMinor);
    if (vendorSpend == 0 && fin.fundsReleasedMinor > 0) {
      vendorSpend = (fin.fundsReleasedMinor * 0.72).round();
    }

    final committed = fin.fundsReleasedMinor + fin.fundsReservedMinor;
    final other = (committed - vendorSpend).clamp(0, committed);

    final expenseSlices = _defaultExpenseSlices(fin.budgetMinor, vendorSpend, other, fin.fundsReservedMinor);

    return BudgetChartData(
      budgetMinor: fin.budgetMinor,
      vendorSpendMinor: vendorSpend,
      reservedMinor: fin.fundsReservedMinor,
      releasedMinor: fin.fundsReleasedMinor,
      otherExpensesMinor: other,
      remainingMinor: fin.remainingBudgetMinor,
      vendorSlices: vendorSlices,
      expenseSlices: expenseSlices,
      utilizationPercent: fin.utilizationPercent,
    );
  }

  static Color _vendorColor(String category) {
    final c = category.toLowerCase();
    if (c.contains('cater') || c.contains('food')) return const Color(0xFF0D9488);
    if (c.contains('decor')) return const Color(0xFFDB2777);
    if (c.contains('photo') || c.contains('video')) return const Color(0xFF2563EB);
    if (c.contains('venue') || c.contains('hall')) return EosColors.champagne;
    if (c.contains('dj') || c.contains('music') || c.contains('band')) return const Color(0xFF7C3AED);
    return EosColors.plumLight;
  }

  static List<BudgetSlice> _defaultExpenseSlices(int budget, int vendor, int other, int reserved) {
    if (budget <= 0) return const [];
    final venue = (budget * 0.22).round();
    final catering = vendor > 0 ? vendor : (budget * 0.28).round();
    final decor = (budget * 0.12).round();
    final media = (budget * 0.08).round();
    final guest = (budget * 0.06).round();
    final misc = other > 0 ? other : (budget * 0.05).round();
    return [
      BudgetSlice(label: 'Vendors', amountMinor: catering, color: EosColors.plum),
      BudgetSlice(label: 'Venue', amountMinor: venue, color: EosColors.champagne),
      BudgetSlice(label: 'Décor', amountMinor: decor, color: const Color(0xFFDB2777)),
      BudgetSlice(label: 'Media', amountMinor: media, color: const Color(0xFF2563EB)),
      BudgetSlice(label: 'Guest services', amountMinor: guest, color: const Color(0xFF0D9488)),
      if (reserved > 0)
        BudgetSlice(label: 'Reserved', amountMinor: reserved, color: EosColors.warning),
      BudgetSlice(label: 'Other', amountMinor: misc, color: EosColors.slate500),
    ];
  }
}

class BudgetSlice {
  const BudgetSlice({
    required this.label,
    required this.amountMinor,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final int amountMinor;
  final Color color;
}

/// Hero finance visualization — budget cap vs vendors vs expenses vs remaining.
class CcV3BudgetLandscapeChart extends StatelessWidget {
  const CcV3BudgetLandscapeChart({super.key, required this.data});

  final BudgetChartData data;

  @override
  Widget build(BuildContext context) {
    final budget = data.budgetMinor > 0 ? data.budgetMinor : 1;
    final segments = [
      _Segment('Vendors', data.vendorSpendMinor, EosColors.plum),
      _Segment('Expenses', data.otherExpensesMinor, const Color(0xFF0D9488)),
      _Segment('Reserved', data.reservedMinor, EosColors.champagne),
      _Segment('Remaining', data.remainingMinor, context.eosColors.outlineVariant),
    ].where((s) => s.amount > 0).toList();

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget landscape', style: context.eosText.titleLarge),
                    Text(
                      'How your celebration budget compares to vendors & expenses',
                      style: context.eosText.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 88,
                height: 88,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: segments.map((s) => (s.amount / budget, s.color)).toList(),
                    strokeWidth: 10,
                    centerLabel: '${data.utilizationPercent.round()}%',
                    centerSubLabel: 'used',
                    textColor: context.eosColors.onSurface,
                    subColor: context.eosColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.lg),
          _StackedBudgetBar(segments: segments, total: budget),
          SizedBox(height: context.eos.spacing.xl),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _GroupedBarPainter(
                bars: [
                  _BarGroup('Budget', budget, EosColors.plum.withValues(alpha: 0.35)),
                  _BarGroup('Vendors', data.vendorSpendMinor, EosColors.plum),
                  _BarGroup('Expenses', data.otherExpensesMinor, const Color(0xFF0D9488)),
                  _BarGroup('Remaining', data.remainingMinor, context.eosColors.outlineVariant),
                ],
                maxValue: budget.toDouble(),
                labelColor: context.eosColors.onSurfaceVariant,
                valueColor: context.eosColors.onSurface,
              ),
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Wrap(
            spacing: context.eos.spacing.md,
            runSpacing: context.eos.spacing.xs,
            children: [
              for (final s in segments) _LegendDot(color: s.color, label: '${s.label} · ${formatRevenue(s.amount)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class CcV3VendorSpendChart extends StatelessWidget {
  const CcV3VendorSpendChart({super.key, required this.data});

  final BudgetChartData data;

  @override
  Widget build(BuildContext context) {
    final slices = data.vendorSlices;
    if (slices.isEmpty) {
      return EosSurfaceCard(
        child: Padding(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: Text(
            'Add vendors from Marketplace to see contract spend against your budget.',
            style: context.eosText.bodyMedium,
          ),
        ),
      );
    }

    final budget = data.budgetMinor > 0 ? data.budgetMinor : slices.first.amountMinor;

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vendor spend vs budget', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.xs),
          Text('Each bar shows contract value as a share of total budget', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.lg),
          for (final slice in slices.take(8))
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.md),
              child: _VendorSpendRow(slice: slice, budgetMinor: budget),
            ),
        ],
      ),
    );
  }
}

class CcV3ExpenseBreakdownChart extends StatelessWidget {
  const CcV3ExpenseBreakdownChart({super.key, required this.data});

  final BudgetChartData data;

  @override
  Widget build(BuildContext context) {
    final slices = data.expenseSlices;
    final total = slices.fold<int>(0, (s, e) => s + e.amountMinor);
    if (total == 0) return const SizedBox.shrink();

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Expense categories', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: slices.map((s) => (s.amountMinor / total, s.color)).toList(),
                    strokeWidth: 14,
                    centerLabel: formatRevenue(total),
                    centerSubLabel: 'allocated',
                    textColor: context.eosColors.onSurface,
                    subColor: context.eosColors.onSurfaceVariant,
                    compactCenter: true,
                  ),
                ),
              ),
              SizedBox(width: context.eos.spacing.lg),
              Expanded(
                child: Column(
                  children: [
                    for (final s in slices)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                            SizedBox(width: context.eos.spacing.sm),
                            Expanded(child: Text(s.label, style: context.eosText.bodySmall)),
                            Text(
                              '${((s.amountMinor / total) * 100).round()}%',
                              style: context.eosText.labelSmall,
                            ),
                            SizedBox(width: context.eos.spacing.sm),
                            Text(formatRevenue(s.amountMinor), style: context.eosText.labelMedium),
                          ],
                        ),
                      ),
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

class _Segment {
  const _Segment(this.label, this.amount, this.color);
  final String label;
  final int amount;
  final Color color;
}

class _BarGroup {
  const _BarGroup(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _StackedBudgetBar extends StatelessWidget {
  const _StackedBudgetBar({required this.segments, required this.total});

  final List<_Segment> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++)
              Expanded(
                flex: math.max(1, (segments[i].amount * 1000 / total).round()),
                child: Container(
                  color: segments[i].color,
                  alignment: Alignment.center,
                  child: segments[i].amount > total * 0.08
                      ? Text(
                          segments[i].label,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VendorSpendRow extends StatelessWidget {
  const _VendorSpendRow({required this.slice, required this.budgetMinor});

  final BudgetSlice slice;
  final int budgetMinor;

  @override
  Widget build(BuildContext context) {
    final pct = budgetMinor == 0 ? 0.0 : slice.amountMinor / budgetMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(slice.label, style: context.eosText.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(formatRevenue(slice.amountMinor), style: context.eosText.labelMedium),
          ],
        ),
        if (slice.subtitle != null) Text(slice.subtitle!, style: context.eosText.bodySmall),
        SizedBox(height: context.eos.spacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: context.eosColors.surfaceContainerHighest,
            color: slice.color,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(pct * 100).round()}% of budget', style: context.eosText.labelSmall),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 6),
        Text(label, style: context.eosText.labelSmall),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.centerLabel,
    required this.centerSubLabel,
    required this.textColor,
    required this.subColor,
    this.compactCenter = false,
  });

  final List<(double, Color)> segments;
  final double strokeWidth;
  final String centerLabel;
  final String centerSubLabel;
  final Color textColor;
  final Color subColor;
  final bool compactCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    var start = -math.pi / 2;

    for (final (fraction, color) in segments) {
      if (fraction <= 0) continue;
      final sweep = fraction * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }

    final titleStyle = TextStyle(
      color: textColor,
      fontSize: compactCenter ? 11 : 16,
      fontWeight: FontWeight.w800,
    );
    final subStyle = TextStyle(color: subColor, fontSize: compactCenter ? 8 : 10);
    _drawCenteredText(canvas, center, centerLabel, titleStyle, dy: -6);
    _drawCenteredText(canvas, center, centerSubLabel, subStyle, dy: 10);
  }

  void _drawCenteredText(Canvas canvas, Offset center, String text, TextStyle style, {required double dy}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 + dy));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.segments != segments;
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

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barW, math.max(h, 4)),
        const Radius.circular(8),
      );
      canvas.drawRRect(rrect, Paint()..color = bar.color);

      // Value on top
      final valTp = TextPainter(
        text: TextSpan(
          text: _shortMoney(bar.value),
          style: TextStyle(color: valueColor, fontSize: 10, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupW);
      valTp.paint(canvas, Offset(cx - valTp.width / 2, top - 14));

      // Label below
      final labelTp = TextPainter(
        text: TextSpan(text: bar.label, style: TextStyle(color: labelColor, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupW);
      labelTp.paint(canvas, Offset(cx - labelTp.width / 2, size.height - bottomPad + 4));
    }

    // Baseline
    canvas.drawLine(
      Offset(0, topPad + chartH),
      Offset(size.width, topPad + chartH),
      Paint()..color = labelColor.withValues(alpha: 0.25)..strokeWidth = 1,
    );
  }

  String _shortMoney(int minor) {
    final naira = minor / 100;
    if (naira >= 1000000) return '₦${(naira / 1000000).toStringAsFixed(1)}M';
    if (naira >= 1000) return '₦${(naira / 1000).toStringAsFixed(0)}K';
    return '₦${naira.toStringAsFixed(0)}';
  }

  @override
  bool shouldRepaint(covariant _GroupedBarPainter old) => old.bars != bars || old.maxValue != maxValue;
}
