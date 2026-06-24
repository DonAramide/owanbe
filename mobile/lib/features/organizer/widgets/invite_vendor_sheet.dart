import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/vendors_api.dart';
import '../../../eos/eos.dart';
import '../../../portals/customer/models/marketplace_models.dart';
import '../../../portals/customer/providers/marketplace_providers.dart';
import '../../../portals/customer/widgets/marketplace/verified_vendor_badge.dart';
import '../data/organizer_persistence.dart';
import '../models/organizer_models.dart';

/// Opens a marketplace vendor picker to invite a vendor to an event.
Future<bool?> showInviteVendorSheet(
  BuildContext context, {
  required String eventId,
  required Set<String> alreadyInvitedCatalogIds,
  required Set<String> alreadyInvitedNames,
  String? cityHint,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => InviteVendorSheet(
      eventId: eventId,
      alreadyInvitedCatalogIds: alreadyInvitedCatalogIds,
      alreadyInvitedNames: alreadyInvitedNames,
      cityHint: cityHint,
    ),
  );
}

class InviteVendorSheet extends ConsumerStatefulWidget {
  const InviteVendorSheet({
    super.key,
    required this.eventId,
    required this.alreadyInvitedCatalogIds,
    required this.alreadyInvitedNames,
    this.cityHint,
  });

  final String eventId;
  final Set<String> alreadyInvitedCatalogIds;
  final Set<String> alreadyInvitedNames;
  final String? cityHint;

  @override
  ConsumerState<InviteVendorSheet> createState() => _InviteVendorSheetState();
}

class _InviteVendorSheetState extends ConsumerState<InviteVendorSheet> {
  final _searchController = TextEditingController();
  String _category = 'All';
  String? _selectedVendorId;
  var _submitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isInvited(MarketplaceVendor vendor) {
    return widget.alreadyInvitedCatalogIds.contains(vendor.id) ||
        widget.alreadyInvitedNames.contains(vendor.businessName.toLowerCase());
  }

