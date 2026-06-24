import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/budget_dashboard_models.dart';

class BudgetPieChart extends StatelessWidget {
  const BudgetPieChart({super.key, required this.slices});

  final List<BudgetPieSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.amountMinor);

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: total == 0
                ? Center(
                    child: Text('No spend data yet', style: context.eosText.bodyMedium),
                  )
                : CustomPaint(
                    painter: _BudgetPiePainter(
                      slices: slices,
                      total: total,
                      holeColor: context.eosCanvas,
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Wrap(
            spacing: context.eos.spacing.md,
            runSpacing: context.eos.spacing.sm,
            children: [
              for (final slice in slices)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(slice.colorArgb),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: context.eos.spacing.xs),
                    Text(slice.category.label, style: context.eosText.labelSmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetPiePainter extends CustomPainter {
  _BudgetPiePainter({
    required this.slices,
    required this.total,
    required this.holeColor,
  });

  final List<BudgetPieSlice> slices;
  final int total;
  final Color holeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final holeRadius = radius * 0.55;

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.amountMinor / total) * 2 * math.pi;
      final paint = Paint()
        ..color = Color(slice.colorArgb)
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }

    final holePaint = Paint()
      ..color = holeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, holeRadius, holePaint);
  }

  @override
  bool shouldRepaint(covariant _BudgetPiePainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}
