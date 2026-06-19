import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/operations_models.dart';
import '../providers/operations_providers.dart';
import '../widgets/operations_shared.dart';

class VendorOpsMonitorScreen extends ConsumerWidget {
  const VendorOpsMonitorScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(operationsVendorsProvider(eventId));

    return EosPageScaffold(
      title: 'Vendor operations',
      subtitle: 'Who is active on the floor right now',
      body: vendors.when(
        data: (list) {
          if (list.isEmpty) {
            return EosSurfaceCard(
              child: Text('No vendors assigned to this event', style: context.eosText.bodyMedium),
            );
          }
          final active = list.where((v) => v.status == VendorOpsStatus.active).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: context.eos.spacing.md,
                children: [
                  SizedBox(
                    width: 200,
                    child: EosKpiCard(
                      title: 'Active now',
                      value: '$active',
                      subtitle: 'of ${list.length} vendors',
                      icon: Icons.sensors,
                      attention: active > 0 ? EosKpiAttention.info : EosKpiAttention.warning,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.eos.spacing.lg),
              for (final v in list)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: VendorOpsCard(vendor: v),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}
