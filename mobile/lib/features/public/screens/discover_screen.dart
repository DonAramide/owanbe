import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/public_providers.dart';
import '../widgets/public_event_grid.dart';
import '../widgets/public_shell_mixin.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(publicEventsProvider);
    final categories = ref.watch(eventCategoriesProvider);
    final selected = ref.watch(discoverCategoryProvider);

    return buildPublicShell(
      context: context,
      ref: ref,
      activeNav: 'discover',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discover events', style: context.eosText.headlineMedium),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Festivals, expos, concerts, and more',
              style: context.eosText.bodyMedium,
            ),
            SizedBox(height: context.eos.spacing.lg),
            EosSearchField(
              hint: 'Search by city, name, or category…',
              onChanged: (v) => ref.read(discoverQueryProvider.notifier).state = v,
            ),
            SizedBox(height: context.eos.spacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final active = selected == cat;
                  return Padding(
                    padding: EdgeInsets.only(right: context.eos.spacing.xs),
                    child: FilterChip(
                      label: Text(cat == 'all' ? 'All' : cat),
                      selected: active,
                      onSelected: (_) => ref.read(discoverCategoryProvider.notifier).state = cat,
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: context.eos.spacing.lg),
            events.when(
              data: (list) => PublicEventGrid(events: list),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
              error: (e, _) => EosSurfaceCard(child: Text('$e')),
            ),
          ],
        ),
      ),
    );
  }
}
