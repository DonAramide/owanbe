import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../../../shared/models/event_access_mode.dart';
import '../models/customer_event_models.dart';
import 'event_closing_models.dart';

/// Local archive state — completed events marked read-only by organizer.
final archivedEventIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Pre-filled wizard draft when duplicating an event.
final eventDuplicateSeedProvider = StateProvider<EventWizardV2Draft?>((ref) => null);

TicketTierType _mapTierType(CustomerTicketTierType type) => switch (type) {
      CustomerTicketTierType.regular => TicketTierType.regular,
      CustomerTicketTierType.vip => TicketTierType.vip,
      CustomerTicketTierType.vvip => TicketTierType.vvip,
      CustomerTicketTierType.earlyBird => TicketTierType.earlyBird,
      CustomerTicketTierType.group => TicketTierType.group,
      CustomerTicketTierType.corporate => TicketTierType.corporate,
      CustomerTicketTierType.table => TicketTierType.table,
    };

TicketVisibility _mapVisibility(CustomerTicketVisibility visibility) => switch (visibility) {
      CustomerTicketVisibility.publicListing => TicketVisibility.publicListing,
      CustomerTicketVisibility.hidden => TicketVisibility.hidden,
    };

EventWizardV2Draft buildDuplicateEventDraft({
  required CustomerEvent event,
  required EventClosingWorkspace workspace,
  bool similar = false,
}) {
  final suffix = similar ? ' (Similar)' : ' (Copy)';
  final nextYear = DateTime(
    event.startsAt.year + 1,
    event.startsAt.month,
    event.startsAt.day,
    event.startsAt.hour,
    event.startsAt.minute,
  );
  final duration = event.endsAt.difference(event.startsAt);

  return EventWizardV2Draft(
    categorySlug: event.category.toLowerCase().replaceAll(' ', '-'),
    categoryLabel: event.category,
    title: '${event.title}$suffix',
    tagline: event.tagline,
    description: event.description,
    city: event.city,
    venueName: event.venueName.isNotEmpty ? event.venueName : event.venue,
    venueAddress: event.venue,
    budgetMinor: workspace.financial.budgetMinor > 0
        ? workspace.financial.budgetMinor
        : workspace.summary.expensesMinor,
    expectedGuests: event.expectedGuests > 0 ? event.expectedGuests : workspace.summary.guestsInvited,
    tags: event.tags,
    startsAt: nextYear,
    endsAt: nextYear.add(duration.isNegative ? const Duration(hours: 6) : duration),
    ticketTiers: [
      for (final tier in event.ticketTiers)
        OrganizerTicketTier(
          id: tier.id,
          name: tier.name,
          description: tier.description,
          priceMinor: tier.priceMinor,
          currency: tier.currency,
          capacity: tier.capacity,
          remaining: tier.capacity,
          tierType: _mapTierType(tier.tierType),
          visibility: _mapVisibility(tier.visibility),
        ),
    ],
    preferredVendorIds: [
      for (final v in event.vendors)
        if (v.catalogVendorId != null && v.catalogVendorId!.isNotEmpty) v.catalogVendorId!,
    ],
    requiredServices: [
      for (final v in event.vendors) v.category,
    ],
    celebrantImageUrl: event.celebrantImageUrl,
    eventAccessMode: event.eventAccessMode,
    listingVisibility:
        event.eventAccessMode == EventAccessMode.publicTicketed ? 'public' : 'invite_only',
    bannerLabel: event.bannerLabel.isNotEmpty ? event.bannerLabel : 'Default banner',
  );
}

void archiveEvent(WidgetRef ref, String eventId) {
  final current = ref.read(archivedEventIdsProvider);
  ref.read(archivedEventIdsProvider.notifier).state = {...current, eventId};
}

void restoreEvent(WidgetRef ref, String eventId) {
  final current = ref.read(archivedEventIdsProvider);
  ref.read(archivedEventIdsProvider.notifier).state = current.where((id) => id != eventId).toSet();
}

void seedDuplicateEvent(WidgetRef ref, EventWizardV2Draft draft) {
  ref.read(eventDuplicateSeedProvider.notifier).state = draft;
}

