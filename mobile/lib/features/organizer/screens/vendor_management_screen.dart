import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../portals/customer/router/customer_routes.dart';
import '../data/organizer_persistence.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/invite_vendor_sheet.dart';
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
        FilledButton.icon(
          onPressed: () => context.push(CustomerRoutes.vendors),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('Browse marketplace'),
        ),
        if (eventId != null)
          OutlinedButton.icon(
            onPressed: () async {
              final event = await ref.read(organizerEventProvider(eventId).future);
              if (!context.mounted || event == null) return;
              await showInviteVendorSheet(
                context,
                eventId: eventId,
                alreadyInvitedCatalogIds: invitedCatalogIdsFromEvent(event),
                alreadyInvitedNames: invitedVendorNamesFromEvent(event),
                cityHint: event.city,
              );
            },
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'No vendors assigned yet. Browse the marketplace to compare caterers, décor, DJs, and venues with photos, ratings, and pricing.',
                            style: context.eosText.bodyMedium,
                          ),
                          SizedBox(height: context.eos.spacing.md),
                          FilledButton.icon(
                            onPressed: () => context.push(CustomerRoutes.vendors),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Find vendors in marketplace'),
                          ),
                        ],
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
                              ? () async {
                                  await updateVendorSlot(ref, event.id, v.id, VendorSlotStatus.approved);
                                }
                              : null,
                          onReject: v.status == VendorSlotStatus.pending
                              ? () async {
                                  await updateVendorSlot(ref, event.id, v.id, VendorSlotStatus.rejected);
                                }
                              : null,
                          onSuspend: v.status == VendorSlotStatus.approved
                              ? () async {
                                  await updateVendorSlot(ref, event.id, v.id, VendorSlotStatus.suspended);
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
}
