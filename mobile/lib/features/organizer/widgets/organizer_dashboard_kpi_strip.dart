import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/organizer_providers.dart';
import 'organizer_shared.dart' show formatRevenue;

/// KPI strip backed by [organizerDashboardStatsProvider] — reusable on hub or dashboard.
class OrganizerDashboardKpiStrip extends ConsumerWidget {
  const OrganizerDashboardKpiStrip({
    super.key,
    this.onEventsTap,
    this.onTicketsTap,
    this.onVendorsTap,
    this.onAttendeesTap,
    this.onAnalyticsTap,
  });

  final VoidCallback? onEventsTap;
  final VoidCallback? onTicketsTap;
  final VoidCallback? onVendorsTap;
  final VoidCallback? onAttendeesTap;
  final VoidCallback? onAnalyticsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(organizerDashboardStatsProvider);

    return stats.when(
      loading: () => const _KpiSkeletonRow(),
      error: (e, _) => EosSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Could not load dashboard metrics', style: context.eosText.titleSmall),
            SizedBox(height: context.eos.spacing.xs),
            Text('$e', style: context.eosText.bodySmall),
            SizedBox(height: context.eos.spacing.sm),
            OutlinedButton(
              onPressed: () => ref.invalidate(organizerDashboardStatsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (s) => EosAdaptiveKpiGrid(
        children: [
          _kpi(context, 'Active', '${s.activeEvents}', Icons.celebration_outlined, onEventsTap,
              subtitle: 'Published + live'),
          _kpi(context, 'Drafts', '${s.draftEvents}', Icons.edit_note_outlined, onEventsTap),
          _kpi(context, 'Upcoming', '${s.upcomingEvents}', Icons.event_outlined, onEventsTap,
              subtitle: 'Future start dates'),
          _kpi(context, 'Live', '${s.liveEvents}', Icons.sensors_outlined, onEventsTap),
          _kpi(context, 'Completed', '${s.completedEvents}', Icons.check_circle_outline, onEventsTap),
          _kpi(context, 'Tickets', '${s.ticketsSold}', Icons.confirmation_number_outlined, onTicketsTap),
          EosKpiCard(
            title: 'Revenue',
            value: formatRevenue(s.revenueMinor),
            icon: Icons.payments_outlined,
            attention: s.revenueMinor > 0 ? EosKpiAttention.info : EosKpiAttention.none,
            actionLabel: onAnalyticsTap != null ? 'View analytics' : null,
            onTap: onAnalyticsTap,
          ),
          _kpi(context, 'Registrations', '${s.registrations}', Icons.how_to_reg_outlined, onAttendeesTap),
          _kpi(context, 'Check-ins', '${s.checkIns}', Icons.qr_code_scanner_outlined, onAttendeesTap),
          _kpi(context, 'Vendors', '${s.vendorCount}', Icons.storefront_outlined, onVendorsTap),
          _kpi(context, 'Attendees', '${s.attendeeCount}', Icons.people_outline, onAttendeesTap),
        ],
      ),
    );
  }

  Widget _kpi(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    VoidCallback? onTap, {
    String? subtitle,
  }) {
    return EosKpiCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      attention: EosKpiAttention.none,
      actionLabel: onTap != null ? 'View' : null,
      onTap: onTap,
    );
  }
}

class _KpiSkeletonRow extends StatelessWidget {
  const _KpiSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return EosAdaptiveKpiGrid(
      children: List.generate(
        6,
        (_) => SizedBox(
          height: 96,
          child: EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.eosColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 48,
                  height: 20,
                  decoration: BoxDecoration(
                    color: context.eosColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
