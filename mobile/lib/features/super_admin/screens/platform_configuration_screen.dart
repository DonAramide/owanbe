import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../shared/models/event_access_mode.dart';
import '../platform_config_providers.dart';

/// Super Admin — centralized platform configuration (no hardcoded taxonomy).
class PlatformConfigurationScreen extends ConsumerWidget {
  const PlatformConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(platformEventCategoriesProvider);
    final tags = ref.watch(platformEventTagsProvider);
    final vendorCats = ref.watch(platformVendorCategoriesProvider);
    final templates = ref.watch(platformEventTemplatesProvider);

    return EosPageScaffold(
      title: 'Platform configuration',
      subtitle: 'Event types, vendor categories, tags, and templates',
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/super-admin'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Control tower'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfigSection(
            title: 'Event categories & types',
            subtitle: 'Wedding, festival, naming ceremony, etc.',
            child: categories.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) => _ChipList(items.map((c) => '${c.label} · ${c.accessMode.label}').toList()),
            ),
          ),
          SizedBox(height: context.eos.spacing.xl),
          _ConfigSection(
            title: 'Vendor categories',
            subtitle: 'Marketplace taxonomy',
            child: vendorCats.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) => _ChipList(items.map((c) => c.label).toList()),
            ),
          ),
          SizedBox(height: context.eos.spacing.xl),
          _ConfigSection(
            title: 'Event tags',
            child: tags.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) => _ChipList(items.map((t) => t.label).toList()),
            ),
          ),
          SizedBox(height: context.eos.spacing.xl),
          _ConfigSection(
            title: 'Event templates & checklists',
            child: templates.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) {
                if (items.isEmpty) {
                  return Text('No templates configured yet.', style: context.eosText.bodyMedium);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in items)
                      ListTile(
                        title: Text(t.label),
                        subtitle: Text('${t.accessMode.label}${t.categorySlug != null ? ' · ${t.categorySlug}' : ''}'),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  const _ConfigSection({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.eosText.titleLarge),
            if (subtitle != null) Text(subtitle!, style: context.eosText.bodySmall),
            SizedBox(height: context.eos.spacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChipList extends StatelessWidget {
  const _ChipList(this.labels);
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.eos.spacing.xs,
      runSpacing: context.eos.spacing.xs,
      children: [for (final l in labels) Chip(label: Text(l))],
    );
  }
}
