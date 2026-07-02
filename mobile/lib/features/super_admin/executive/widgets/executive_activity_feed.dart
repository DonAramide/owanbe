import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../super_admin_providers.dart';
import '../models/executive_dashboard_models.dart';

class ExecutiveActivityFeed extends ConsumerStatefulWidget {
  const ExecutiveActivityFeed({super.key, required this.items});

  final List<ExecutiveActivityItem> items;

  @override
  ConsumerState<ExecutiveActivityFeed> createState() => _ExecutiveActivityFeedState();
}

class _ExecutiveActivityFeedState extends ConsumerState<ExecutiveActivityFeed> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Live platform activity', style: context.eosText.titleLarge),
              const Spacer(),
              const EosLiveIndicator(),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          SizedBox(
            height: 360,
            child: ListView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              itemBuilder: (context, i) {
                final item = widget.items[i];
                return EosFeedItem(
                  title: item.title,
                  subtitle: item.subtitle,
                  timestamp: _timeAgo(item.timestamp),
                  leading: _severityDot(item.severity),
                  onTap: () => ref.read(superAdminShellTabProvider.notifier).select(item.tabIndex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _severityDot(String severity) {
    final color = switch (severity.toLowerCase()) {
      'critical' => EosColors.critical,
      'warning' => EosColors.warning,
      _ => EosColors.info,
    };
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  String _timeAgo(DateTime ts) {
    final d = DateTime.now().difference(ts);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
