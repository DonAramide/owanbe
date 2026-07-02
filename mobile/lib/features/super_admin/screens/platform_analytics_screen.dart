import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';

class PlatformAnalyticsScreen extends ConsumerWidget {
  const PlatformAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EosPageScaffold(
      title: 'Platform Analytics',
      subtitle: 'Growth KPIs across revenue, events, vendors, attendees',
      body: EosSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Launch Business Intelligence Workspace', style: context.eosText.titleMedium),
              const SizedBox(height: 12),
              const Text('Open the Platform Analytics 360 cockpit to review forecasts, lifecycle funnels, and geo-density mappings.'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/super-admin/analytics/platform');
                },
                icon: const Icon(Icons.analytics),
                label: const Text('Open Analytics 360 Workspace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
