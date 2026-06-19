import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../organizer/models/organizer_models.dart';
import '../../organizer/providers/organizer_providers.dart';
import '../data/operations_store.dart';
import '../models/operations_models.dart';
import '../providers/operations_providers.dart';

class LiveOpsEventPicker extends ConsumerWidget {
  const LiveOpsEventPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(liveOrganizerEventsProvider);
    final selected = ref.watch(liveOpsEventIdProvider);

    if (events.isEmpty) {
      return EosAttentionBanner(
        headline: 'No live events',
        message: 'Publish an event and tap Go live from Events to open the command center.',
        severity: 'WARNING',
        actionLabel: 'Go to Events',
        onAction: () => ref.read(organizerShellTabProvider.notifier).select(1),
      );
    }

    final value = selected ?? events.first.id;
    if (selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(liveOpsEventIdProvider.notifier).state = events.first.id;
        OperationsStore.instance.ensureLive(events.first.id);
      });
    }

    final event = events.firstWhere((e) => e.id == value, orElse: () => events.first);
    final isLive = event.status == OrganizerEventStatus.live;

    return EosSurfaceCard(
      child: Row(
        children: [
          if (isLive) const EosLiveIndicator(compact: true),
          if (isLive) SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: EosSelectField<String>(
              label: 'Live event',
              value: value,
              items: [
                for (final e in events)
                  DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${e.title}${e.status == OrganizerEventStatus.live ? ' · LIVE' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id != null) {
                  ref.read(liveOpsEventIdProvider.notifier).state = id;
                  OperationsStore.instance.ensureLive(id);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EventHealthBadge extends StatelessWidget {
  const EventHealthBadge({super.key, required this.level});

  final EventHealthLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      EventHealthLevel.healthy => EosColors.success,
      EventHealthLevel.warning => EosColors.warning,
      EventHealthLevel.critical => EosColors.critical,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EosStatusPulse(color: color, size: 10),
        SizedBox(width: context.eos.spacing.xs),
        EosFinanceChip(label: level.name, compact: true),
      ],
    );
  }
}

class OpsGuestCard extends StatelessWidget {
  const OpsGuestCard({
    super.key,
    required this.guest,
    this.onCheckIn,
    this.onResend,
    this.onHistory,
  });

  final OpsGuest guest;
  final VoidCallback? onCheckIn;
  final VoidCallback? onResend;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      accentColor: guest.tier == GuestTier.vvip
          ? EosColors.champagne
          : guest.tier == GuestTier.vip
              ? context.eosColors.primary
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(guest.name, style: context.eosText.titleSmall)),
              if (guest.tier == GuestTier.vvip || guest.tier == GuestTier.vip)
                EosFinanceChip(
                  label: guest.tier == GuestTier.vvip ? 'vvip' : 'vip',
                  compact: true,
                ),
              SizedBox(width: context.eos.spacing.xs),
              EosCheckinStatus(
                checkedIn: guest.checkedIn,
                checkedInAt: guest.checkedInAt != null ? formatOpsTime(guest.checkedInAt!) : null,
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.xxs),
          Text(guest.tierName, style: context.eosText.bodySmall),
          Text('Ticket ${guest.ticketId}', style: context.eosText.labelSmall),
          if (guest.checkedInAt != null)
            Text('Arrived ${formatOpsTime(guest.checkedInAt!)}', style: context.eosText.labelSmall),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              Icon(
                guest.qrValid && !guest.ticketExpired ? Icons.qr_code_2 : Icons.block,
                size: 16,
                color: guest.qrValid ? EosColors.success : EosColors.warning,
              ),
              SizedBox(width: context.eos.spacing.xxs),
              Text(
                guest.ticketExpired ? 'QR expired' : guest.qrValid ? 'QR valid' : 'QR invalid',
                style: context.eosText.labelSmall,
              ),
              const Spacer(),
              if (!guest.checkedIn && onCheckIn != null)
                FilledButton(onPressed: onCheckIn, child: const Text('Check in')),
              if (guest.checkedIn && onResend != null)
                TextButton(onPressed: onResend, child: const Text('Resend ticket')),
              if (onHistory != null) TextButton(onPressed: onHistory, child: const Text('History')),
            ],
          ),
        ],
      ),
    );
  }
}

class OpsIncidentCard extends StatelessWidget {
  const OpsIncidentCard({
    super.key,
    required this.incident,
    this.onInvestigate,
    this.onResolve,
  });

  final OpsIncident incident;
  final VoidCallback? onInvestigate;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (incident.priority) {
      IncidentPriority.critical => EosColors.critical,
      IncidentPriority.high => EosColors.warning,
      IncidentPriority.medium => EosColors.info,
      IncidentPriority.low => context.eosColors.outline,
    };

