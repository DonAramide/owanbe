import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../eos/eos.dart';
import '../../admin/widgets/admin_page_layout.dart';

final vendorBusinessCapabilitiesProvider =
    FutureProvider.autoDispose<List<VendorBusinessCapabilityConfig>>((ref) async {
  return EventConfigApi(createOwambeHttpClient()).adminListBusinessCapabilities();
});

class VendorBusinessCapabilitiesScreen extends ConsumerWidget {
  const VendorBusinessCapabilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(vendorBusinessCapabilitiesProvider);
    return AdminPageLayout(
      title: 'Vendor Business Capabilities',
      subtitle:
          'Platform definitions only. A vendor may hold one or both once onboarding consumes these keys. '
          'This screen does not create a second vendor identity.',
      actions: [
        TextButton.icon(
          onPressed: () => context.canPop() ? context.pop() : context.go('/super-admin'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
        ),
      ],
      body: caps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Could not load capabilities: $e'),
        data: (items) {
          if (items.isEmpty) {
            return const Text('No capability definitions found. Apply migration 071 and retry.');
          }
          return Column(
            children: [
              for (final cap in items)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: EosSurfaceCard(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(cap.label),
                      subtitle: Text('${cap.capabilityKey}\n${cap.description}'),
                      isThreeLine: cap.description.isNotEmpty,
                      value: cap.isActive,
                      onChanged: (v) async {
                        try {
                          await EventConfigApi(createOwambeHttpClient()).adminPatchBusinessCapability(
                            capabilityKey: cap.capabilityKey,
                            isActive: v,
                          );
                          ref.invalidate(vendorBusinessCapabilitiesProvider);
                        } catch (err) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$err')),
                          );
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
