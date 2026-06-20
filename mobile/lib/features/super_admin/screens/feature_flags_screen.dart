import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../super_admin_providers.dart';

class FeatureFlagsScreen extends ConsumerWidget {
  const FeatureFlagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(superAdminFeatureFlagTenantProvider);
    final flags = ref.watch(superAdminFeatureFlagsProvider(tenantId));
    return EosPageScaffold(
      title: 'Feature flags',
      subtitle: 'Tenant-specific rollout controls',
      floatingHeader: EosSearchField(
        hint: 'Tenant ID for flags',
        onSubmitted: (v) => ref.read(superAdminFeatureFlagTenantProvider.notifier).state = v.trim(),
      ),
      body: flags.when(
        data: (d) {
          final items = (d['flags'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return Column(
            children: items.map((f) => Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosSurfaceCard(
                child: Row(
                  children: [
                    Expanded(child: Text(f['key'] as String? ?? '', style: context.eosText.titleSmall)),
                    Switch(
                      value: f['enabled'] as bool? ?? true,
                      onChanged: (v) async {
                        await ref.read(superAdminApiProvider).setFeatureFlag(tenantId, f['key'] as String, v);
                        bumpSuperAdminRevision(ref);
                      },
                    ),
                  ],
                ),
              ),
            )).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}
