import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';

String formatVendorDate(DateTime dt) =>
    '${dt.month}/${dt.day}/${dt.year} · ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

String formatVendorMoney(int minor) => ngnFromMinor(minor.toString());

String moneyAmountForEos(int minor) => ngnFromMinor(minor.toString()).replaceFirst('₦', '');

/// EOS-formatted currency display for vendor finance surfaces.
class VendorMoneyText extends StatelessWidget {
  const VendorMoneyText({super.key, required this.minor, this.compact = false, this.color});

  final int minor;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return EosMoneyText(
      amount: moneyAmountForEos(minor),
      currency: '₦',
      compact: compact,
      color: color,
    );
  }
}

String participationChipLabel(VendorParticipationStatus status) => switch (status) {
      VendorParticipationStatus.invited => 'invited',
      VendorParticipationStatus.pending => 'applied',
      VendorParticipationStatus.confirmed => 'approved',
      VendorParticipationStatus.live => 'live',
      VendorParticipationStatus.completed => 'completed',
      VendorParticipationStatus.declined => 'declined',
    };

String lifecycleTitle(ParticipationLifecycle stage) => switch (stage) {
      ParticipationLifecycle.invited => 'Invited',
      ParticipationLifecycle.applied => 'Applied',
      ParticipationLifecycle.approved => 'Approved',
      ParticipationLifecycle.completed => 'Completed',
    };

EosKpiAttention attentionForParticipation(VendorParticipationStatus status) => switch (status) {
      VendorParticipationStatus.invited => EosKpiAttention.warning,
      VendorParticipationStatus.pending => EosKpiAttention.info,
      VendorParticipationStatus.live => EosKpiAttention.critical,
      VendorParticipationStatus.confirmed => EosKpiAttention.none,
      _ => EosKpiAttention.none,
    };

IconData catalogTypeIcon(VendorCatalogType? type) => switch (type) {
      VendorCatalogType.catering => Icons.restaurant_menu,
      VendorCatalogType.photography => Icons.camera_alt_outlined,
      VendorCatalogType.decoration => Icons.celebration_outlined,
      VendorCatalogType.entertainment => Icons.music_note_outlined,
      VendorCatalogType.security => Icons.security_outlined,
      VendorCatalogType.rentals => Icons.chair_outlined,
      VendorCatalogType.beauty => Icons.face_retouching_natural_outlined,
      VendorCatalogType.fashionAttire => Icons.checkroom_outlined,
      VendorCatalogType.rentalsEquipment => Icons.inventory_2_outlined,
      VendorCatalogType.logistics => Icons.local_shipping_outlined,
      null => Icons.inventory_2_outlined,
    };

IconData catalogTypeIconFromLabel(String category) =>
    catalogTypeIcon(VendorCatalogType.fromLabel(category));

class VendorEventPicker extends ConsumerWidget {
  const VendorEventPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participations = ref.watch(vendorParticipationsProvider);
    final selected = ref.watch(selectedVendorEventIdProvider);

    return participations.when(
      data: (list) {
        if (list.isEmpty) {
          return EosSurfaceCard(
            child: Text('Join an event to filter by event', style: context.eosText.bodyMedium),
          );
        }
        final value = selected ?? list.first.eventId;
        if (selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedVendorEventIdProvider.notifier).state = list.first.eventId;
          });
        }
        return EosSelectField<String>(
          label: 'Event context',
          value: value,
          items: [
            for (final p in list)
              DropdownMenuItem(value: p.eventId, child: Text(p.eventTitle, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (id) => ref.read(selectedVendorEventIdProvider.notifier).state = id,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
    );
  }
}

class VendorCatalogCard extends StatelessWidget {
  const VendorCatalogCard({
    super.key,
    required this.item,
    this.onToggle,
    this.onTap,
  });

  final VendorCatalogItem item;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = VendorCatalogType.fromLabel(item.category);
    return EosSurfaceCard(
      onTap: onTap,
      elevated: true,
      accentColor: item.status == VendorCatalogStatus.paused ? EosColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.eos.spacing.sm),
                decoration: BoxDecoration(
                  color: context.eosColors.primaryContainer,
                  borderRadius: context.eos.radius.input,
                ),
                child: Icon(catalogTypeIcon(type), color: context.eosColors.primary, size: 22),
              ),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: context.eosText.titleSmall),
                    Text(item.category, style: context.eosText.labelSmall),
                  ],
                ),
              ),
              EosFinanceChip(
                label: item.status == VendorCatalogStatus.active ? 'active' : 'paused',
                compact: true,
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(item.description, style: context.eosText.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          SizedBox(height: context.eos.spacing.md),
          Row(
            children: [
              VendorMoneyText(minor: item.priceMinor, compact: true),
              const Spacer(),
              Text('${item.ordersCount} orders', style: context.eosText.bodySmall),
              if (onToggle != null) ...[
                SizedBox(width: context.eos.spacing.sm),
                IconButton(onPressed: onToggle, icon: const Icon(Icons.toggle_on_outlined, size: 20)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class VendorOrderCard extends StatelessWidget {
  const VendorOrderCard({
    super.key,
    required this.order,
    this.onAccept,
    this.onFulfill,
  });

  final VendorOrder order;
  final VoidCallback? onAccept;
  final VoidCallback? onFulfill;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      accentColor: order.status == VendorOrderStatus.newOrder ? EosColors.info : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(order.itemName, style: context.eosText.titleSmall)),
              EosFinanceChip(label: order.statusLabel, compact: true),
            ],
          ),
          SizedBox(height: context.eos.spacing.xxs),
          Text('Customer: ${order.customerName}', style: context.eosText.bodySmall),
          Text('Event: ${order.eventTitle}', style: context.eosText.bodySmall),
          Text('Package: ${order.itemName}', style: context.eosText.labelSmall),
          if (order.notes != null) ...[
            SizedBox(height: context.eos.spacing.xxs),
            Text(order.notes!, style: context.eosText.labelSmall),
          ],
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              VendorMoneyText(minor: order.amountMinor, compact: true),
              const Spacer(),
              if (order.status == VendorOrderStatus.newOrder && onAccept != null)
                FilledButton(onPressed: onAccept, child: const Text('Accept')),
              if (order.status == VendorOrderStatus.inProgress && onFulfill != null)
                FilledButton(onPressed: onFulfill, child: const Text('Mark fulfilled')),
            ],
          ),
        ],
      ),
    );
  }
}

class VendorParticipationCard extends StatelessWidget {
  const VendorParticipationCard({
    super.key,
    required this.participation,
    this.trailing,
  });

  final VendorEventParticipation participation;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      accentColor: participation.lifecycleStage == ParticipationLifecycle.invited ? EosColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(participation.eventTitle, style: context.eosText.titleMedium)),
              EosFinanceChip(label: participation.lifecycleLabel, compact: true),
              if (participation.status == VendorParticipationStatus.live) ...[
                SizedBox(width: context.eos.spacing.xs),
                const EosLiveIndicator(compact: true),
              ],
            ],
          ),
          SizedBox(height: context.eos.spacing.xxs),
          Text('${participation.city} · ${participation.venue}', style: context.eosText.bodySmall),
          Text(participation.boothLabel, style: context.eosText.labelSmall),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expected payout', style: context.eosText.labelSmall),
                    VendorMoneyText(minor: participation.expectedPayoutMinor, compact: true),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}
