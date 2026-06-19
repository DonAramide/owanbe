import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../data/organizer_event_store.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

class VendorManagementScreen extends ConsumerWidget {
  const VendorManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = ref.watch(selectedOrganizerEventIdProvider);
    final eventAsync = eventId == null ? null : ref.watch(organizerEventProvider(eventId));

    return EosPageScaffold(
      title: 'Vendor management',
      subtitle: 'Invite, approve, and monitor event vendors',
      actions: [
        if (eventId != null)
          OutlinedButton.icon(
            onPressed: () => _inviteVendor(context, ref, eventId),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Invite vendor'),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrganizerEventPicker(),
          SizedBox(height: context.eos.spacing.lg),
          if (eventId == null)
            EosSurfaceCard(child: Text('Select an event', style: context.eosText.bodyMedium))
          else
            eventAsync!.when(
              data: (event) {
                if (event == null) return const Text('Event not found');
                if (event.vendors.isEmpty) {
                  return EosSurfaceCard(
                    child: Padding(
                      padding: EdgeInsets.all(context.eos.spacing.lg),
                      child: Text(
                        'No vendors assigned yet. Invite caterers, AV, décor, and more.',
                        style: context.eosText.bodyMedium,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final v in event.vendors)
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
                    TextButton(
                      onPressed: () => context.push('/organizer/events/${event.id}?tab=3'),
                      child: const Text('Open vendor workspace'),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
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