void clearDuplicateSeed(WidgetRef ref) {
  ref.read(eventDuplicateSeedProvider.notifier).state = null;
}

enum ClosingReportKind {
  organizer,
  finance,
  vendor,
  guest,
  ticket,
  timeline,
  operational,
}

String buildClosingReport({
  required ClosingReportKind kind,
  required EventClosingWorkspace workspace,
}) {
  final s = workspace.summary;
  final f = workspace.financial;
  final g = workspace.guestIntel;
  final t = workspace.ticketAnalytics;

  return switch (kind) {
    ClosingReportKind.organizer => '''
ORGANIZER REPORT — ${s.eventName}
Venue: ${s.venue}, ${s.city}
Date: ${s.startsAt}
Status: ${s.status.name}
Guests: ${s.guestsInvited} invited · ${s.guestsAttended} attended
Tickets: ${s.ticketsSold} sold · ${formatRevenue(s.revenueMinor)} revenue
Vendors: ${s.vendorsUsed}
Timeline: ${s.timelineCompletionPct}% complete
Historical score: ${workspace.historicalScore}/100
''',
    ClosingReportKind.finance => '''
FINANCE REPORT — ${s.eventName}
Budget: ${formatRevenue(f.budgetMinor)}
Actual spend: ${formatRevenue(f.actualSpendMinor)}
Outstanding: ${formatRevenue(f.outstandingMinor)}
Vendor payments: ${formatRevenue(f.vendorPaymentsMinor)}
Ticket revenue: ${formatRevenue(f.ticketRevenueMinor)}
Refunds: ${f.refundsMinor}
Profit/Loss: ${formatRevenue(f.profitLossMinor)}
Settlement eligible: ${f.settlementEligible ? 'Yes' : 'No'}
''',
    ClosingReportKind.vendor => '''
VENDOR REPORT — ${s.eventName}
${workspace.vendorPerformance.map((v) => '- ${v.businessName} (${v.service}): ${v.completionStatus}, ${v.paymentStatus}').join('\n')}
''',
    ClosingReportKind.guest => '''
GUEST REPORT — ${s.eventName}
Invited: ${g.invited}
Accepted: ${g.accepted}
Declined: ${g.declined}
Checked in: ${g.checkedIn}
Walk-ins: ${g.walkIns}
No-shows: ${g.noShows}
VIP attendance: ${g.vipAttendance}
''',
    ClosingReportKind.ticket => '''
TICKET REPORT — ${s.eventName}
Sales: ${t.sales}
Revenue: ${formatRevenue(t.revenueMinor)}
Capacity: ${t.capacity}
Attendance: ${t.attendance}
Sell-through: ${t.sellThroughPct}%
Refunds: ${t.refunds}
QR scans: ${t.qrScans}
${t.tierBreakdown.map((tier) => '- ${tier.$1}: ${tier.$2}/${tier.$3}').join('\n')}
''',
    ClosingReportKind.timeline => '''
TIMELINE REPORT — ${s.eventName}
Completion: ${s.timelineCompletionPct}%
${workspace.debrief.delays.isEmpty ? 'No delays recorded.' : workspace.debrief.delays.join('\n')}
''',
    ClosingReportKind.operational => '''
OPERATIONAL REPORT — ${s.eventName}
Open incidents: ${workspace.openIncidents}
Historical score: ${workspace.historicalScore}/100
${workspace.historicalDimensions.map((d) => '- ${d.label}: ${d.score}/100 (${d.summary})').join('\n')}
''',
  };
}

Future<void> exportClosingReport({
  required ClosingReportKind kind,
  required EventClosingWorkspace workspace,
}) async {
  final text = buildClosingReport(kind: kind, workspace: workspace);
  await Clipboard.setData(ClipboardData(text: text.trim()));
}

Future<void> exportEventBundle(EventClosingWorkspace workspace) async {
  final sections = ClosingReportKind.values
      .map((k) => buildClosingReport(kind: k, workspace: workspace))
      .join('\n\n---\n\n');
  await Clipboard.setData(ClipboardData(text: sections.trim()));
}
