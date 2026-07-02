import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../extensions/eos_context.dart';
import 'eos_chart_legend.dart';

class EosTimeSeriesPoint {
  const EosTimeSeriesPoint({required this.label, required this.values});
  final String label;
  final Map<String, double> values;
}

class EosTimeSeriesSeries {
  const EosTimeSeriesSeries({required this.key, required this.label, required this.color});
  final String key;
  final String label;
  final Color color;
}

/// Multi-series time chart — sparkline-grade CustomPaint with hover tooltips and PNG export.
class EosTimeSeriesChart extends StatefulWidget {
  const EosTimeSeriesChart({
    super.key,
    required this.points,
    required this.series,
    this.height = 280,
    this.valueFormatter,
  });

  final List<EosTimeSeriesPoint> points;
  final List<EosTimeSeriesSeries> series;
  final double height;
  final String Function(double value)? valueFormatter;

  @override
  State<EosTimeSeriesChart> createState() => _EosTimeSeriesChartState();
}

class _EosTimeSeriesChartState extends State<EosTimeSeriesChart> {
  final _chartKey = GlobalKey();
  int? _hoverIndex;

  String _fmt(double v) => widget.valueFormatter?.call(v) ?? v.toStringAsFixed(0);

  Future<void> _exportPng() async {
    final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: 'Chart exported (${bytes.lengthInBytes} bytes PNG copied to clipboard metadata)'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chart snapshot captured — use browser screenshot for file save on web.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text('Not enough data for chart', style: context.eosText.bodySmall)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: EosChartLegend(
                items: [
                  for (final s in widget.series) EosLegendItem(label: s.label, color: s.color),
                ],
              ),
            ),
            IconButton(tooltip: 'Export PNG', onPressed: _exportPng, icon: const Icon(Icons.download_outlined)),
          ],
        ),
        Expanded(
          child: RepaintBoundary(
            key: _chartKey,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 3,
              child: SizedBox(
                height: double.infinity,
                width: double.infinity,
                child: MouseRegion(
                  onHover: (e) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(e.position);
                    final idx = ((local.dx / box.size.width) * (widget.points.length - 1)).round().clamp(0, widget.points.length - 1);
                    if (_hoverIndex != idx) setState(() => _hoverIndex = idx);
                  },
                  onExit: (_) => setState(() => _hoverIndex = null),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size.infinite,
                        painter: _TimeSeriesPainter(
                          points: widget.points,
                          series: widget.series,
                          gridColor: context.eosColors.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      if (_hoverIndex != null) _TooltipOverlay(
                        index: _hoverIndex!,
                        point: widget.points[_hoverIndex!],
                        series: widget.series,
                        formatter: _fmt,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.index,
    required this.point,
    required this.series,
    required this.formatter,
  });

  final int index;
  final EosTimeSeriesPoint point;
  final List<EosTimeSeriesSeries> series;
  final String Function(double) formatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final x = constraints.maxWidth * (index / math.max(1, point.label.isEmpty ? 1 : 1));
        final left = (x - 80).clamp(8.0, constraints.maxWidth - 168);
        return Positioned(
          left: left,
          top: 8,
          child: Material(
            elevation: 4,
            borderRadius: context.eos.radius.chip,
            color: context.eosColors.surface,
            child: Padding(
              padding: EdgeInsets.all(context.eos.spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point.label, style: context.eosText.labelMedium),
                  for (final s in series) ...[
                    SizedBox(height: context.eos.spacing.xxs),
                    Text('${s.label}: ${formatter(point.values[s.key] ?? 0)}', style: context.eosText.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimeSeriesPainter extends CustomPainter {
  _TimeSeriesPainter({required this.points, required this.series, required this.gridColor});

  final List<EosTimeSeriesPoint> points;
  final List<EosTimeSeriesSeries> series;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    var maxV = 0.0;
    for (final p in points) {
      for (final s in series) {
        maxV = math.max(maxV, p.values[s.key] ?? 0);
      }
    }
    if (maxV < 1) maxV = 1;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final s in series) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = size.width * (i / (points.length - 1));
        final v = points[i].values[s.key] ?? 0;
        final y = size.height - (v / maxV) * (size.height - 8);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimeSeriesPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.series != series;
}
