import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/operations_models.dart';
import '../providers/operations_providers.dart';
import '../widgets/operations_shared.dart';

class EventCommandCenterScreen extends ConsumerWidget {
  const EventCommandCenterScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(operationsKpisProvider(eventId));
    final health = ref.watch(operationsHealthProvider(eventId));
    final feed = ref.watch(operationsFeedProvider(eventId));
    final vendors = ref.watch(operationsVendorsProvider(eventId));
    final incidents = ref.watch(operationsIncidentsProvider(eventId));
    final guests = ref.watch(operationsGuestsProvider(eventId));

    return EosPageScaffold(
      title: 'Event command center',
      subtitle: 'Mission control for live operations',
      floatingHeader: const Row(
        children: [
          EosLiveIndicator(label: 'LIVE OPS'),
          SizedBox(width: 12),
          EosStatusPulse(color: EosColors.live, size: 10),
        ],
      ),
      body: EosResponsive(
        mobile: _CommandGrid(
          kpis: kpis,
          health: health,
          feed: feed,
          vendors: vendors,
          incidents: incidents,
          guests: guests,
          columns: 1,
        ),
        tablet: _CommandGrid(
          kpis: kpis,
          health: health,
          feed: feed,
          vendors: vendors,
          incidents: incidents,
          guests: guests,
          columns: 2,
        ),
        desktop: _CommandGrid(
          kpis: kpis,
          health: health,
          feed: feed,
          vendors: vendors,
          incidents: incidents,
          guests: guests,
          columns: 3,
        ),
      ),
    );
  }
}

class _CommandGrid extends StatelessWidget {
  const _CommandGrid({
    required this.kpis,
    required this.health,
    required this.feed,
    required this.vendors,
    required this.incidents,
    required this.guests,
    required this.columns,
  });

  final AsyncValue<LiveEventKpis> kpis;
  final AsyncValue<EventHealthSnapshot> health;
  final AsyncValue<List<OpsFeedEvent>> feed;
  final AsyncValue<List<VendorOpsSnapshot>> vendors;
  final AsyncValue<List<OpsIncident>> incidents;
  final AsyncValue<List<OpsGuest>> guests;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kpis.when(
          data: (k) => Wrap(
            spacing: context.eos.spacing.sm,
            runSpacing: context.eos.spacing.sm,
            children: [
              SizedBox(
                width: 160,
                child: EosKpiCard(title: 'Checked in', value: '${k.checkedIn}', icon: Icons.qr_code_scanner),
              ),
              SizedBox(
                width: 160,
                child: EosKpiCard(title: 'Remaining', value: '${k.remainingGuests}', icon: Icons.people_outline),
              ),
              SizedBox(
                width: 160,
                child: EosKpiCard(
                  title: 'Revenue',
                  value: formatOpsMoney(k.revenueTodayMinor),
                  icon: Icons.payments_outlined,
                ),
              ),
              SizedBox(
                width: 160,
                child: EosKpiCard(
                  title: 'Incidents',
                  value: '${k.openIncidents}',
                  attention: k.openIncidents > 0 ? EosKpiAttention.critical : EosKpiAttention.none,
                  icon: Icons.report_problem_outlined,
                ),
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        SizedBox(height: context.eos.spacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (columns - 1) * context.eos.spacing.md) / columns;
            return Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                SizedBox(
                  width: width,
                  child: _attendancePanel(context, guests),
                ),
                SizedBox(
                  width: width,
                  child: _vendorPanel(context, vendors),
                ),
                SizedBox(
                  width: width,
                  child: _feedPanel(context, feed),
                ),
                SizedBox(
                  width: width,
                  child: _incidentPanel(context, incidents),
                ),
                SizedBox(
                  width: width,
                  child: health.when(
                    data: (h) => EosSurfaceCard(
                      elevated: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Operational alerts', style: context.eosText.titleSmall),
                          SizedBox(height: context.eos.spacing.sm),
                          EventHealthBadge(level: h.level),
                          SizedBox(height: context.eos.spacing.sm),
                          Text(h.summary, style: context.eosText.bodySmall),
                        ],
                      ),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('$e'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _timelinePanel(context, feed),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _attendancePanel(BuildContext context, AsyncValue<List<OpsGuest>> data) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live attendance', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          data.when(
            data: (items) {
              final checked = items.where((g) => g.checkedIn).length;
              return Text('$checked / ${items.length} checked in', style: context.eosText.headlineSmall);
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }

  Widget _vendorPanel(BuildContext context, AsyncValue<List<VendorOpsSnapshot>> data) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vendor activity', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          data.when(
            data: (items) {
              final active = items.where((v) => v.status == VendorOpsStatus.active).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$active active', style: context.eosText.headlineSmall),
                  for (final v in items.take(3))
                    Text(v.businessName, style: context.eosText.bodySmall),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }

  Widget _feedPanel(BuildContext context, AsyncValue<List<OpsFeedEvent>> data) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue feed', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          data.when(
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items.where((i) => i.type == FeedEventType.orderPlaced).take(4))
                  Text(item.headline, style: context.eosText.bodySmall),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }

  Widget _incidentPanel(BuildContext context, AsyncValue<List<OpsIncident>> data) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incidents', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          data.when(
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final inc in items.take(4))
                  Text('${inc.priority.name}: ${inc.title}', style: context.eosText.bodySmall),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }

  Widget _timelinePanel(BuildContext context, AsyncValue<List<OpsFeedEvent>> data) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timeline', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          data.when(
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items.take(6))
                  Text(
                    '${formatOpsTime(item.timestamp)} · ${item.headline}',
                    style: context.eosText.bodySmall,
                  ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }
}
