import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/marketplace_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/marketplace/request_vendor_sheet.dart';
import '../widgets/marketplace/vendor_contact_bar.dart';
import '../widgets/marketplace/vendor_metrics_row.dart';
import '../widgets/marketplace/vendor_reviews_list.dart';
import '../widgets/marketplace/verified_vendor_badge.dart';
import '../widgets/section_header.dart';

/// Vendor detail at `/vendors/:vendorId`.
class MarketplaceVendorDetailScreen extends ConsumerWidget {
  const MarketplaceVendorDetailScreen({super.key, required this.vendorId});

  final String vendorId;

  Future<void> _requestVendor(BuildContext context, WidgetRef ref) async {
    final profile = await ref.read(marketplaceVendorProfileProvider(vendorId).future);
    if (!context.mounted) return;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RequestVendorSheet(vendor: profile.vendor),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor request sent for your event')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(marketplaceVendorProfileProvider(vendorId));

    return Scaffold(
      backgroundColor: EosColors.canvas,
      appBar: AppBar(
        backgroundColor: EosColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(CustomerRoutes.vendors);
            }
          },
        ),
        title: const Text('Vendor profile'),
      ),
      bottomNavigationBar: profile.maybeWhen(
        data: (data) => VendorContactBar(
          vendorName: data.vendor.businessName,
          phone: data.phone,
          onRequest: () => _requestVendor(context, ref),
        ),
        orElse: () => null,
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Vendor not found',
              message: error.toString(),
              actionLabel: 'Browse vendors',
              onAction: () => context.go(CustomerRoutes.vendors),
            ),
          ],
        ),
        data: (data) {
          final vendor = data.vendor;
          return ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: EosRadius.card,
                  gradient: LinearGradient(
                    colors: [Color(data.coverColorStart), Color(data.coverColorEnd)],
                  ),
                ),
                padding: EdgeInsets.all(context.eos.spacing.lg),
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
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
                  if (data.priceLabel != null)
                    Text(data.priceLabel!, style: context.eosText.titleSmall),
                ],
              ),
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
                  vendor.description ?? 'Premium celebration partner on Owanbe.',
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
