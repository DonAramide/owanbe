import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../../../portals/customer/widgets/vendor_crm/vendor_stage_badge.dart';
import '../providers/vendor_providers.dart';

/// Vendor CRM inbox at `/vendor/crm`.
class VendorCrmScreen extends ConsumerStatefulWidget {
  const VendorCrmScreen({super.key});

  @override
  ConsumerState<VendorCrmScreen> createState() => _VendorCrmScreenState();
}

class _VendorCrmScreenState extends ConsumerState<VendorCrmScreen> {
  bool _saving = false;

  Future<void> _transition(VendorRequest request, String stage) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(vendorCrmApiProvider).transitionStage(request.id, stage);
      refreshVendorCrm(ref);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(vendorProfileProvider);
    final inbox = ref.watch(vendorInboxProvider(profile.id));

    return EosPageScaffold(
      title: 'Requests & pipeline',
      subtitle: profile.businessName,
      actions: [
        IconButton(
          tooltip: 'Calendar',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => context.push('/vendor/calendar'),
        ),
      ],
      body: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (snapshot) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            if (snapshot.items.isEmpty)
              const Text('No event requests yet.')
            else
              ...snapshot.items.map(
                (r) => Card(
                  margin: EdgeInsets.only(bottom: context.eos.spacing.md),
                  child: ListTile(
                    title: Text(r.eventTitle ?? 'Event'),
                    subtitle: Text(r.message.isEmpty ? (r.serviceLabel ?? '') : r.message),
                    trailing: VendorStageBadge(stage: r.stage),
                    onTap: () => _showActions(context, r),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, VendorRequest request) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (request.stage == 'negotiating')
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Accept request'),
                onTap: () {
                  Navigator.pop(ctx);
                  _transition(request, 'accepted');
                },
              ),
            if (request.stage == 'scheduled')
              ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Mark arrived on site'),
                onTap: () {
                  Navigator.pop(ctx);
                  _transition(request, 'arrived');
                },
              ),
            if (request.stage == 'arrived')
              ListTile(
                leading: const Icon(Icons.task_alt),
                title: const Text('Mark completed'),
                onTap: () {
                  Navigator.pop(ctx);
                  _transition(request, 'completed');
                },
              ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Decline'),
              onTap: () {
                Navigator.pop(ctx);
                _transition(request, 'declined');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified vendor calendar at `/vendor/calendar`.
class VendorCalendarScreen extends ConsumerStatefulWidget {
  const VendorCalendarScreen({super.key});

  @override
  ConsumerState<VendorCalendarScreen> createState() => _VendorCalendarScreenState();
}

class _VendorCalendarScreenState extends ConsumerState<VendorCalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(vendorProfileProvider);
    final calendar = ref.watch(vendorCalendarProvider(profile.id));

    return EosPageScaffold(
      title: 'Schedule & availability',
      subtitle: profile.businessName,
      body: calendar.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (snap) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            SwitchListTile(
              title: const Text('Vacation mode'),
              subtitle: Text(snap.vacationUntil != null ? 'Until ${snap.vacationUntil}' : 'Pause new bookings'),
              value: snap.vacationMode,
              onChanged: (v) async {
                await ref.read(vendorCrmApiProvider).patchVacation(profile.id, vacationMode: v);
                refreshVendorCrm(ref);
              },
            ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Upcoming blocks', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            if (snap.blocks.isEmpty)
              const Text('No calendar blocks in the next 60 days.')
            else
              ...snap.blocks.map(
                (b) => ListTile(
                  leading: Icon(_iconForKind(b.kind), color: EosColors.plum),
                  title: Text(b.kind.replaceAll('_', ' ')),
                  subtitle: Text(
                    b.allDay
                        ? '${b.startsAt.month}/${b.startsAt.day}/${b.startsAt.year}'
                        : '${b.startsAt.hour}:${b.startsAt.minute.toString().padLeft(2, '0')} – ${b.endsAt.hour}:${b.endsAt.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: b.reason != null ? Text(b.reason!, style: Theme.of(context).textTheme.bodySmall) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForKind(String kind) => switch (kind) {
        'vacation' => Icons.beach_access,
        'blackout' => Icons.event_busy,
        'rental_delivery' => Icons.local_shipping_outlined,
        'crm_scheduled' => Icons.event,
        _ => Icons.schedule,
      };
}
