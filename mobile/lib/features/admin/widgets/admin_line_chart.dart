import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

class AdminLineChart extends StatelessWidget {
  const AdminLineChart({
    super.key,
    required this.points,
    required this.label,
    this.height = 220,
    this.color,
  });

  final List<double> points;
  final String label;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? context.eosColors.primary;

    return EosSurfaceCard(
      elevated: true,
      padding: const EdgeInsets.all(EosSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: context.eos.spacing.md),
          SizedBox(
            height: height,
            width: double.infinity,
            child: points.length < 2
                ? Center(child: Text('Not enough data', style: context.eosText.bodyMedium))
                : CustomPaint(
                    painter: _AdminLinePainter(points: points, color: lineColor),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminLinePainter extends CustomPainter {
  _AdminLinePainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = points.reduce(math.max);
    final minVal = points.reduce(math.min);
    final range = (maxVal - minVal).abs() < 1 ? 1.0 : maxVal - minVal;
    final dx = size.width / (points.length - 1);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - ((points[i] - minVal) / range) * (size.height - 16) - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AdminLinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

List<double> syntheticTrend(num seed, {int points = 7}) {
  final base = seed.toDouble().clamp(1, double.infinity);
  return List.generate(points, (i) => base * (0.55 + i * 0.08 + (i.isEven ? 0.03 : 0)));
}
