import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/vendor_availability_display.dart';
import '../../../core/api/vendors_api.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../features/vendor/providers/vendor_providers.dart';
import '../models/marketplace_filters.dart';
import '../models/marketplace_models.dart';
import '../models/marketplace_offering_context.dart';
import '../providers/customer_event_providers.dart';
import '../providers/marketplace_providers.dart';
import '../navigation/event_navigator.dart';
import '../workspace/widgets/event_friendly_errors.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/marketplace/request_vendor_sheet.dart';
import '../widgets/marketplace/vendor_availability_list.dart';
import '../widgets/marketplace/vendor_contact_bar.dart';
import '../widgets/marketplace/vendor_metrics_row.dart';
import '../widgets/marketplace/vendor_reviews_list.dart';
import '../widgets/marketplace/verified_vendor_badge.dart';
import '../widgets/section_header.dart';

/// Vendor detail at `/vendors/:vendorId`.
class MarketplaceVendorDetailScreen extends ConsumerWidget {
  const MarketplaceVendorDetailScreen({
    super.key,
    required this.vendorId,
    this.eventId,
    this.initialService,
    this.vendorBuyerMode = false,
  });

  final String vendorId;

  /// Active event when opened from Event Desktop marketplace.
  final String? eventId;

  /// Originating marketplace filter (service name) — preserved across navigation.
  final String? initialService;