  Future<void> _sendInvite(MarketplaceVendor vendor) async {
    setState(() => _submitting = true);
    try {
      await inviteVendor(ref, widget.eventId, vendor);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to ${vendor.businessName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<MarketplaceVendor> _filter(List<MarketplaceVendor> vendors) {
    final query = _searchController.text.trim().toLowerCase();
    var list = vendors;
    if (_category != 'All') {
      list = list.where((v) => v.matchesService(_category)).toList();
    }
    if (widget.cityHint != null && widget.cityHint!.trim().isNotEmpty) {
      final city = widget.cityHint!.trim().toLowerCase();
      list = list
          .where((v) => (v.city ?? '').toLowerCase().contains(city) || (v.city ?? '').isEmpty)
          .toList();
    }
    if (query.isNotEmpty) {
      list = list.where((v) {
        final hay = '${v.businessName} ${v.categoryLabel} ${v.city ?? ''}'.toLowerCase();
        return hay.contains(query);
      }).toList();
    }
    list.sort((a, b) => (b.ratingAverage ?? 0).compareTo(a.ratingAverage ?? 0));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(marketplaceVendorsProvider);
    final categories = ref.watch(marketplaceCategoriesProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.eos.spacing.lg,
                context.eos.spacing.md,
                context.eos.spacing.lg,
                context.eos.spacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite vendor', style: context.eosText.titleLarge),
                  SizedBox(height: context.eos.spacing.xxs),
                  Text(
                    'Choose from the marketplace — ratings, pricing, and category included.',
                    style: context.eosText.bodySmall,
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search vendors…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.xs),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return FilterChip(
                          label: Text(cat),
                          selected: _category == cat,
                          onSelected: (_) => setState(() => _category = cat),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: vendorsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load vendors: $e')),
                data: (all) {
                  final vendors = _filter(all);
                  if (vendors.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.eos.spacing.lg),
                        child: Text(
                          'No vendors match your search. Try another category or clear filters.',
                          style: context.eosText.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg),
                    itemCount: vendors.length,
                    separatorBuilder: (_, _) => SizedBox(height: context.eos.spacing.sm),
                    itemBuilder: (context, index) {
                      final vendor = vendors[index];
                      final invited = _isInvited(vendor);
                      final selected = _selectedVendorId == vendor.id;
                      return _VendorInviteTile(
                        vendor: vendor,
                        selected: selected,
                        invited: invited,
                        onTap: invited
                            ? null
                            : () => setState(() => _selectedVendorId = vendor.id),
                      );
                    },
                  );
                },
              ),
            ),
            vendorsAsync.maybeWhen(
              data: (all) {
                final matches = all.where((v) => v.id == _selectedVendorId);
                final selected = matches.isEmpty ? null : matches.first;
                if (selected == null) {
                  return Padding(
                    padding: EdgeInsets.all(context.eos.spacing.lg),
                    child: Text(
                      'Select a vendor to send an invite',
                      style: context.eosText.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return _InviteFooter(
                  vendor: selected,
                  submitting: _submitting,
                  onSend: () => _sendInvite(selected),
                  onCancel: () => Navigator.pop(context),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorInviteTile extends StatelessWidget {
  const _VendorInviteTile({
    required this.vendor,
    required this.selected,
    required this.invited,
    this.onTap,
  });

  final MarketplaceVendor vendor;
  final bool selected;
  final bool invited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final profile = buildVendorProfile(vendor);
    final imageUrl = vendor.imageUrl ?? vendorCoverImageUrl(vendor);

    return EosSurfaceCard(
      elevated: selected,
      onTap: onTap,
      child: Opacity(
        opacity: invited ? 0.55 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              invited
                  ? Icons.block
                  : selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
              color: invited
                  ? context.eosColors.onSurfaceVariant
                  : selected
                      ? context.eosColors.primary
                      : context.eosColors.outline,
            ),
            SizedBox(width: context.eos.spacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 64,
                  height: 64,
                  color: Color(profile.coverColorStart),
                  child: Icon(Icons.storefront, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(vendor.businessName, style: context.eosText.titleSmall)),
                      if (vendor.isVerified) const VerifiedVendorBadge(compact: true),
                      if (invited) ...[
                        SizedBox(width: context.eos.spacing.xs),
                        Chip(
                          label: const Text('Invited'),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                  Text(vendor.categoryLabel, style: context.eosText.bodySmall),
                  SizedBox(height: context.eos.spacing.xxs),
                  Row(
                    children: [
                      if (vendor.ratingAverage != null) ...[
                        Icon(Icons.star_rounded, size: 16, color: EosColors.champagne),
                        Text(' ${vendor.ratingAverage!.toStringAsFixed(1)}', style: context.eosText.bodySmall),
                      ],
                      if (vendor.city != null) ...[
                        const SizedBox(width: 8),
                        Text('· ${vendor.city}', style: context.eosText.bodySmall),
                      ],
                    ],
                  ),
                  if (profile.priceLabel != null) ...[
                    SizedBox(height: context.eos.spacing.xxs),
                    Text(profile.priceLabel!, style: context.eosText.labelMedium),
                  ],
                  if (profile.pricePerGuestLabel(150).isNotEmpty)
                    Text(profile.pricePerGuestLabel(150), style: context.eosText.bodySmall),
                  if (vendor.description != null && vendor.description!.isNotEmpty) ...[
                    SizedBox(height: context.eos.spacing.xxs),
                    Text(
                      vendor.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.eosText.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteFooter extends StatelessWidget {
  const _InviteFooter({
    required this.vendor,
    required this.submitting,
    required this.onSend,
    required this.onCancel,
  });

  final MarketplaceVendor vendor;
  final bool submitting;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invite ${vendor.businessName}?', style: context.eosText.titleSmall),
            Text(
              '${vendor.categoryLabel}${vendor.city != null ? ' · ${vendor.city}' : ''}',
              style: context.eosText.bodySmall,
            ),
            SizedBox(height: context.eos.spacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: submitting ? null : onCancel, child: const Text('Cancel')),
                ),
                SizedBox(width: context.eos.spacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: submitting ? null : onSend,
                    child: Text(submitting ? 'Sending…' : 'Send invite'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Set<String> invitedCatalogIdsFromEvent(OrganizerEvent event) {
  return event.vendors.map((v) => v.catalogVendorId).whereType<String>().toSet();
}

Set<String> invitedVendorNamesFromEvent(OrganizerEvent event) {
  return event.vendors.map((v) => v.businessName.toLowerCase()).toSet();
}