    return EosSurfaceCard(
      elevated: true,
      accentColor: priorityColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(incident.title, style: context.eosText.titleSmall)),
              EosFinanceChip(label: incident.priority.name, compact: true),
              SizedBox(width: context.eos.spacing.xxs),
              EosFinanceChip(label: incident.status.name, compact: true),
            ],
          ),
          SizedBox(height: context.eos.spacing.xxs),
          Text(
            '${_categoryLabel(incident.category)} · ${incident.reporter}',
            style: context.eosText.bodySmall,
          ),
          if (incident.description.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.xxs),
            Text(incident.description, style: context.eosText.labelSmall),
          ],
          SizedBox(height: context.eos.spacing.sm),
          Text('Timeline', style: context.eosText.labelLarge),
          for (final t in incident.timeline)
            Padding(
              padding: EdgeInsets.only(top: context.eos.spacing.xxs),
              child: Text('${formatOpsTime(t.at)} · ${t.label}', style: context.eosText.bodySmall),
            ),
          if (incident.status == IncidentStatus.open && onInvestigate != null) ...[
            SizedBox(height: context.eos.spacing.sm),
            FilledButton(onPressed: onInvestigate, child: const Text('Start investigation')),
          ],
          if (incident.status == IncidentStatus.investigating && onResolve != null) ...[
            SizedBox(height: context.eos.spacing.sm),
            FilledButton(onPressed: onResolve, child: const Text('Mark resolved')),
          ],
        ],
      ),
    );
  }

  static String _categoryLabel(IncidentCategory c) => switch (c) {
        IncidentCategory.security => 'Security',
        IncidentCategory.medical => 'Medical',
        IncidentCategory.access => 'Access',
        IncidentCategory.technical => 'Technical',
        IncidentCategory.vendor => 'Vendor',
      };
}

class QrScanResultPanel extends StatelessWidget {
  const QrScanResultPanel({super.key, required this.response});

  final QrScanResponse response;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (response.result) {
      QrScanResult.valid => (EosColors.success, Icons.check_circle_outline),
      QrScanResult.vip => (EosColors.plum, Icons.star_outline),
      QrScanResult.vvip => (EosColors.champagne, Icons.diamond_outlined),
      QrScanResult.alreadyUsed => (EosColors.warning, Icons.info_outline),
      QrScanResult.expired => (EosColors.warning, Icons.schedule),
      QrScanResult.invalid => (EosColors.critical, Icons.cancel_outlined),
    };

    return EosSurfaceCard(
      elevated: true,
      accentColor: color,
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            response.result.name.toUpperCase().replaceAll('_', ' '),
            style: context.eosText.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.eos.spacing.xs),
          Text(response.message, style: context.eosText.bodyMedium, textAlign: TextAlign.center),
          if (response.guest != null) ...[
            SizedBox(height: context.eos.spacing.md),
            Text(response.guest!.name, style: context.eosText.titleSmall),
            Text(response.guest!.tierName, style: context.eosText.bodySmall),
          ],
        ],
      ),
    );
  }
}

class VendorOpsCard extends StatelessWidget {
  const VendorOpsCard({super.key, required this.vendor});

  final VendorOpsSnapshot vendor;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      accentColor: vendor.status == VendorOpsStatus.active ? EosColors.success : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: context.eosColors.primaryContainer,
            child: Text(
              vendor.businessName.isNotEmpty ? vendor.businessName[0] : 'V',
              style: context.eosText.titleSmall?.copyWith(color: context.eosColors.primary),
            ),
          ),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendor.businessName, style: context.eosText.titleSmall),
                Text(vendor.category, style: context.eosText.bodySmall),
                Text('${vendor.ordersToday} orders today', style: context.eosText.labelSmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vendor.status == VendorOpsStatus.active) ...[
                    const EosStatusPulse(color: EosColors.live, size: 8),
                    SizedBox(width: context.eos.spacing.xxs),
                  ],
                  EosFinanceChip(label: vendor.status.name, compact: true),
                ],
              ),
              SizedBox(height: context.eos.spacing.xs),
              Text(ngnFromMinor(vendor.revenueTodayMinor.toString()), style: context.eosText.titleSmall),
              Text(formatOpsTime(vendor.lastActivity), style: context.eosText.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class OpsModuleChipBar extends ConsumerWidget {
  const OpsModuleChipBar({super.key});

  static const labels = [
    'Dashboard',
    'Check-In',
    'Scan',
    'Feed',
    'Vendors',
    'Incidents',
    'Command',
    'Health',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(operationsShellTabProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(right: context.eos.spacing.xs),
              child: FilterChip(
                label: Text(labels[i]),
                selected: selected == i,
                onSelected: (_) => ref.read(operationsShellTabProvider.notifier).select(i),
              ),
            ),
        ],
      ),
    );
  }
}

String formatOpsTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatOpsMoney(int minor) => ngnFromMinor(minor.toString());

List<OpsGuest> filterGuests(List<OpsGuest> guests, CheckInFilter filter) => switch (filter) {
      CheckInFilter.all => guests,
      CheckInFilter.checkedIn => guests.where((g) => g.checkedIn).toList(),
      CheckInFilter.notCheckedIn => guests.where((g) => !g.checkedIn).toList(),
      CheckInFilter.vip => guests.where((g) => g.tier == GuestTier.vip).toList(),
      CheckInFilter.vvip => guests.where((g) => g.tier == GuestTier.vvip).toList(),
    };

IconData feedIcon(FeedEventType type) => switch (type) {
      FeedEventType.guestCheckedIn => Icons.qr_code_scanner,
      FeedEventType.vendorJoined => Icons.storefront_outlined,
      FeedEventType.orderPlaced => Icons.receipt_long_outlined,
      FeedEventType.refundRequested => Icons.undo,
      FeedEventType.incidentLogged => Icons.report_problem_outlined,
    };