  /// Vendor browsing as buyer. Service CRM requests stay organizer-only.
  final bool vendorBuyerMode;

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (vendorBuyerMode) {
      final q = <String>['vendorBuyer=1'];
      if (eventId != null && eventId!.isNotEmpty) {
        q.insert(0, 'eventId=${Uri.encodeComponent(eventId!)}');
      }
      context.go('/vendors?${q.join('&')}');
    } else if (eventId != null && eventId!.isNotEmpty) {
      context.eventNav.openMarketplace(eventId: eventId);
    } else {
      context.eventNav.openMarketplace();
    }
  }

  String? _originatingService(WidgetRef ref) {
    final fromRoute = initialService?.trim();
    if (fromRoute != null && fromRoute.isNotEmpty && fromRoute != 'All') {
      return fromRoute;
    }
    final filterCategory = ref.read(marketplaceFiltersProvider).serviceCategory;
    if (filterCategory != 'All' && filterCategory.trim().isNotEmpty) {
      return filterCategory.trim();
    }
    return null;
  }

  MarketplaceVendorService? _resolveSelected(
    List<MarketplaceVendorService> services,
    String? originating,
  ) {
    if (originating == null || originating.isEmpty) return null;
    for (final s in services) {
      if (s.matchesLabel(originating)) return s;
    }
    return null;
  }

  Future<void> _requestService(
    BuildContext context,
    WidgetRef ref, {
    required MarketplaceVendor vendor,
    MarketplaceVendorService? service,
    String? fallbackLabel,
  }) async {
    if (vendorBuyerMode && (eventId == null || eventId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an associated event before requesting a service')),
      );
      return;
    }
    if (vendorBuyerMode) {
      final sent = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => RequestVendorSheet(
          vendor: vendor,
          lockedEventId: eventId,
          serviceCategory: service?.serviceName ?? fallbackLabel ?? vendor.categoryLabel,
          serviceKey: service?.serviceKey,
          vendorServiceId: service?.id,
          vendorBuyerMode: true,
        ),
      );
      if (sent == true && context.mounted) {
        final name = service?.serviceName ?? fallbackLabel ?? 'service';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request sent for $name')),
        );
      }
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RequestVendorSheet(
        vendor: vendor,
        lockedEventId: eventId,
        serviceCategory: service?.serviceName ?? fallbackLabel ?? vendor.categoryLabel,
        serviceKey: service?.serviceKey,
        vendorServiceId: service?.id,
      ),
    );
    if (sent == true && context.mounted) {
      final name = service?.serviceName ?? fallbackLabel ?? 'service';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent for $name')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(marketplaceVendorProfileProvider(vendorId));
    final originating = _originatingService(ref);
    final lockedEventId = eventId;
    final currentVendorId = vendorBuyerMode
        ? ref.watch(canonicalVendorIdProvider).valueOrNull
        : null;
    final ownOffering = isMarketplaceOwnOffering(
      offeringVendorId: vendorId,
      currentVendorId: currentVendorId,
    );
    final eventAwareServices = lockedEventId != null && lockedEventId.isNotEmpty
        ? ref.watch(
            marketplaceVendorServicesForEventProvider((vendorId: vendorId, eventId: lockedEventId)),
          )
        : null;
    final event = lockedEventId != null && lockedEventId.isNotEmpty
        ? ref.watch(customerEventProvider(lockedEventId)).valueOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
        title: const Text('Vendor profile'),
      ),
      bottomNavigationBar: profile.maybeWhen(
        data: (data) {
          final services = eventAwareServices?.valueOrNull ?? data.vendor.services;
          final selected = _resolveSelected(services, originating);
          return VendorContactBar(
            vendorName: data.vendor.businessName,
            phone: data.phone,
            onManage: ownOffering ? () => context.push('/vendor/offerings') : null,
            onRequest: ownOffering
                ? null
                : () => _requestService(
                      context,
                      ref,
                      vendor: data.vendor,
                      service: selected,
                      fallbackLabel: originating ?? data.vendor.categoryLabel,
                    ),
            requestLabel: vendorBuyerMode ? 'Request Service' : 'Request',
          );
        },
        orElse: () => null,
      ),
      body: profile.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: EventFriendlyErrors.headlineFor('this vendor'),
              message: EventFriendlyErrors.genericMessage,
              actionLabel: 'Browse vendors',
              onAction: () => context.eventNav.openMarketplace(eventId: eventId),
            ),
          ],
        ),
        data: (data) {
          final vendor = data.vendor;
          final guestCount = ref.watch(marketplaceExpectedGuestsProvider);
          final imageUrl = vendor.imageUrl ?? vendorCoverImageUrl(vendor);
          final services = eventAwareServices?.valueOrNull ?? vendor.services;
          final selected = _resolveSelected(services, originating);
          final windowLabel = event == null ? null : formatDateTimeWindow(event.startsAt, event.endsAt);

          return ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              ClipRRect(
                borderRadius: EosRadius.card,
                child: Stack(
                  children: [
                    Image.network(
                      imageUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(data.coverColorStart), Color(data.coverColorEnd)],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: context.eos.spacing.lg,
                      right: context.eos.spacing.lg,
                      bottom: context.eos.spacing.lg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data.isVerified) ...[
                            const VerifiedVendorBadge(),
                            SizedBox(height: context.eos.spacing.sm),
                          ],
                          Text(
                            vendor.businessName,
                            style: context.eosText.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${vendor.categoryLabel}${vendor.city != null ? ' · ${vendor.city}' : ''}',
                            style: context.eosText.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                    if (vendorPreviewVideoUrl(vendor) != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Opening vendor highlight reel…')),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Watch reel'),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: context.eos.spacing.md),
              Row(
                children: [
                  Icon(Icons.star_rounded, color: EosColors.champagne),
                  SizedBox(width: context.eos.spacing.xxs),
                  Text(
                    '${data.rating.toStringAsFixed(1)} · ${data.reviewCount} reviews',
                    style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Builder(
                    builder: (context) {
                      final priced = services
                          .map((s) => s.priceFromMinor)
                          .whereType<int>()
                          .where((p) => p > 0)
                          .toList()
                        ..sort();
                      if (priced.isNotEmpty) {
                        return Text(
                          'From ${formatRevenue(priced.first)}',
                          style: context.eosText.titleSmall,
                        );
                      }
                      if (data.priceLabel != null) {
                        return Text(data.priceLabel!, style: context.eosText.titleSmall);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              if (data.pricePerGuestLabel(guestCount).isNotEmpty) ...[
                SizedBox(height: context.eos.spacing.xs),
                Text(data.pricePerGuestLabel(guestCount), style: context.eosText.bodySmall),
              ],
              SizedBox(height: context.eos.spacing.lg),
              SectionHeader(
                title: 'Vendor Services',
                subtitle: () {
                  final priced = services
                      .map((s) => s.priceFromMinor)
                      .whereType<int>()
                      .where((p) => p > 0)
                      .toList();
                  if (priced.isEmpty) {
                    return 'Request one specific service from this vendor.';
                  }
                  priced.sort();
                  return '${services.length} service${services.length == 1 ? '' : 's'} · From ${formatRevenue(priced.first)}';
                }(),
              ),
              if (windowLabel != null) ...[
                SizedBox(height: context.eos.spacing.sm),
                EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR EVENT', style: context.eosText.labelSmall),
                      SizedBox(height: context.eos.spacing.xxs),
                      Text(event?.title ?? 'Event', style: context.eosText.titleSmall),
                      Text(windowLabel, style: context.eosText.bodyMedium),
                    ],
                  ),
                ),
                SizedBox(height: context.eos.spacing.md),
              ],
              // Legacy starting_price is display metadata only — never the commercial source.
              if (services.isEmpty)
                EosSurfaceCard(
                  child: Text(
                    vendor.servicesOffered.isEmpty
                        ? 'No services listed yet for this vendor.'
                        : vendor.servicesOffered.join(' · '),
                    style: context.eosText.bodyMedium,
                  ),
                )
              else
                ...services.map((service) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child:                     _ServiceAvailabilityCard(
                      vendorId: vendor.id,
                      vendorName: vendor.businessName,
                      service: service,
                      isSelected: selected?.id == service.id,
                      isOwnOffering: ownOffering,
                      onManage: () => context.push('/vendor/offerings'),
                      onRequest: () => _requestService(
                        context,
                        ref,
                        vendor: vendor,
                        service: service,
                      ),
                    ),
                  );
                }),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Vendor metrics',
                subtitle: 'Trust signals from real celebrations.',
              ),
              VendorMetricsRow(metrics: data.metrics),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'About',
                subtitle: 'What makes this vendor special.',
              ),
              EosSurfaceCard(
                child: Text(
                  vendor.description ?? 'Premium celebration partner on Owambe.',
                  style: context.eosText.bodyMedium,
                ),
              ),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Reviews',
                subtitle: 'What hosts are saying.',
              ),
              VendorReviewsList(reviews: data.reviews, averageRating: data.rating),
              SizedBox(height: context.eos.spacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceAvailabilityCard extends ConsumerWidget {
  const _ServiceAvailabilityCard({
    required this.vendorId,
    required this.vendorName,
    required this.service,
    required this.isSelected,
    required this.onRequest,
    this.isOwnOffering = false,
    this.onManage,
  });

  final String vendorId;
  final String vendorName;
  final MarketplaceVendorService service;
  final bool isSelected;
  final VoidCallback onRequest;
  final bool isOwnOffering;
  final VoidCallback? onManage;

  MarketplaceVendorService? _matchRangeService(List<MarketplaceVendorService> items) {
    for (final item in items) {
      if (item.id == service.id) return item;
    }
    for (final item in items) {
      if (item.serviceKey.toLowerCase() == service.serviceKey.toLowerCase()) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = service.priceFromMinor;
    final availability = formatServiceAvailability(service.availabilityStatus);
    final blocked = serviceWindowBlocksNewRequest(service.availabilityStatus);
    final eventRanges = service.bookedRanges;
    final conflictNote = availabilityConflictExplanation(service.availabilityStatus, eventRanges);
    final showEventAvailability = availability.isNotEmpty;
    final displayRange = organizerAvailabilityDisplayRange();
    final rangeAsync = ref.watch(
      marketplaceVendorServicesForRangeProvider((
        vendorId: vendorId,
        from: displayRange.from.toUtc().toIso8601String(),
        to: displayRange.to.toUtc().toIso8601String(),
      )),
    );
    final rangeService = rangeAsync.valueOrNull == null ? null : _matchRangeService(rangeAsync.valueOrNull!);
    final browserRanges = rangeService?.bookedRanges ?? const <BookedRange>[];
    final overlayRanges = rangeService?.unavailableRanges ?? const <BookedRange>[];

    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(vendorName, style: context.eosText.labelSmall),
          SizedBox(height: context.eos.spacing.xxs),
          Row(
            children: [
              Expanded(
                child: Text(
                  service.serviceName,
                  style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(
                label: Text(
                  service.offerStatus.toLowerCase() == 'active' ? 'Active' : 'Inactive',
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              if (isSelected)
                Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: const Text('Selected'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          if (service.serviceCode != null && service.serviceCode!.trim().isNotEmpty)
            Text('Service Code: ${service.serviceCode}', style: context.eosText.bodySmall),
          if (price != null && price > 0) ...[
            SizedBox(height: context.eos.spacing.xxs),
            Text(
              formatRevenue(price),
              style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (showEventAvailability) ...[
            SizedBox(height: context.eos.spacing.sm),
            Text('VENDOR AVAILABILITY', style: context.eosText.labelSmall),
            SizedBox(height: context.eos.spacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(availability),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: blocked ? Colors.red.withValues(alpha: 0.12) : null,
              ),
            ),
            if (conflictNote != null) ...[
              SizedBox(height: context.eos.spacing.xs),
              Text(conflictNote, style: context.eosText.bodySmall),
            ],
          ],
          SizedBox(height: context.eos.spacing.sm),
          if (rangeAsync.isLoading)
            const LinearProgressIndicator()
          else
            NextBookedSummary(
              bookedRanges: browserRanges,
            ),
          if (service.capabilities.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.xs),
            Text('Provided by this vendor', style: context.eosText.labelSmall),
            for (final cap in service.capabilities)
              Text('✓ ${cap.label}', style: context.eosText.bodySmall),
          ],
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: context.eos.spacing.sm,
            runSpacing: context.eos.spacing.xs,
            children: [
              OutlinedButton(
                onPressed: rangeAsync.hasValue
                    ? () => showVendorAvailabilitySheet(
                          context,
                          vendorName: vendorName,
                          serviceName: service.serviceName,
                          serviceCode: service.serviceCode,
                          from: displayRange.from,
                          to: displayRange.to,
                          bookedRanges: browserRanges,
                          unavailableRanges: overlayRanges,
                          availabilityStatus: rangeService?.availabilityStatus,
                        )
                    : null,
                child: const Text('View Availability'),
              ),
              if (isOwnOffering)
                FilledButton(
                  onPressed: onManage,
                  child: const Text('Manage'),
                )
              else
                FilledButton(
                  onPressed: blocked ? null : onRequest,
                  child: Text(blocked ? availability : 'Request ${service.serviceName}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
