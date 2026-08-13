import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/vendors_api.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/marketplace_filters.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_providers.dart';
import '../navigation/event_navigator.dart';
import '../workspace/widgets/event_friendly_errors.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/marketplace/request_vendor_sheet.dart';
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
  });

  final String vendorId;

  /// Active event when opened from Event Desktop marketplace.
  final String? eventId;

  /// Originating marketplace filter (service name) — preserved across navigation.
  final String? initialService;

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
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
          final services = data.vendor.services;
          final selected = _resolveSelected(services, originating);
          return VendorContactBar(
            vendorName: data.vendor.businessName,
            phone: data.phone,
            onRequest: () => _requestService(
              context,
              ref,
              vendor: data.vendor,
              service: selected,
              fallbackLabel: originating ?? data.vendor.categoryLabel,
            ),
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
          final services = vendor.services;
          final selected = _resolveSelected(services, originating);

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
                title: 'Services Offered',
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
                  final isSelected = selected?.id == service.id;
                  final price = service.priceFromMinor;
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: EosSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  service.serviceName,
                                  style: context.eosText.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
                          if (price != null && price > 0) ...[
                            SizedBox(height: context.eos.spacing.xxs),
                            Text(
                              formatRevenue(price),
                              style: context.eosText.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          SizedBox(height: context.eos.spacing.sm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton(
                              onPressed: () => _requestService(
                                context,
                                ref,
                                vendor: vendor,
                                service: service,
                              ),
                              child: Text('Request ${service.serviceName}'),
                            ),
                          ),
                        ],
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
