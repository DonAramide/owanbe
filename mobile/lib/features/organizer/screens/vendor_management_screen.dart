import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../../../portals/customer/router/customer_routes.dart';
import '../../../portals/customer/router/event_route_registry.dart';
import '../command_center_v3/tabs/vendors_tab_v3.dart';
import '../providers/organizer_providers.dart';
import '../widgets/invite_vendor_sheet.dart';
import '../widgets/organizer_shared.dart';

/// EOS Vendor management — delegates to canonical CRM (`VendorsTabV3`), not slot dual-path.
class VendorManagementScreen extends ConsumerWidget {
  const VendorManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = ref.watch(selectedOrganizerEventIdProvider);

    return EosPageScaffold(
      title: 'Vendor management',
      subtitle: 'Same CRM as Event Workspace Vendors — marketplace hire to completion',
      actions: [
        FilledButton.icon(
          onPressed: () => context.push(CustomerRoutes.vendors),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('Browse marketplace'),
        ),
        if (eventId != null)
          OutlinedButton.icon(
            onPressed: () async {
              final crm = await ref.read(eventVendorCrmProvider(eventId).future);
              if (!context.mounted) return;
              await showInviteVendorSheet(
                context,
                eventId: eventId,
                alreadyInvitedCatalogIds: crm.items.map((e) => e.vendorId).toSet(),
                alreadyInvitedNames:
                    crm.items.map((e) => e.vendorName ?? '').where((n) => n.isNotEmpty).toSet(),
              );
              refreshVendorCrm(ref);
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
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(EventRouteRegistry.event(eventId)),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open Event Workspace'),
              ),
            ),
            VendorsTabV3(eventId: eventId, nestedInParentScroll: true),
          ],
        ],
      ),
    );
  }
}
