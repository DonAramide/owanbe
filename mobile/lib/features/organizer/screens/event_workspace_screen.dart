import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../operations/data/operations_store.dart';
import '../../operations/providers/operations_providers.dart';
import '../data/organizer_event_store.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

const _workspaceTabs = [
  'Overview',
  'Tickets',
  'Attendees',
  'Vendors',
  'Finance',
  'Operations',
  'Analytics',
  'Settings',
];

class EventWorkspaceScreen extends ConsumerStatefulWidget {
  const EventWorkspaceScreen({super.key, required this.eventId, this.initialTab = 0});

  final String eventId;
  final int initialTab;

  @override
  ConsumerState<EventWorkspaceScreen> createState() => _EventWorkspaceScreenState();
}

class _EventWorkspaceScreenState extends ConsumerState<EventWorkspaceScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _workspaceTabs.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedOrganizerEventIdProvider.notifier).state = widget.eventId;
      ref.read(eventWorkspaceTabProvider.notifier).state = _tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(organizerEventProvider(widget.eventId));

    return Scaffold(
      backgroundColor: EosColors.canvas,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/organizer')),
        title: eventAsync.when(
          data: (e) => Text(e?.title ?? 'Event workspace'),
          loading: () => const Text('Event workspace'),
          error: (_, _) => const Text('Event workspace'),
        ),
        actions: [
          eventAsync.whenOrNull(
            data: (e) {
              if (e == null) return null;
              return Row(
                children: [
                  EosFinanceChip(label: organizerStatusLabel(e.status)),
                  if (e.status == OrganizerEventStatus.live) ...[
                    SizedBox(width: context.eos.spacing.xs),
                    const EosLiveIndicator(compact: true),
                  ],
                  SizedBox(width: context.eos.spacing.sm),
                ],
              );
            },
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) return const Center(child: Text('Event not found'));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.eos.spacing.lg,
                  context.eos.spacing.md,
                  context.eos.spacing.lg,
                  0,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _workspaceTabs.length; i++)
                        Padding(
                          padding: EdgeInsets.only(right: context.eos.spacing.xs),
                          child: FilterChip(
                            label: Text(_workspaceTabs[i]),
                            selected: _tab == i,
                            onSelected: (_) {
                              setState(() => _tab = i);
                              ref.read(eventWorkspaceTabProvider.notifier).state = i;
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _tabBody(context, ref, event)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _tabBody(BuildContext context, WidgetRef ref, OrganizerEvent event) {
    return switch (_tab) {
      0 => _OverviewTab(event: event, ref: ref),
      1 => _TicketsTab(event: event),
      2 => _AttendeesTab(event: event),
      3 => _VendorsTab(event: event, ref: ref),
      4 => _FinanceTab(event: event),
      5 => _OperationsTab(event: event, ref: ref),
      6 => _AnalyticsTab(eventId: event.id),
      _ => _SettingsTab(event: event, ref: ref),
    };
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.event, required this.ref});
  final OrganizerEvent event;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.tagline, style: context.eosText.bodyLarge),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            '${event.venueType.name} · ${event.city} · ${event.venue}',
            style: context.eosText.bodySmall,
          ),
          Text(formatEventDateRange(event.startsAt, event.endsAt), style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.lg),
          Wrap(
            spacing: context.eos.spacing.md,
            runSpacing: context.eos.spacing.md,
            children: [
              SizedBox(
                width: 200,
                child: EosKpiCard(
                  title: 'Tickets sold',
                  value: '${event.ticketsSold}',
                  subtitle: 'of ${event.totalCapacity}',
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              SizedBox(
                width: 200,
                child: EosKpiCard(
                  title: 'Revenue',
                  value: formatRevenue(event.revenueMinor),
                  icon: Icons.payments_outlined,
                ),
              ),
              SizedBox(
                width: 200,
                child: EosKpiCard(
                  title: 'Vendors',
                  value: '${event.vendors.length}',
                  icon: Icons.storefront_outlined,
                ),
              ),
              SizedBox(
                width: 200,
                child: EosKpiCard(
                  title: 'Attendees',
                  value: '${event.attendees.length}',
                  icon: Icons.people_outline,
                ),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.lg),
          Wrap(
            spacing: context.eos.spacing.xs,
            children: [
              if (event.status == OrganizerEventStatus.draft)
                FilledButton(
                  onPressed: () {
                    OrganizerEventStore.instance.publish(event.id);
                    bumpOrganizerRevision(ref);
                  },
                  child: const Text('Publish event'),
                ),
              if (event.status == OrganizerEventStatus.published)
                FilledButton(
                  onPressed: () {
                    OrganizerEventStore.instance.setLive(event.id);
                    OperationsStore.instance.ensureLive(event.id);
                    bumpOrganizerRevision(ref);
                    bumpOperationsRevision(ref);
                    ref.read(liveOpsEventIdProvider.notifier).state = event.id;
                    ref.read(organizerShellTabProvider.notifier).select(6);
                    context.go('/organizer');
                  },
                  child: const Text('Go live'),
                ),
              if (event.refundRequests > 0)
                EosAttentionBanner(
                  headline: '${event.refundRequests} refund request(s)',
                  message: 'Review in Finance tab (mock)',
                  severity: 'CRITICAL',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketsTab extends ConsumerStatefulWidget {
  const _TicketsTab({required this.event});
  final OrganizerEvent event;

  @override
  ConsumerState<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends ConsumerState<_TicketsTab> {
  @override
  Widget build(BuildContext context) {
    final event = ref.watch(organizerEventProvider(widget.event.id)).value ?? widget.event;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Ticket tiers', style: context.eosText.titleLarge)),
              FilledButton.icon(
                onPressed: () => _showTierDialog(context, event.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add tier'),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          EosDataTable(
            columns: const [
              DataColumn(label: Text('Tier')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Sold')),
              DataColumn(label: Text('Window')),
              DataColumn(label: Text('Visibility')),
              DataColumn(label: Text('')),
            ],
            rows: event.ticketTiers.map((t) {
              final sold = t.capacity - t.remaining;
              final window = t.salesWindowStart == null
                  ? 'Open'
                  : '${t.salesWindowStart!.month}/${t.salesWindowStart!.day} – ${t.salesWindowEnd?.month}/${t.salesWindowEnd?.day}';
              return DataRow(
                cells: [
                  DataCell(Text(t.name)),
                  DataCell(Text(ticketTierTypeLabel(t.tierType))),
                  DataCell(Text(ngnFromMinor(t.priceMinor.toString()))),
                  DataCell(Text('$sold / ${t.capacity}')),
                  DataCell(Text(window, style: context.eosText.labelSmall)),
                  DataCell(EosFinanceChip(
                    label: t.visibility == TicketVisibility.publicListing ? 'public' : 'hidden',
                    compact: true,
                  )),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showTierDialog(context, event.id, existing: t),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showTierDialog(BuildContext context, String eventId, {OrganizerTicketTier? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final price = TextEditingController(text: existing != null ? '${existing.priceMinor ~/ 100}' : '15000');
    final cap = TextEditingController(text: existing != null ? '${existing.capacity}' : '100');
    var tierType = existing?.tierType ?? TicketTierType.regular;
    var visibility = existing?.visibility ?? TicketVisibility.publicListing;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Create ticket tier' : 'Edit ticket tier'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EosTextField(controller: name, label: 'Name'),
                SizedBox(height: context.eos.spacing.sm),
                EosTextField(controller: desc, label: 'Description'),
                SizedBox(height: context.eos.spacing.sm),
                EosTextField(controller: price, label: 'Price (NGN)', keyboardType: TextInputType.number),
                SizedBox(height: context.eos.spacing.sm),
                EosTextField(controller: cap, label: 'Capacity', keyboardType: TextInputType.number),
                SizedBox(height: context.eos.spacing.sm),
                EosSelectField<TicketTierType>(
                  label: 'Tier type',
                  value: tierType,
                  items: TicketTierType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(ticketTierTypeLabel(t))))
                      .toList(),
                  onChanged: (v) => tierType = v ?? tierType,
                ),
                EosSelectField<TicketVisibility>(
                  label: 'Visibility',
                  value: visibility,
                  items: const [
                    DropdownMenuItem(value: TicketVisibility.publicListing, child: Text('Public listing')),
                    DropdownMenuItem(value: TicketVisibility.hidden, child: Text('Hidden')),
                  ],
                  onChanged: (v) => visibility = v ?? visibility,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final priceMinor = (int.tryParse(price.text) ?? 0) * 100;
              final capacity = int.tryParse(cap.text) ?? 100;
              if (existing == null) {
                OrganizerEventStore.instance.addTicketTier(
                  eventId,
                  OrganizerTicketTier(
                    id: 'tier_${DateTime.now().millisecondsSinceEpoch}',
                    name: name.text.trim(),
                    description: desc.text.trim(),
                    priceMinor: priceMinor,
                    currency: 'NGN',
                    capacity: capacity,
                    remaining: capacity,
                    tierType: tierType,
                    visibility: visibility,
                    salesWindowStart: DateTime.now(),
                    salesWindowEnd: DateTime.now().add(const Duration(days: 90)),
                  ),
                );
              } else {
                OrganizerEventStore.instance.updateTicketTier(eventId, existing.id, (t) {
                  final sold = t.capacity - t.remaining;
                  final newCap = capacity;
                  return t.copyWith(
                    name: name.text.trim(),
                    description: desc.text.trim(),
                    priceMinor: priceMinor,
                    capacity: newCap,
                    remaining: (newCap - sold).clamp(0, newCap),
                    tierType: tierType,
                    visibility: visibility,
                  );
                });
              }
              bumpOrganizerRevision(ref);
              Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
    name.dispose();
    desc.dispose();
    price.dispose();
    cap.dispose();
  }
}

class _AttendeesTab extends ConsumerWidget {
  const _AttendeesTab({required this.event});
  final OrganizerEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(attendeeSearchQueryProvider).toLowerCase();
    final eventData = ref.watch(organizerEventProvider(event.id)).value ?? event;
    final filtered = eventData.attendees.where((a) {
      if (query.isEmpty) return true;
      return a.name.toLowerCase().contains(query) ||
          a.email.toLowerCase().contains(query) ||
          a.ticketId.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EosTextField(
            label: 'Search attendees',
            hint: 'Name, email, or ticket ID',
            onChanged: (v) => ref.read(attendeeSearchQueryProvider.notifier).state = v,
          ),
          SizedBox(height: context.eos.spacing.md),
          if (filtered.isEmpty)
            EosSurfaceCard(child: Text('No matching attendees', style: context.eosText.bodyMedium))
          else
            for (final a in filtered)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  child: ExpansionTile(
                    title: Text(a.name, style: context.eosText.titleSmall),
                    subtitle: Text('${a.tierName} · ${a.email}'),
                    trailing: EosCheckinStatus(checkedIn: a.checkedIn),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(context.eos.spacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ticket: ${a.ticketId}', style: context.eosText.labelSmall),
                            SizedBox(height: context.eos.spacing.sm),
                            Text('Purchase history', style: context.eosText.titleSmall),
                            for (final p in a.purchases)
                              ListTile(
                                dense: true,
                                title: Text(p.item),
                                subtitle: Text(p.purchasedAt.toString()),
                                trailing: OrganizerMoneyText(minor: p.amountMinor, compact: true),
                              ),
                            SizedBox(height: context.eos.spacing.sm),
                            Text('Timeline', style: context.eosText.titleSmall),
                            for (final t in a.timeline)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.timeline, size: 18),
                                title: Text(t.label),
                                subtitle: Text(t.at.toString()),
                              ),
                            if (!a.checkedIn)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    OrganizerEventStore.instance.update(event.id, (e) {
                                      final attendees = e.attendees
                                          .map((x) => x.id == a.id ? x.copyWith(checkedIn: true) : x)
                                          .toList();
                                      return e.copyWith(attendees: attendees);
                                    });
                                    bumpOrganizerRevision(ref);
                                  },
                                  child: const Text('Manual check-in'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _VendorsTab extends ConsumerWidget {
  const _VendorsTab({required this.event, required this.ref});
  final OrganizerEvent event;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventData = ref.watch(organizerEventProvider(event.id)).value ?? event;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Event vendors', style: context.eosText.titleLarge)),
              FilledButton.icon(
                onPressed: () => _inviteVendor(context, ref, event.id),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Invite vendor'),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          if (eventData.vendors.isEmpty)
            EosSurfaceCard(
              child: Text('No vendors yet. Invite caterers, AV, décor, and more.', style: context.eosText.bodyMedium),
            )
          else
            for (final v in eventData.vendors)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: OrganizerVendorManageCard(
                  vendor: v,
                  onApprove: v.status == VendorSlotStatus.pending
                      ? () {
                          OrganizerEventStore.instance.setVendorStatus(event.id, v.id, VendorSlotStatus.approved);
                          bumpOrganizerRevision(ref);
                        }
                      : null,
                  onReject: v.status == VendorSlotStatus.pending
                      ? () {
                          OrganizerEventStore.instance.setVendorStatus(event.id, v.id, VendorSlotStatus.rejected);
                          bumpOrganizerRevision(ref);
                        }
                      : null,
                  onSuspend: v.status == VendorSlotStatus.approved
                      ? () {
                          OrganizerEventStore.instance.setVendorStatus(event.id, v.id, VendorSlotStatus.suspended);
                          bumpOrganizerRevision(ref);
                        }
                      : null,
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _inviteVendor(BuildContext context, WidgetRef ref, String eventId) async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'Catering');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EosTextField(controller: name, label: 'Business name'),
            SizedBox(height: context.eos.spacing.sm),
            EosTextField(controller: category, label: 'Category'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              OrganizerEventStore.instance.inviteVendor(
                eventId,
                businessName: name.text.trim(),
                category: category.text.trim(),
              );
              bumpOrganizerRevision(ref);
              Navigator.pop(ctx);
            },
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
    name.dispose();
    category.dispose();
  }
}

class _FinanceTab extends StatelessWidget {
  const _FinanceTab({required this.event});
  final OrganizerEvent event;

  @override
  Widget build(BuildContext context) {
    final vendorRevenue = event.vendors.fold(0, (sum, v) => sum + v.revenueMinor);
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EosAttentionBanner(
            headline: 'Mock finance summary',
            message: 'Full Finance Operations (Phase 5) is not started. Numbers below are local estimates.',
            severity: 'INFO',
          ),
          Wrap(
            spacing: context.eos.spacing.md,
            runSpacing: context.eos.spacing.md,
            children: [
              SizedBox(
                width: 220,
                child: EosKpiCard(
                  title: 'Ticket revenue',
                  value: formatRevenue(event.revenueMinor),
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              SizedBox(
                width: 220,
                child: EosKpiCard(
                  title: 'Vendor GMV',
                  value: formatRevenue(vendorRevenue),
                  icon: Icons.storefront_outlined,
                ),
              ),
              SizedBox(
                width: 220,
                child: EosKpiCard(
                  title: 'Refund requests',
                  value: '${event.refundRequests}',
                  icon: Icons.replay_outlined,
                  attention: event.refundRequests > 0 ? EosKpiAttention.warning : EosKpiAttention.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OperationsTab extends StatelessWidget {
  const _OperationsTab({required this.event, required this.ref});
  final OrganizerEvent event;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live operations', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            'Open the Live Ops module for QR check-in, incidents, command center, and health monitoring.',
            style: context.eosText.bodyMedium,
          ),
          SizedBox(height: context.eos.spacing.md),
          Wrap(
            spacing: context.eos.spacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () {
                  ref.read(liveOpsEventIdProvider.notifier).state = event.id;
                  ref.read(organizerShellTabProvider.notifier).select(6);
                  context.go('/organizer');
                },
                icon: const Icon(Icons.sensors, size: 18),
                label: const Text('Open Live Ops'),
              ),
              if (event.status != OrganizerEventStatus.live)
                OutlinedButton(
                  onPressed: () {
                    OrganizerEventStore.instance.setLive(event.id);
                    OperationsStore.instance.ensureLive(event.id);
                    bumpOrganizerRevision(ref);
                    bumpOperationsRevision(ref);
                    ref.read(liveOpsEventIdProvider.notifier).state = event.id;
                    ref.read(organizerShellTabProvider.notifier).select(6);
                    context.go('/organizer');
                  },
                  child: const Text('Go live now'),
                ),
            ],
          ),
          SizedBox(height: context.eos.spacing.lg),
          EosKpiCard(
            title: 'Check-ins',
            value: '${event.checkedInCount}',
            subtitle: '${event.attendees.length} registered · ${event.noShowCount} no-shows',
            icon: Icons.qr_code_scanner,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(organizerAnalyticsProvider(eventId));
    var period = ref.watch(_analyticsPeriodProvider);

    return analytics.when(
      data: (snap) => SingleChildScrollView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                SizedBox(
                  width: 200,
                  child: EosKpiCard(title: 'Registrations', value: '${snap.registrations}', icon: Icons.how_to_reg),
                ),
                SizedBox(
                  width: 200,
                  child: EosKpiCard(title: 'Check-ins', value: '${snap.checkIns}', icon: Icons.qr_code_scanner),
                ),
                SizedBox(
                  width: 200,
                  child: EosKpiCard(title: 'No-shows', value: '${snap.noShows}', icon: Icons.person_off_outlined),
                ),
                SizedBox(
                  width: 200,
                  child: EosKpiCard(
                    title: 'Revenue',
                    value: formatRevenue(snap.revenueMinor),
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Daily')),
                ButtonSegment(value: 1, label: Text('Weekly')),
                ButtonSegment(value: 2, label: Text('Monthly')),
              ],
              selected: {period},
              onSelectionChanged: (s) => ref.read(_analyticsPeriodProvider.notifier).state = s.first,
            ),
            SizedBox(height: context.eos.spacing.md),
            EosSurfaceCard(
              child: EosSparkline(
                values: switch (period) {
                  0 => snap.dailySales,
                  1 => snap.weeklySales,
                  _ => snap.monthlySales,
                },
                height: 64,
              ),
            ),
            SizedBox(height: context.eos.spacing.xl),
            EosSection(
              title: 'Tier performance by type',
              child: EosDataTable(
                columns: const [
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Sold')),
                ],
                rows: snap.tierTypeBreakdown.entries
                    .map(
                      (e) => DataRow(cells: [
                        DataCell(Text(ticketTierTypeLabel(e.key))),
                        DataCell(Text('${e.value}')),
                      ]),
                    )
                    .toList(),
                emptyMessage: 'No sales yet',
              ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

final _analyticsPeriodProvider = StateProvider<int>((ref) => 0);

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.event, required this.ref});
  final OrganizerEvent event;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event settings', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.md),
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(title: const Text('Banner'), subtitle: Text(event.bannerLabel)),
                ListTile(title: const Text('Tags'), subtitle: Text(event.tags.isEmpty ? 'None' : event.tags.join(', '))),
                ListTile(
                  title: const Text('Media assets'),
                  subtitle: Text(event.mediaLabels.isEmpty ? 'None' : event.mediaLabels.join(', ')),
                ),
                ListTile(title: const Text('Category'), subtitle: Text(event.category)),
                ListTile(title: const Text('Venue type'), subtitle: Text(event.venueType.name)),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          if (event.status == OrganizerEventStatus.draft)
            FilledButton(
              onPressed: () {
                OrganizerEventStore.instance.publish(event.id);
                bumpOrganizerRevision(ref);
              },
              child: const Text('Publish to marketplace'),
            ),
        ],
      ),
    );
  }
}
