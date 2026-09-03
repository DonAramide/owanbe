import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../admin/widgets/admin_page_layout.dart';

/// Control Tower → Commerce → Vendor Configuration hub.
class VendorConfigurationHubScreen extends StatelessWidget {
  const VendorConfigurationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Vendor Configuration',
      subtitle:
          'Authoritative Super Admin definitions for vendor business capabilities, '
          'service vs rental categories, and the master resource catalogue. '
          'Does not assign capabilities to vendors, build packages, or change Vendor CRM.',
      actions: [
        TextButton.icon(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/super-admin');
            }
          },
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
        ),
      ],
      body: Column(
        children: [
          _HubCard(
            title: 'Business Capabilities',
            description: 'Enable or disable Service Provider and Rental Provider definitions.',
            icon: Icons.badge_outlined,
            route: '/super-admin/commerce/vendor-configuration/capabilities',
          ),
          SizedBox(height: context.eos.spacing.md),
          _HubCard(
            title: 'Service Categories',
            description: 'Create, edit, and activate/deactivate service categories (e.g. DJ, Catering).',
            icon: Icons.home_repair_service_outlined,
            route: '/super-admin/commerce/vendor-configuration/service-categories',
          ),
          SizedBox(height: context.eos.spacing.md),
          _HubCard(
            title: 'Rental Categories',
            description: 'Create, edit, and activate/deactivate rental categories (e.g. DJ Equipment).',
            icon: Icons.inventory_2_outlined,
            route: '/super-admin/commerce/vendor-configuration/rental-categories',
          ),
          SizedBox(height: context.eos.spacing.md),
          _HubCard(
            title: 'Resource Catalogue',
            description:
                'Master resource kinds (microphone, speaker, mixer). Definitions only — not inventory.',
            icon: Icons.category_outlined,
            route: '/super-admin/commerce/vendor-configuration/resources',
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: EosColors.plum),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(description, style: context.eosText.bodyMedium),
          SizedBox(height: context.eos.spacing.md),
          FilledButton.tonalIcon(
            onPressed: () => context.push(route),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('Open $title'),
          ),
        ],
      ),
    );
  }
}
