import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../super_admin_providers.dart';

class PlatformAnalyticsScreen extends ConsumerWidget {
  const PlatformAnalyticsScreen({super.key});

  static const ranges = ['7d', '30d', '90d', '365d'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(superAdminAnalyticsRangeProvider);
    final analytics = ref.watch(superAdminAnalyticsProvider(range));
    return EosPageScaffold(
      title: 'Platform analytics',
      subtitle: 'Growth KPIs across revenue, events, vendors, attendees',
      floatingHeader: SegmentedButton<String>(
        segments: ranges.map((r) => ButtonSegment(value: r, label: Text(r))).toList(),
        selected: {range},
        onSelectionChanged: (s) => ref.read(superAdminAnalyticsRangeProvider.notifier).state = s.first,
      ),
      body: analytics.when(
        data: (d) => Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.md,
          children: [
            _kpi(context, 'Revenue growth', '${d['revenueGrowth']}%', Icons.trending_up),
            _kpi(context, 'Event growth', '${d['eventGrowth']}%', Icons.celebration_outlined),
            _kpi(context, 'Vendor growth', '${d['vendorGrowth']}%', Icons.storefront_outlined),
            _kpi(context, 'Attendee growth', '${d['attendeeGrowth']}%', Icons.people_outline),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  Widget _kpi(BuildContext context, String title, String value, IconData icon) {
    return SizedBox(width: 220, child: EosKpiCard(title: title, value: value, icon: icon));
  }
}
