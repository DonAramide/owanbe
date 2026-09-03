import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/vendors_api.dart';
import '../../../eos/eos.dart';
import '../../../features/vendor/providers/vendor_providers.dart';
import '../models/marketplace_filters.dart';
import '../models/marketplace_models.dart';
import '../models/vendor_crm_models.dart';
import '../providers/marketplace_providers.dart';
import '../providers/rentals_providers.dart';
import '../providers/vendor_crm_providers.dart';
import '../navigation/event_navigator.dart';
import '../workspace/widgets/event_friendly_errors.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/marketplace/marketplace_filter_bar.dart';
import '../widgets/marketplace/premium_vendor_card.dart';
import 'marketplace_rentals_screen.dart';
import '../widgets/section_header.dart';

/// Premium vendor marketplace at `/vendors`.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({
    super.key,
    this.eventId,
    this.initialCategory,
    this.vendorBuyerMode = false,
    this.buyerVendorId,
    this.initialTab = 0,
  });

  /// When set, vendor requests and back navigation are scoped to this event.
  final String? eventId;

  /// Service category from planning task (e.g. Catering, DJ, Photographer).
  final String? initialCategory;

  final bool vendorBuyerMode;
  final String? buyerVendorId;
  final int initialTab;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  List<({String id, String title})> _buyerEvents = const [];

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory?.trim();
    if (category != null && category.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = ref.read(marketplaceFiltersProvider);
        ref.read(marketplaceFiltersProvider.notifier).state = current.copyWith(
          serviceCategory: category,
        );
      });
    }
    if (widget.vendorBuyerMode) {
      _loadBuyerEvents();
    }
  }

  Future<void> _loadBuyerEvents() async {
    try {
      final items = await ref.read(rentalsApiProvider).fetchBuyerEligibleEvents();
      if (!mounted) return;
      setState(() => _buyerEvents = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _buyerEvents = const []);
    }
  }

  void _selectBuyerEvent(String eventId) {
    context.go('/vendors?eventId=${Uri.encodeComponent(eventId)}&vendorBuyer=1');
  }

  Widget _buildVendorBuyerEventPicker(String? eventId) {
    final selected = eventId != null && eventId.isNotEmpty ? eventId : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('${_buyerEvents.length}-$selected'),
          initialValue: _buyerEvents.any((e) => e.id == selected) ? selected : null,
          decoration: const InputDecoration(
            labelText: 'Associated event',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final e in _buyerEvents)
              DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v != null) _selectBuyerEvent(v);
          },
        ),
        if (_buyerEvents.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: context.eos.spacing.sm),
            child: Text(
              'Select an associated event to request services or book rentals. '
              'Accept a booking request or participation first. No event is invented.',
              style: context.eosText.bodySmall,
            ),
          )
        else if (selected == null)
          Padding(
            padding: EdgeInsets.only(top: context.eos.spacing.sm),
            child: Text(
              'Choose an event to request or rent. You can still browse the catalogue.',
              style: context.eosText.bodySmall,
            ),
          ),
      ],
    );
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (widget.vendorBuyerMode) {
      context.go('/vendor');
    } else if (widget.eventId != null && widget.eventId!.isNotEmpty) {
      context.eventNav.backToOverview(widget.eventId!);
    } else {
      context.eventNav.goHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId;
    final currentVendorId = widget.vendorBuyerMode
        ? ref.watch(canonicalVendorIdProvider).valueOrNull
        : null;
    final vendors = ref.watch(marketplaceVendorsProvider);
    final discover = ref.watch(marketplaceDiscoverVendorsProvider(eventId));
    final categories = ref.watch(marketplaceCategoriesProvider);
    final cities = ref.watch(marketplaceCitiesProvider);
    final guestCount = ref.watch(marketplaceExpectedGuestsProvider);
    final filters = ref.watch(marketplaceFiltersProvider);
    final booked = eventId != null && eventId.isNotEmpty
        ? ref.watch(eventBookedVendorRequestsProvider(eventId))
        : const <VendorRequest>[];

    final categoryTitle = filters.serviceCategory != 'All' ? filters.serviceCategory : null;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(context),
          ),
          title: Text(
            categoryTitle != null ? '$categoryTitle marketplace' : 'Marketplace',
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Services'),
              Tab(text: 'Rentals'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBody(context, vendors, discover, categories, cities, guestCount, filters, booked, eventId),
            MarketplaceRentalsScreen(
              eventId: eventId,
              vendorBuyerMode: widget.vendorBuyerMode,
              buyerVendorId: currentVendorId ?? widget.buyerVendorId,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<MarketplaceVendor>> vendors,
    List<MarketplaceVendor> discover,
    List<String> categories,
    List<String> cities,
    int guestCount,
    MarketplaceFilters filters,
    List<VendorRequest> booked,
    String? eventId,
  ) {
    if (vendors.isLoading && !vendors.hasValue) {
      return const EventLoadingSkeleton(variant: EventLoadingVariant.list);
    }
    if (vendors.hasError && !vendors.hasValue) {
      return ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          EmptyStateCard(
            title: EventFriendlyErrors.genericHeadline,
            message: EventFriendlyErrors.genericMessage,
            actionLabel: 'Back home',
            onAction: () => context.eventNav.goHome(),
          ),
        ],
      );
    }

    final categoryTitle = filters.serviceCategory != 'All' ? filters.serviceCategory : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketplaceVendorsProvider);
        if (eventId != null) {
          refreshVendorCrm(ref);
          ref.invalidate(eventVendorCrmProvider(eventId));
        }
        await ref.read(marketplaceVendorsProvider.future);
      },
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              SectionHeader(
                title: categoryTitle != null
                    ? 'Find $categoryTitle vendors'
                    : 'Find your dream team',
                subtitle: categoryTitle != null
                    ? 'Only vendors matching $categoryTitle. Booked vendors are listed separately.'
                    : 'Search by service, name, city, price, or rating.',
              ),
              if (widget.vendorBuyerMode) ...[
                SizedBox(height: context.eos.spacing.md),
                _buildVendorBuyerEventPicker(eventId),
              ],
              SizedBox(height: context.eos.spacing.md),
              MarketplaceFilterBar(categories: categories, cities: cities),
              SizedBox(height: context.eos.spacing.sm),
              Text(
                'Expected attendees: $guestCount (used for per-guest price estimates)',
                style: context.eosText.bodySmall,
              ),
              Slider(
                value: guestCount.toDouble(),
                min: 50,
                max: 500,
                divisions: 18,
                label: '$guestCount',
                onChanged: (v) =>
                    ref.read(marketplaceExpectedGuestsProvider.notifier).state = v.round(),
              ),
              if (booked.isNotEmpty) ...[
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'My Booked Vendors',
                  subtitle: 'Already requested or booked for this event — not shown in discovery.',
                ),
                SizedBox(height: context.eos.spacing.sm),
                for (final req in booked)
                  Card(
                    margin: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: ListTile(
                      title: Text(req.vendorName ?? 'Vendor'),
                      subtitle: Text(
                        [
                          if (req.serviceLabel != null && req.serviceLabel!.isNotEmpty) req.serviceLabel!,
                          vendorCrmStageLabels[req.stage] ?? req.stage,
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: eventId == null
                          ? null
                          : () => context.eventNav.openVendorPipeline(eventId),
                    ),
                  ),
              ],
              SizedBox(height: context.eos.spacing.lg),
              Text(
                '${discover.length} available vendor${discover.length == 1 ? '' : 's'}',
                style: context.eosText.labelLarge,
              ),
              SizedBox(height: context.eos.spacing.sm),
              if (discover.isEmpty)
                EmptyStateCard(
                  title: 'No vendors found',
                  message: categoryTitle != null
                      ? 'No available $categoryTitle vendors match your filters.'
                      : 'Try another service, city, or filter.',
                  icon: Icons.storefront_outlined,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = EosResponsive.columnsFor(context).clamp(1, 3);
                    final width =
                        (constraints.maxWidth - (columns - 1) * context.eos.spacing.md) / columns;

                    return Wrap(
                      spacing: context.eos.spacing.md,
                      runSpacing: context.eos.spacing.md,
                      children: [
                        for (final vendor in discover)
                          SizedBox(
                            width: width,
                            child: PremiumVendorCard(
                              vendor: vendor,
                              coverColorStart: buildVendorProfile(vendor).coverColorStart,
                              coverColorEnd: buildVendorProfile(vendor).coverColorEnd,
                              priceLabel: buildVendorProfile(vendor).priceLabel,
                              guestCount: guestCount,
                              onTap: () {
                                final q = <String>[
                                  if (eventId != null && eventId.isNotEmpty)
                                    'eventId=${Uri.encodeComponent(eventId)}',
                                  if (filters.serviceCategory != 'All')
                                    'service=${Uri.encodeComponent(filters.serviceCategory)}',
                                  if (widget.vendorBuyerMode) 'vendorBuyer=1',
                                ].join('&');
                                context.push('/vendors/${vendor.id}${q.isEmpty ? '' : '?$q'}');
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              SizedBox(height: context.eos.spacing.xl),
            ],
          ),
          if (vendors.isRefreshing)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
