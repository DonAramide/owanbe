import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../super_admin_providers.dart';
import '../models/executive_dashboard_models.dart';

class ExecutiveAlertCenter extends ConsumerWidget {
  const ExecutiveAlertCenter({super.key, required this.alerts});

  final List<ExecutiveAlert> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EosSection(
      title: 'Live alert center',
      subtitle: 'Critical platform signals',
      child: Column(
        children: [
          for (final a in alerts)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosAttentionBanner(
                headline: a.title,
                message: a.message,
                severity: a.severity,
                onAction: () => ref.read(superAdminShellTabProvider.notifier).select(a.tabIndex),
                actionLabel: 'Open workspace',
              ),
            ),
        ],
      ),
    );
  }
}
