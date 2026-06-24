import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../portals/customer/router/customer_routes.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';

export '../../../core/utils/money.dart' show formatRevenue;

String formatEventDateRange(DateTime start, DateTime end) {
  return '${start.month}/${start.day}/${start.year} · ${start.hour}:${start.minute.toString().padLeft(2, '0')}';
}

String moneyAmountForEos(int minor) => ngnFromMinor(minor.toString()).replaceFirst('₦', '');

class OrganizerMoneyText extends StatelessWidget {
  const OrganizerMoneyText({super.key, required this.minor, this.compact = false, this.color});

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

class OrganizerEventPicker extends ConsumerWidget {
  const OrganizerEventPicker({super.key, this.onChanged});

  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(organizerEventsProvider);
    final selected = ref.watch(selectedOrganizerEventIdProvider);

    return events.when(
      data: (list) {
        if (list.isEmpty) {
          return EosSurfaceCard(child: Text('Create an event to get started', style: context.eosText.bodyMedium));
        }
        final value = selected ?? list.first.id;
        if (selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedOrganizerEventIdProvider.notifier).state = list.first.id;
          });
        }
        return EosSelectField<String>(
          label: 'Active event',
          value: value,
          items: [
            for (final e in list)
              DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (id) {
            ref.read(selectedOrganizerEventIdProvider.notifier).state = id;
            onChanged?.call(id);
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
    );
  }
}

String organizerStatusLabel(OrganizerEventStatus status) => switch (status) {
      OrganizerEventStatus.draft => 'draft',
      OrganizerEventStatus.published => 'published',
      OrganizerEventStatus.live => 'live',
      OrganizerEventStatus.completed => 'completed',
      OrganizerEventStatus.cancelled => 'cancelled',
    };

EosKpiAttention attentionForStatus(OrganizerEventStatus status) => switch (status) {
      OrganizerEventStatus.draft => EosKpiAttention.warning,
      OrganizerEventStatus.live => EosKpiAttention.critical,
      OrganizerEventStatus.published => EosKpiAttention.info,
      OrganizerEventStatus.completed => EosKpiAttention.none,
      OrganizerEventStatus.cancelled => EosKpiAttention.critical,
    };

class OrganizerVendorManageCard extends StatelessWidget {
  const OrganizerVendorManageCard({
    super.key,
    required this.vendor,
    this.onApprove,
    this.onReject,
    this.onSuspend,
  });

  final OrganizerVendorSlot vendor;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onSuspend;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      accentColor: vendor.status == VendorSlotStatus.pending ? EosColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendor.businessName, style: context.eosText.titleSmall),
                    Text(
                      [vendor.category, if (vendor.city != null) vendor.city].join(' · '),
                      style: context.eosText.bodySmall,
                    ),
                  ],
                ),
              ),
              EosFinanceChip(label: vendorSlotStatusLabel(vendor.status), compact: true),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              Expanded(child: Text('${vendor.ordersCount} orders', style: context.eosText.labelSmall)),
              OrganizerMoneyText(minor: vendor.revenueMinor, compact: true),
            ],
          ),
          if (vendor.status == VendorSlotStatus.pending) ...[
            SizedBox(height: context.eos.spacing.sm),
            Wrap(
              spacing: context.eos.spacing.xs,
              children: [
                if (onApprove != null) FilledButton(onPressed: onApprove, child: const Text('Approve')),
                if (onReject != null) OutlinedButton(onPressed: onReject, child: const Text('Reject')),
              ],
            ),
          ],
          if (vendor.status == VendorSlotStatus.approved && onSuspend != null) ...[
            SizedBox(height: context.eos.spacing.sm),
            TextButton(onPressed: onSuspend, child: const Text('Suspend vendor')),
          ],
        ],
      ),
    );
  }
}

class OrganizerQuickActions extends ConsumerWidget {
  const OrganizerQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/organizer/events/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create event'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            final id = ref.read(selectedOrganizerEventIdProvider);
            if (id != null) context.push('/organizer/events/$id?tab=1');
          },
          icon: const Icon(Icons.confirmation_number_outlined, size: 18),
          label: const Text('Create ticket tier'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push('/attendee'),
          icon: const Icon(Icons.confirmation_number_outlined, size: 18),
          label: const Text('Events I\'m attending'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(CustomerRoutes.vendors),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('Browse marketplace'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            final id = ref.read(selectedOrganizerEventIdProvider);
            if (id != null) context.push('/organizer/events/$id?tab=3');
          },
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Invite vendor'),
        ),
        OutlinedButton.icon(
          onPressed: () => ref.read(organizerShellTabProvider.notifier).select(5),
          icon: const Icon(Icons.insights_outlined, size: 18),
          label: const Text('View analytics'),
        ),
      ],
    );
  }
}
