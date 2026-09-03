import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';

/// Control Tower → Commerce Configuration hub.
/// Vendor Pricing deep-links to the existing [AdminVendorPricingScreen] via route —
/// no duplicate pricing editor.
class CommerceConfigurationScreen extends ConsumerWidget {
  const CommerceConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EosPageScaffold(
      title: 'Commerce Configuration',
      subtitle: 'Platform commerce controls for Control Tower operators',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CommerceNavCard(
            title: 'Vendor Pricing',
            description:
                'Global default, service category, vendor, and vendor+service markup rules. '
                'Opens the existing Platform Admin pricing editor.',
            icon: Icons.percent,
            onOpen: () => context.push('/super-admin/commerce/vendor-pricing'),
          ),
          SizedBox(height: context.eos.spacing.md),
          _CommerceNavCard(
            title: 'Vendor Capabilities',
            description:
                'Admin-owned Core and Optional capability catalogues per service category. '
                'Vendors only toggle what they provide — they cannot create catalogue items. '
                'Does not change vendor pricing or historical requests.',
            icon: Icons.checklist_outlined,
            onOpen: () => context.push('/super-admin/commerce/vendor-capabilities'),
          ),
          SizedBox(height: context.eos.spacing.md),
          _CommerceNavCard(
            title: 'Vendor Configuration',
            description:
                'Business capabilities (Service Provider / Rental Provider), service categories, '
                'rental categories, and the master resource catalogue. Definitions only — '
                'does not change Vendor CRM, rental bookings, or vendor identity.',
            icon: Icons.tune_outlined,
            onOpen: () => context.push('/super-admin/commerce/vendor-configuration'),
          ),
          SizedBox(height: context.eos.spacing.md),
          _CommerceNavCard(
            title: 'Fee Rules',
            description:
                'Platform fee policies (ticket / booking). Configuration surface coming soon.',
            icon: Icons.receipt_long_outlined,
            onOpen: null,
            disabledLabel: 'Coming soon',
          ),
        ],
      ),
    );
  }
}

class _CommerceNavCard extends StatelessWidget {
  const _CommerceNavCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onOpen,
    this.disabledLabel,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onOpen;
  final String? disabledLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onOpen != null;
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: enabled ? EosColors.plum : EosColors.slate500),
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
          if (enabled)
            FilledButton.tonalIcon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('Open $title'),
            )
          else
            Text(
              disabledLabel ?? 'Unavailable',
              style: context.eosText.labelMedium?.copyWith(color: EosColors.slate500),
            ),
        ],
      ),
    );
  }
}
