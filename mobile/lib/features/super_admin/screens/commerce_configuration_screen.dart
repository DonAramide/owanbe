import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../admin/screens/admin_vendor_categories_screen.dart';

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
            title: 'Service Categories',
            description:
                'Vendor service categories used in marketplace filters and event workflows.',
            icon: Icons.category_outlined,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminVendorCategoriesScreen()),
            ),
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
