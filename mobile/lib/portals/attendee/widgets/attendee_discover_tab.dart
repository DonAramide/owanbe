import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/public/data/discover_location.dart';
import '../../../features/public/models/discover_filters.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/widgets/discover_event_rail.dart';
import '../../../features/public/widgets/discover_filters_sheet.dart';
import '../../../features/public/widgets/public_event_grid.dart';
import '../navigation/attendee_routes.dart';
import 'attendee_tab_scroll_padding.dart';

/// Attendee Discover marketplace — curated rails + search + filters.
/// Search wiring (`discoverQueryProvider`) is preserved.
class AttendeeDiscoverTab extends ConsumerStatefulWidget {
  const AttendeeDiscoverTab({super.key});

  @override
  ConsumerState<AttendeeDiscoverTab> createState() => _AttendeeDiscoverTabState();
}

class _AttendeeDiscoverTabState extends ConsumerState<AttendeeDiscoverTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLocation());
  }

  Future<void> _ensureLocation() async {
    if (ref.read(discoverUserLocationProvider) != null) return;
    final loc = await resolveDiscoverLocation();
    if (!mounted || loc == null) return;
    ref.read(discoverUserLocationProvider.notifier).state = loc;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);
    final selected = ref.watch(discoverCategoryProvider);
    final filters = ref.watch(discoverFiltersProvider);
    final upcoming = ref.watch(discoverUpcomingEventsProvider);
    final upcomingTotal = ref.watch(discoverUpcomingTotalProvider);
    final pageSize = ref.watch(discoverUpcomingPageSizeProvider);

    void openEvent(event) {
      context.push(AttendeeRoutes.eventDetail(event.id));
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(publicEventCatalogProvider);
        ref.invalidate(eventCategoriesProvider);
        ref.read(discoverUpcomingPageSizeProvider.notifier).state = 6;
        await _ensureLocation();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg).copyWith(
          bottom: attendeeTabScrollPadding(context).bottom,
        ),
        children: [
          Text('Discover events', style: context.eosText.headlineMedium),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'A living marketplace of celebrations — curated for you.',
            style: context.eosText.bodyMedium?.copyWith(color: context.eosColors.onSurfaceVariant),
          ),
          SizedBox(height: context.eos.spacing.lg),
          DiscoverAsyncRail(
            title: 'Featured Events',
            subtitle: 'Curated highlights',
            asyncEvents: ref.watch(discoverFeaturedEventsProvider),
            onEventTap: openEvent,
          ),
          EosSearchField(
            hint: 'Search by city, name, or category…',
            onChanged: (v) => ref.read(discoverQueryProvider.notifier).state = v,
          ),
          SizedBox(height: context.eos.spacing.md),
          categoriesAsync.when(
            data: (categories) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.xs),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ActionChip(
                          avatar: const Icon(Icons.tune, size: 18),
                          label: Text(
                            filters.activeCount > 0 ? 'Filters (${filters.activeCount})' : 'Filters',
                          ),
                          onPressed: () => showDiscoverFiltersSheet(
                            context,
                            ref,
                            categories: categories,
                          ),
                        );
                      }
                      final cat = categories[index - 1];
                      final active = selected == cat;
                      return FilterChip(
                        label: Text(cat == 'all' ? 'All' : cat),
                        selected: active,
                        onSelected: (_) => ref.read(discoverCategoryProvider.notifier).state = cat,
                      );
                    },
                  ),
                ),
                if (filters.hasActiveFilters) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  Wrap(
                    spacing: context.eos.spacing.xs,
                    runSpacing: context.eos.spacing.xs,
                    children: [
                      if (filters.dateFrom != null || filters.dateTo != null)
                        InputChip(
                          label: const Text('Date'),
                          onDeleted: () => ref.read(discoverFiltersProvider.notifier).state =
                              filters.copyWith(clearDates: true),
                        ),
                      if (filters.maxPriceMinor > 0)
                        InputChip(
                          label: const Text('Price'),
                          onDeleted: () => ref.read(discoverFiltersProvider.notifier).state =
                              filters.copyWith(maxPriceMinor: 0),
                        ),
                      if (filters.maxDistanceKm > 0)
                        InputChip(
                          label: const Text('Distance'),
                          onDeleted: () => ref.read(discoverFiltersProvider.notifier).state =
                              filters.copyWith(maxDistanceKm: 0),
                        ),
                      if (filters.venueTypes.isNotEmpty)
                        InputChip(
                          label: Text(
                            filters.venueTypes.map((t) => t[0].toUpperCase() + t.substring(1)).join(', '),
                          ),
                          onDeleted: () => ref.read(discoverFiltersProvider.notifier).state =
                              filters.copyWith(venueTypes: <String>{}),
                        ),
                      if (filters.freeOnly)
                        InputChip(
                          label: const Text('Free'),
                          onDeleted: () => ref.read(discoverFiltersProvider.notifier).state =
                              filters.copyWith(freeOnly: false),
                        ),
                      if (filters.paidOnly)
                        InputChip(
                          label: const Text('Paid'),
                          onDeleted: () => ref.read(discoverFiltersProvider.notifier).state =
                              filters.copyWith(paidOnly: false),
                        ),
                      TextButton(
                        onPressed: () =>
                            ref.read(discoverFiltersProvider.notifier).state = const DiscoverFilters(),
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox.shrink(),
          ),
          SizedBox(height: context.eos.spacing.lg),
          DiscoverAsyncRail(
            title: 'Trending Events',
            subtitle: 'Popular by ticket demand',
            asyncEvents: ref.watch(discoverTrendingEventsProvider),
            onEventTap: openEvent,
          ),
          EosSection(
            title: 'Upcoming Events',
            subtitle: 'Sorted by start date',
            child: upcoming.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              ),
              error: (e, _) => EosSurfaceCard(child: Text('$e')),
              data: (list) {
                final total = upcomingTotal.valueOrNull ?? list.length;
                return Column(
                  children: [
                    PublicEventGrid(events: list, onEventTap: openEvent),
                    if (pageSize < total) ...[
                      SizedBox(height: context.eos.spacing.md),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(discoverUpcomingPageSizeProvider.notifier).state = pageSize + 6,
                        child: Text('See more ($pageSize of $total)'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          DiscoverAsyncRail(
            title: 'Free Events',
            subtitle: 'Zero-cost entry',
            asyncEvents: ref.watch(discoverFreeEventsProvider),
            onEventTap: openEvent,
          ),
          DiscoverAsyncRail(
            title: 'Paid Events',
            subtitle: 'Ticketed celebrations',
            asyncEvents: ref.watch(discoverPaidEventsProvider),
            onEventTap: openEvent,
          ),
          DiscoverAsyncRail(
            title: 'Nearby Events',
            subtitle: 'Closest to you',
            asyncEvents: ref.watch(discoverNearbyEventsProvider),
            onEventTap: openEvent,
          ),
          DiscoverAsyncRail(
            title: 'Recommended for you',
            subtitle: 'Based on your interests & activity',
            asyncEvents: ref.watch(discoverPersonalizedEventsProvider),
            onEventTap: openEvent,
          ),
          DiscoverAsyncRail(
            title: 'Similar Events',
            subtitle: 'Like what you viewed',
            asyncEvents: ref.watch(discoverSimilarEventsProvider),
            onEventTap: openEvent,
          ),
          DiscoverAsyncRail(
            title: 'Recently Viewed',
            subtitle: 'Pick up where you left off',
            asyncEvents: ref.watch(discoverRecentlyViewedEventsProvider),
            onEventTap: openEvent,
          ),
          DiscoverAsyncRail(
            title: 'Popular Near You',
            subtitle: 'High demand nearby',
            asyncEvents: ref.watch(discoverPopularNearYouProvider),
            onEventTap: openEvent,
          ),
          categoriesAsync.when(
            data: (categories) {
              final cats = categories.where((c) => c != 'all').toList();
              if (cats.isEmpty) return const SizedBox.shrink();
              return EosSection(
                title: 'Categories',
                subtitle: 'Jump to a vibe',
                child: Wrap(
                  spacing: context.eos.spacing.xs,
                  runSpacing: context.eos.spacing.xs,
                  children: [
                    for (final cat in cats)
                      ActionChip(
                        label: Text(cat),
                        onPressed: () => ref.read(discoverCategoryProvider.notifier).state = cat,
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          SizedBox(height: context.eos.spacing.xl),
        ],
      ),
    );
  }
}
