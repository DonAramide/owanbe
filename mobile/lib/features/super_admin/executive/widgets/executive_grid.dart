import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

/// 12-column executive grid for Control Tower dashboards.
class ExecutiveGrid extends StatelessWidget {
  const ExecutiveGrid({super.key, required this.children});

  final List<ExecutiveGridItem> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= EosBreakpoints.desktop ? 12 : constraints.maxWidth >= EosBreakpoints.tablet ? 6 : 1;
        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final c in children) Padding(padding: EdgeInsets.only(bottom: context.eos.spacing.md), child: c.child)],
          );
        }

        final rows = <List<ExecutiveGridItem>>[];
        var current = <ExecutiveGridItem>[];
        var used = 0;
        for (final item in children) {
          final span = cols == 6 ? (item.span / 2).ceil().clamp(1, 6) : item.span.clamp(1, 12);
          if (used + span > cols) {
            rows.add(current);
            current = [];
            used = 0;
          }
          current.add(ExecutiveGridItem(span: span, child: item.child));
          used += span;
          if (used >= cols) {
            rows.add(current);
            current = [];
            used = 0;
          }
        }
        if (current.isNotEmpty) rows.add(current);

        return Column(
          children: [
            for (final row in rows) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in row) ...[
                      Expanded(
                        flex: item.span,
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: context.eos.spacing.md,
                            bottom: context.eos.spacing.md,
                          ),
                          child: item.child,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class ExecutiveGridItem {
  const ExecutiveGridItem({required this.span, required this.child});
  final int span;
  final Widget child;
}

class ExecutiveAnimatedMetric extends StatelessWidget {
  const ExecutiveAnimatedMetric({super.key, required this.value, this.style});

  final num value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        v >= 1000000 ? '${(v / 1000000).toStringAsFixed(1)}M' : v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1),
        style: style ?? EosTypography.metric(context.eosColors),
      ),
    );
  }
}

class ExecutiveSkeleton extends StatelessWidget {
  const ExecutiveSkeleton({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              width: 120,
              decoration: BoxDecoration(
                color: context.eosColors.surfaceContainerHighest,
                borderRadius: context.eos.radius.chip,
              ),
            ),
            SizedBox(height: context.eos.spacing.md),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.eosColors.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: context.eos.radius.card,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
