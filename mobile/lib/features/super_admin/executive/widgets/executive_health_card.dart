import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../models/executive_dashboard_models.dart';

class ExecutiveHealthCard extends StatelessWidget {
  const ExecutiveHealthCard({
    super.key,
    required this.status,
    required this.score,
    required this.summary,
    required this.subsystems,
    required this.onSubsystemTap,
  });

  final PlatformStatus status;
  final int score;
  final String summary;
  final List<SubsystemHealth> subsystems;
  final ValueChanged<SubsystemHealth> onSubsystemTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (status) {
      PlatformStatus.healthy => 'Healthy',
      PlatformStatus.warning => 'Warning',
      PlatformStatus.critical => 'Critical',
    };
    final severity = switch (status) {
      PlatformStatus.critical => 'CRITICAL',
      PlatformStatus.warning => 'WARNING',
      PlatformStatus.healthy => 'INFO',
    };

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global platform health', style: context.eosText.titleLarge),
                    SizedBox(height: context.eos.spacing.xs),
                    EosAttentionBanner(
                      headline: 'Overall: $statusLabel',
                      message: summary,
                      severity: severity,
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.eos.spacing.lg),
              _ScoreRing(score: score, status: status),
            ],
          ),
          SizedBox(height: context.eos.spacing.lg),
          Wrap(
            spacing: context.eos.spacing.sm,
            runSpacing: context.eos.spacing.sm,
            children: [
              for (final s in subsystems) _SubsystemChip(subsystem: s, onTap: () => onSubsystemTap(s)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.status});
  final int score;
  final PlatformStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PlatformStatus.critical => EosColors.critical,
      PlatformStatus.warning => EosColors.warning,
      PlatformStatus.healthy => EosColors.success,
    };
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: context.eosText.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
              Text('Health', style: context.eosText.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubsystemChip extends StatelessWidget {
  const _SubsystemChip({required this.subsystem, required this.onTap});
  final SubsystemHealth subsystem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (subsystem.status) {
      'critical' => EosColors.critical,
      'degraded' => EosColors.warning,
      _ => EosColors.success,
    };
    final trendIcon = switch (subsystem.trend) {
      SubsystemTrend.up => Icons.trending_up,
      SubsystemTrend.down => Icons.trending_down,
      SubsystemTrend.stable => Icons.trending_flat,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.eos.radius.card,
        child: Container(
          width: 168,
          padding: EdgeInsets.all(context.eos.spacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: context.eosColors.outlineVariant),
            borderRadius: context.eos.radius.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(subsystem.label, style: context.eosText.labelLarge)),
                  Icon(trendIcon, size: 14, color: color),
                ],
              ),
              SizedBox(height: context.eos.spacing.xxs),
              EosFinanceChip(label: subsystem.status, compact: true),
              SizedBox(height: context.eos.spacing.xxs),
              Text('${subsystem.responseMs}ms', style: context.eosText.bodySmall),
              Text(_timeAgo(subsystem.lastCheck), style: context.eosText.labelSmall),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}

void showSubsystemDetailDrawer(BuildContext context, SubsystemHealth subsystem) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(ctx.eos.spacing.lg, 0, ctx.eos.spacing.lg, ctx.eos.spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subsystem.label, style: ctx.eosText.headlineSmall),
          SizedBox(height: ctx.eos.spacing.md),
          _detailRow(ctx, 'Status', subsystem.status),
          _detailRow(ctx, 'Response time', '${subsystem.responseMs} ms'),
          _detailRow(ctx, 'Last check', subsystem.lastCheck.toLocal().toString()),
          _detailRow(ctx, 'Trend', subsystem.trend.name),
          SizedBox(height: ctx.eos.spacing.sm),
          Text(subsystem.detail, style: ctx.eosText.bodyMedium),
        ],
      ),
    ),
  );
}

Widget _detailRow(BuildContext context, String label, String value) {
  return Padding(
    padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(label, style: context.eosText.labelMedium)),
        Expanded(child: Text(value, style: context.eosText.bodyMedium)),
      ],
    ),
  );
}
