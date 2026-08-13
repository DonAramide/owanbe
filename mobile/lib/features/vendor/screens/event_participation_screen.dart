import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../data/vendor_persistence.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_event_workspace_nav.dart';
import '../providers/vendor_providers.dart';
import 'vendor_event_360_workspace_screen.dart';

class EventParticipationScreen extends ConsumerStatefulWidget {
  const EventParticipationScreen({super.key});

  @override
  ConsumerState<EventParticipationScreen> createState() => _EventParticipationScreenState();
}

class _EventParticipationScreenState extends ConsumerState<EventParticipationScreen> {
  String? _activeEventId;
  String? _activeEventUuid;
  String? _activeRequestId;
  int? _initialTabIndex;
  ParticipationLifecycle _filter = ParticipationLifecycle.approved;

  static const _stages = ParticipationLifecycle.values;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeNavTarget());
  }

  void _consumeNavTarget() {
    final target = ref.read(vendorEventWorkspaceNavProvider);
    if (target == null || !mounted) return;
    setState(() {
      _activeEventId = target.eventId;
      _activeEventUuid = target.eventUuid;
      _activeRequestId = target.requestId;
      _initialTabIndex = target.initialTabIndex;
      _filter = ParticipationLifecycle.approved;
    });
    ref.read(vendorEventWorkspaceNavProvider.notifier).clear();
  }

  Future<void> _openWorkspace({
    required String eventId,
    String? eventUuid,
    String? requestId,
    int? initialTabIndex,
    String? eventTitle,
  }) async {
    final resolved = await resolveVendorRequestIdForWorkspace(
      context,
      ref,
      eventKey: eventId,
      eventUuid: eventUuid,
      requestId: requestId,
      eventTitle: eventTitle,
    );
    if (!mounted) return;
    setState(() {
      _activeEventId = eventId;
      _activeEventUuid = eventUuid;
      _activeRequestId = resolved;
      _initialTabIndex = initialTabIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VendorEventWorkspaceNav?>(vendorEventWorkspaceNavProvider, (prev, next) {
      if (next == null) return;
      setState(() {
        _activeEventId = next.eventId;
        _activeEventUuid = next.eventUuid;
        _activeRequestId = next.requestId;
        _initialTabIndex = next.initialTabIndex;
        _filter = ParticipationLifecycle.approved;
      });
      ref.read(vendorEventWorkspaceNavProvider.notifier).clear();
    });

    if (_activeEventId != null) {
      return VendorEvent360WorkspaceScreen(
        eventId: _activeEventId!,
        eventUuid: _activeEventUuid,
        requestId: _activeRequestId,
        initialTabIndex: _initialTabIndex,
        onBack: () => setState(() {
          _activeEventId = null;
          _activeEventUuid = null;
          _activeRequestId = null;
          _initialTabIndex = null;
        }),
      );
    }

    final participations = ref.watch(vendorParticipationsByLifecycleProvider(_filter));

    return EosPageScaffold(
      title: 'Event Operations Center',
      subtitle: 'Operational workspace for scheduled events',
      floatingHeader: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final stage in _stages)
              Padding(
                padding: EdgeInsets.only(right: context.eos.spacing.xs),
                child: FilterChip(
                  label: Text(_stageLabel(stage)),
                  selected: _filter == stage,
                  onSelected: (_) => setState(() => _filter = stage),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(right: context.eos.spacing.xs),
              child: FilterChip(
                label: const Text('Cancelled'),
                selected: false,
                onSelected: (_) {},
              ),
            ),
          ],
        ),
      ),
      body: participations.when(
        data: (list) {
          if (list.isEmpty) {
            return EosSurfaceCard(
              child: Padding(
                padding: EdgeInsets.all(context.eos.spacing.lg),
                child: Text(
                  _emptyMessage(_filter),
                  style: context.eosText.bodyMedium,
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final p in list)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: Card(
                    color: Colors.white.withValues(alpha: 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  p.eventTitle,
                                  style: context.eosText.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _filter == ParticipationLifecycle.approved
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _filter == ParticipationLifecycle.approved
                                      ? 'Active'
                                      : _filter.name.toUpperCase(),
                                  style: TextStyle(
                                    color: _filter == ParticipationLifecycle.approved
                                        ? Colors.greenAccent
                                        : Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Event ID: ${p.eventId}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          Text('Organizer: ${p.organizerName}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: () => _openWorkspace(
                                  eventId: p.eventId,
                                  eventUuid: p.eventUuid,
                                  eventTitle: p.eventTitle,
                                ),
                                style: ElevatedButton.styleFrom(backgroundColor: EosColors.champagne),
                                child: const Text(
                                  'Open Event Workspace',
                                  style: TextStyle(
                                    color: EosColors.plumDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _actions(context, ref, p) ?? const SizedBox(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  String _stageLabel(ParticipationLifecycle stage) => switch (stage) {
        ParticipationLifecycle.invited => 'Invited / Upcoming',
        ParticipationLifecycle.applied => 'Applied / Pending',
        ParticipationLifecycle.approved => 'Active / Scheduled',
        ParticipationLifecycle.completed => 'Completed',
      };

  String _emptyMessage(ParticipationLifecycle stage) => switch (stage) {
        ParticipationLifecycle.invited =>
          'No invitations right now. Published events appear here when organizers invite you.',
        ParticipationLifecycle.applied => 'No pending applications. Apply from Invited events.',
        ParticipationLifecycle.approved =>
          'No approved events yet. Accept invites or wait for organizer approval.',
        ParticipationLifecycle.completed =>
          'Completed events will appear here after you finish participating.',
      };

  Widget? _actions(BuildContext context, WidgetRef ref, VendorEventParticipation p) {
    if (p.lifecycleStage == ParticipationLifecycle.invited) {
      if (p.id.startsWith('disc_')) {
        return FilledButton(
          onPressed: () async {
            await applyToEvent(ref, p.eventId);
            setState(() {
              _filter = ParticipationLifecycle.applied;
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application submitted')),
              );
            }
          },
          child: const Text('Apply'),
        );
      }
      return FilledButton(
        onPressed: () async {
          await acceptParticipation(ref, p);
          setState(() {
            _filter = ParticipationLifecycle.approved;
          });
        },
        child: const Text('Accept'),
      );
    }
    return null;
  }
}
