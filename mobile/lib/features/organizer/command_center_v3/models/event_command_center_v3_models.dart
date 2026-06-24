import '../../../operations/models/operations_models.dart';
import '../../finance/organizer_finance_api.dart';
import '../../models/organizer_models.dart';
import '../../../../portals/customer/models/home_hub_models.dart';
import '../workspace_tabs.dart';

enum GuestRsvpStatus { invited, accepted, pending, declined, checkedIn }

enum GuestGroup {
  family,
  friends,
  vip,
  brideFamily,
  groomFamily,
  corporate,
}

extension GuestGroupX on GuestGroup {
  String get label => switch (this) {
        GuestGroup.family => 'Family',
        GuestGroup.friends => 'Friends',
        GuestGroup.vip => 'VIP',
        GuestGroup.brideFamily => 'Bride Family',
        GuestGroup.groomFamily => 'Groom Family',
        GuestGroup.corporate => 'Corporate Guests',
      };
}

enum VendorPipelineStage { requested, negotiating, confirmed, completed }

enum CommandActivityType {
  vendorAccepted,
  vendorDeclined,
  rsvpSubmitted,
  invitationSent,
  budgetReleased,
  vendorArrived,
  ticketSold,
  guestCheckedIn,
}

class CommandActivityItem {
  const CommandActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.at,
  });

  final CommandActivityType type;
  final String title;
  final String subtitle;
  final DateTime at;
}

class FinancialHealthSnapshot {
  const FinancialHealthSnapshot({
    required this.budgetMinor,
    required this.walletBalanceMinor,
    required this.fundsReleasedMinor,
    required this.fundsReservedMinor,
    required this.remainingBudgetMinor,
    required this.utilizationPercent,
  });

  final int budgetMinor;
  final int walletBalanceMinor;
  final int fundsReleasedMinor;
  final int fundsReservedMinor;
  final int remainingBudgetMinor;
  final double utilizationPercent;
}

class VendorHealthSnapshot {
  const VendorHealthSnapshot({
    required this.requested,
    required this.negotiating,
    required this.confirmed,
    required this.completed,
    required this.progressPercent,
  });

  final int requested;
  final int negotiating;
  final int confirmed;
  final int completed;
  final double progressPercent;
}

class GuestHealthSnapshot {
  const GuestHealthSnapshot({
    required this.invited,
    required this.rsvpAccepted,
    required this.rsvpPending,
    required this.declined,
    required this.checkedIn,
    required this.responsePercent,
  });

  final int invited;
  final int rsvpAccepted;
  final int rsvpPending;
  final int declined;
  final int checkedIn;
  final double responsePercent;
}

class PublicEventMetrics {
  const PublicEventMetrics({
    required this.ticketsSold,
    required this.totalCapacity,
    required this.revenueMinor,
    required this.attendees,
    required this.conversionPercent,
  });

  final int ticketsSold;
  final int totalCapacity;
  final int revenueMinor;
  final int attendees;
  final double conversionPercent;
}

class NegotiationEntry {
  const NegotiationEntry({
    required this.label,
    required this.amountMinor,
    required this.at,
    required this.byOrganizer,
  });

  final String label;
  final int amountMinor;
  final DateTime at;
  final bool byOrganizer;
}

class EventVendorDetail {
  const EventVendorDetail({
    required this.slot,
    required this.stage,
    required this.rating,
    required this.contractAmountMinor,
    required this.imageUrl,
    required this.negotiation,
  });

  final OrganizerVendorSlot slot;
  final VendorPipelineStage stage;
  final double rating;
  final int contractAmountMinor;
  final String? imageUrl;
  final List<NegotiationEntry> negotiation;
}

class OperationsTaskItem {
  const OperationsTaskItem({required this.label, required this.done, required this.category});

  final String label;
  final bool done;
  final String category;
}

class FinanceInsight {
  const FinanceInsight({required this.headline, required this.detail});

  final String headline;
  final String detail;
}

enum EventReminderKind { countdown, vendor, attendee, recommendation }

enum EventReminderSeverity { info, warning, critical }

class EventReminder {
  const EventReminder({
    required this.kind,
    required this.headline,
    required this.detail,
    this.severity = EventReminderSeverity.info,
    this.actionTab,
    this.actionLabel,
  });

  final EventReminderKind kind;
  final String headline;
  final String detail;
  final EventReminderSeverity severity;
  final EventWorkspaceTab? actionTab;
  final String? actionLabel;
}

class EventCommandCenterV3Snapshot {
  const EventCommandCenterV3Snapshot({
    required this.event,
    required this.planningProgress,
    required this.financial,
    required this.vendorHealth,
    required this.guestHealth,
    required this.publicMetrics,
    required this.activities,
    required this.vendorDetails,
    required this.operationsTasks,
    required this.financeInsights,
    required this.reminders,
    required this.daysUntilEvent,
  });

  final OrganizerEvent event;
  final double planningProgress;
  final FinancialHealthSnapshot financial;
  final VendorHealthSnapshot vendorHealth;
  final GuestHealthSnapshot guestHealth;
  final PublicEventMetrics? publicMetrics;
  final List<CommandActivityItem> activities;
  final List<EventVendorDetail> vendorDetails;
  final List<OperationsTaskItem> operationsTasks;
  final List<FinanceInsight> financeInsights;
  final List<EventReminder> reminders;
  final int daysUntilEvent;

  bool get isPrivate => event.isPrivateCelebration;
}

VendorPipelineStage vendorStage(OrganizerVendorSlot slot) {
  if (slot.status == VendorSlotStatus.approved && slot.ordersCount > 0) {
    return VendorPipelineStage.completed;
  }
  if (slot.status == VendorSlotStatus.approved) return VendorPipelineStage.confirmed;
  if (slot.status == VendorSlotStatus.pending) return VendorPipelineStage.negotiating;
  return VendorPipelineStage.requested;
}

GuestRsvpStatus guestRsvpStatus(OrganizerAttendee guest) {
  if (guest.checkedIn) return GuestRsvpStatus.checkedIn;
  if (guest.ticketId.isNotEmpty || guest.purchasedAt != null) return GuestRsvpStatus.accepted;
  return GuestRsvpStatus.pending;
}

GuestGroup guestGroupFor(OrganizerAttendee guest, int index) {
  final groups = GuestGroup.values;
  if (guest.tierName.toLowerCase().contains('vip')) return GuestGroup.vip;
  return groups[index % groups.length];
}

FinancialHealthSnapshot buildFinancialHealth(OrganizerEvent event, OrganizerEventFinanceSummary? finance) {
  final budget = event.budgetMinor > 0
      ? event.budgetMinor
      : (event.isPublicTicketed ? event.revenueMinor : 500000000);
  final released = finance != null
      ? int.tryParse(finance.netEarningsMinor) ?? event.revenueMinor
      : event.vendors.fold<int>(0, (s, v) => s + v.revenueMinor);
  final reserved = finance != null ? int.tryParse(finance.heldInEscrowMinor) ?? 0 : released ~/ 4;
  final wallet = finance != null
      ? int.tryParse(finance.availableForPayoutMinor) ?? 0
      : (budget - released).clamp(0, budget);
  final remaining = (budget - released - reserved).clamp(0, budget);
  final spent = budget == 0 ? 0.0 : ((released + reserved) / budget).clamp(0.0, 1.0);
  return FinancialHealthSnapshot(
    budgetMinor: budget,
    walletBalanceMinor: wallet,
    fundsReleasedMinor: released,
    fundsReservedMinor: reserved,
    remainingBudgetMinor: remaining,
    utilizationPercent: spent * 100,
  );
}

VendorHealthSnapshot buildVendorHealth(OrganizerEvent event) {
  var requested = 0, negotiating = 0, confirmed = 0, completed = 0;
  for (final v in event.vendors) {
    switch (vendorStage(v)) {
      case VendorPipelineStage.requested:
        requested++;
      case VendorPipelineStage.negotiating:
        negotiating++;
      case VendorPipelineStage.confirmed:
        confirmed++;
      case VendorPipelineStage.completed:
        completed++;
    }
  }
  final total = event.vendors.length;
  final progress = total == 0 ? 0.0 : (confirmed + completed) / total * 100;
  return VendorHealthSnapshot(
    requested: requested,
    negotiating: negotiating,
    confirmed: confirmed,
    completed: completed,
    progressPercent: progress,
  );
}

GuestHealthSnapshot buildGuestHealth(OrganizerEvent event) {
  final invited = event.expectedGuests > 0 ? event.expectedGuests : event.attendees.length;
  var accepted = 0, pending = 0, declined = 0, checkedIn = 0;
  for (final g in event.attendees) {
    if (g.checkedIn) {
      checkedIn++;
      accepted++;
      continue;
    }
    if (g.ticketId.isNotEmpty || g.purchasedAt != null) {
      accepted++;
    } else {
      pending++;
    }
  }
  if (event.attendees.isEmpty && invited > 0) pending = invited;
  final responded = accepted + declined;
  final responsePct = invited == 0 ? 0.0 : responded / invited * 100;
  return GuestHealthSnapshot(
    invited: invited,
    rsvpAccepted: accepted,
    rsvpPending: pending,
    declined: declined,
    checkedIn: checkedIn,
    responsePercent: responsePct,
  );
}

List<CommandActivityItem> buildActivities(OrganizerEvent event, List<OpsFeedEvent> feed) {
  final items = <CommandActivityItem>[];
  for (final v in event.vendors) {
    if (v.status == VendorSlotStatus.approved) {
      items.add(CommandActivityItem(
        type: CommandActivityType.vendorAccepted,
        title: '${v.businessName} confirmed',
        subtitle: v.category,
        at: DateTime.now().subtract(Duration(hours: v.id.hashCode % 48)),
      ));
    }
    if (v.status == VendorSlotStatus.rejected) {
      items.add(CommandActivityItem(
        type: CommandActivityType.vendorDeclined,
        title: '${v.businessName} declined',
        subtitle: v.category,
        at: DateTime.now().subtract(Duration(hours: v.id.hashCode % 72)),
      ));
    }
  }
  for (final a in event.attendees.take(5)) {
    if (a.purchasedAt != null) {
      items.add(CommandActivityItem(
        type: CommandActivityType.rsvpSubmitted,
        title: '${a.name} RSVP\'d',
        subtitle: a.tierName,
        at: a.purchasedAt!,
      ));
    }
    if (a.checkedIn) {
      items.add(CommandActivityItem(
        type: CommandActivityType.guestCheckedIn,
        title: '${a.name} checked in',
        subtitle: 'Gate scan',
        at: DateTime.now().subtract(const Duration(hours: 2)),
      ));
    }
  }
  for (final f in feed.take(8)) {
    items.add(CommandActivityItem(
      type: CommandActivityType.vendorArrived,
      title: f.headline,
      subtitle: f.detail,
      at: f.timestamp,
    ));
  }
  items.sort((a, b) => b.at.compareTo(a.at));
  return items.take(12).toList();
}

List<EventVendorDetail> buildVendorDetails(OrganizerEvent event) {
  return event.vendors.map((slot) {
    final base = slot.revenueMinor > 0 ? slot.revenueMinor : 25000000 + slot.id.hashCode % 50000000;
    return EventVendorDetail(
      slot: slot,
      stage: vendorStage(slot),
      rating: 4.2 + (slot.id.hashCode % 8) / 10,
      contractAmountMinor: base,
      imageUrl: null,
      negotiation: [
        NegotiationEntry(
          label: 'Vendor offer',
          amountMinor: (base * 1.15).round(),
          at: DateTime.now().subtract(const Duration(days: 5)),
          byOrganizer: false,
        ),
        NegotiationEntry(
          label: 'Your counter',
          amountMinor: base,
          at: DateTime.now().subtract(const Duration(days: 4)),
          byOrganizer: true,
        ),
        if (slot.status == VendorSlotStatus.approved)
          NegotiationEntry(
            label: 'Accepted price',
            amountMinor: base,
            at: DateTime.now().subtract(const Duration(days: 2)),
            byOrganizer: false,
          ),
      ],
    );
  }).toList();
}

List<OperationsTaskItem> buildOperationsTasks(OrganizerEvent event) {
  final vendors = event.vendors;
  final hasCatering = vendors.any((v) => v.category.toLowerCase().contains('cater'));
  final hasDecor = vendors.any((v) => v.category.toLowerCase().contains('decor'));
  final hasPhoto = vendors.any((v) => v.category.toLowerCase().contains('photo'));
  return [
    OperationsTaskItem(label: 'Venue confirmed', done: event.venue.isNotEmpty, category: 'Venue'),
    OperationsTaskItem(label: 'Food confirmed', done: hasCatering, category: 'Catering'),
    OperationsTaskItem(label: 'Decoration confirmed', done: hasDecor, category: 'Decoration'),
    OperationsTaskItem(
      label: 'Invitations sent',
      done: event.attendees.isNotEmpty,
      category: 'Guests',
    ),
    OperationsTaskItem(
      label: 'Cake ordered',
      done: vendors.any((v) => v.category.toLowerCase().contains('cake')),
      category: 'Cake',
    ),
    OperationsTaskItem(label: 'Photography confirmed', done: hasPhoto, category: 'Media'),
  ];
}

List<FinanceInsight> buildFinanceInsights(FinancialHealthSnapshot fin) {
  final pct = fin.utilizationPercent.round();
  final remainingVendors = fin.remainingBudgetMinor > 50000000 ? 2 : 1;
  return [
    FinanceInsight(
      headline: 'You have spent $pct% of your budget',
      detail: 'Track releases in the payment timeline below.',
    ),
    if (fin.remainingBudgetMinor > 0)
      FinanceInsight(
        headline: 'You can still afford $remainingVendors additional vendor${remainingVendors == 1 ? '' : 's'}',
        detail: '${formatBudgetMinor(fin.remainingBudgetMinor)} remaining in your celebration wallet.',
      ),
  ];
}

List<EventReminder> buildEventReminders(EventCommandCenterV3Snapshot snap) {
  final reminders = <EventReminder>[];
  final event = snap.event;
  final days = snap.daysUntilEvent;

  if (days > 0) {
  final urgency = days <= 7
      ? EventReminderSeverity.critical
      : days <= 21
          ? EventReminderSeverity.warning
          : EventReminderSeverity.info;
  reminders.add(
    EventReminder(
      kind: EventReminderKind.countdown,
      headline: '$days day${days == 1 ? '' : 's'} to ${event.title}',
      detail: days <= 14
          ? 'Final stretch — confirm vendors, chase RSVPs, and review your run-sheet.'
          : 'Your celebration is on ${formatEventDate(event.startsAt)}. Keep momentum on bookings and guest outreach.',
      severity: urgency,
      actionTab: EventWorkspaceTab.operations,
      actionLabel: 'View checklist',
    ),
  );
  } else if (event.status == OrganizerEventStatus.live) {
    reminders.add(
      EventReminder(
        kind: EventReminderKind.countdown,
        headline: 'Celebration day is here',
        detail: 'Monitor check-ins, vendor arrivals, and live operations from the Ops tab.',
        severity: EventReminderSeverity.critical,
        actionTab: EventWorkspaceTab.operations,
        actionLabel: 'Open operations',
      ),
    );
  }

  final missingServices = snap.operationsTasks.where((t) => !t.done).map((t) => t.category).toList();
  if (missingServices.isNotEmpty) {
    final listed = missingServices.take(4).join(', ');
    final extra = missingServices.length > 4 ? ' +${missingServices.length - 4} more' : '';
    reminders.add(
      EventReminder(
        kind: EventReminderKind.vendor,
        headline: '${missingServices.length} service${missingServices.length == 1 ? '' : 's'} yet to be confirmed',
        detail: '$listed$extra — browse Marketplace to seal the deal.',
        severity: days <= 21 ? EventReminderSeverity.critical : EventReminderSeverity.warning,
        actionTab: EventWorkspaceTab.marketplace,
        actionLabel: 'Find vendors',
      ),
    );
  }

  final openDeals = snap.vendorDetails
      .where((v) => v.stage == VendorPipelineStage.requested || v.stage == VendorPipelineStage.negotiating)
      .map((v) => v.slot.businessName)
      .toList();
  if (openDeals.isNotEmpty) {
    final names = openDeals.take(3).join(', ');
    final suffix = openDeals.length > 3 ? ' and ${openDeals.length - 3} more' : '';
    reminders.add(
      EventReminder(
        kind: EventReminderKind.vendor,
        headline: '${openDeals.length} vendor deal${openDeals.length == 1 ? '' : 's'} still open',
        detail: '$names$suffix — follow up or counter-offer to lock them in.',
        severity: EventReminderSeverity.warning,
        actionTab: EventWorkspaceTab.vendors,
        actionLabel: 'Review vendors',
      ),
    );
  }

  final guest = snap.guestHealth;
  if (guest.rsvpPending > 0) {
    reminders.add(
      EventReminder(
        kind: EventReminderKind.attendee,
        headline: '${guest.rsvpPending} guest${guest.rsvpPending == 1 ? '' : 's'} awaiting RSVP',
        detail: days <= 30
            ? 'Send a gentle reminder — only $days day${days == 1 ? '' : 's'} left to finalise headcount.'
            : 'Nudge pending guests so catering and seating stay accurate.',
        severity: days <= 14 ? EventReminderSeverity.critical : EventReminderSeverity.warning,
        actionTab: EventWorkspaceTab.attendees,
        actionLabel: 'Remind guests',
      ),
    );
  }

  if (guest.invited > 0 && guest.responsePercent < 70 && days <= 45) {
    reminders.add(
      EventReminder(
        kind: EventReminderKind.attendee,
        headline: 'RSVP rate at ${guest.responsePercent.round()}%',
        detail: 'Aim for 80%+ before the final vendor headcount lock ($days days left).',
        severity: EventReminderSeverity.info,
        actionTab: EventWorkspaceTab.attendees,
        actionLabel: 'Guest list',
      ),
    );
  }

  if (snap.financial.utilizationPercent > 85 && snap.financial.remainingBudgetMinor > 0) {
    reminders.add(
      EventReminder(
        kind: EventReminderKind.recommendation,
        headline: 'Budget nearly allocated',
        detail: '${formatBudgetMinor(snap.financial.remainingBudgetMinor)} left — hold reserves for last-minute guest adds.',
        severity: EventReminderSeverity.warning,
        actionTab: EventWorkspaceTab.finance,
        actionLabel: 'Review budget',
      ),
    );
  }

  if (snap.planningProgress < 0.5 && days <= 60) {
    reminders.add(
      EventReminder(
        kind: EventReminderKind.recommendation,
        headline: 'Planning ${(snap.planningProgress * 100).round()}% complete',
        detail: 'Publish invitations, confirm core vendors, and set your venue to stay on track.',
        severity: EventReminderSeverity.info,
        actionTab: EventWorkspaceTab.overview,
        actionLabel: 'Planning tasks',
      ),
    );
  }

  if (event.isPublicTicketed && snap.publicMetrics != null) {
    final conv = snap.publicMetrics!.conversionPercent;
    if (conv < 20 && event.totalCapacity > 0) {
      reminders.add(
        EventReminder(
          kind: EventReminderKind.recommendation,
          headline: 'Ticket sales below target',
          detail: 'Only ${conv.round()}% sold — promote your listing or adjust tiers.',
          severity: EventReminderSeverity.warning,
          actionTab: EventWorkspaceTab.tickets,
          actionLabel: 'Ticket settings',
        ),
      );
    }
  }

  return reminders;
}

String formatBudgetMinor(int minor) {
  final naira = minor / 100;
  if (naira >= 1000000) return '₦${(naira / 1000000).toStringAsFixed(1)}M';
  if (naira >= 1000) return '₦${(naira / 1000).toStringAsFixed(0)}K';
  return '₦${naira.toStringAsFixed(0)}';
}

EventCommandCenterV3Snapshot buildCommandCenterV3Snapshot({
  required OrganizerEvent event,
  OrganizerEventFinanceSummary? finance,
  List<OpsFeedEvent> feed = const [],
}) {
  final financial = buildFinancialHealth(event, finance);
  final planning = computePlanningProgress(event);
  final days = event.startsAt.difference(DateTime.now()).inDays.clamp(0, 999);
  PublicEventMetrics? publicMetrics;
  if (event.isPublicTicketed) {
    publicMetrics = PublicEventMetrics(
      ticketsSold: event.ticketsSold,
      totalCapacity: event.totalCapacity,
      revenueMinor: event.revenueMinor,
      attendees: event.attendees.length,
      conversionPercent: event.sellThroughRate * 100,
    );
  }
  final base = EventCommandCenterV3Snapshot(
    event: event,
    planningProgress: planning,
    financial: financial,
    vendorHealth: buildVendorHealth(event),
    guestHealth: buildGuestHealth(event),
    publicMetrics: publicMetrics,
    activities: buildActivities(event, feed),
    vendorDetails: buildVendorDetails(event),
    operationsTasks: buildOperationsTasks(event),
    financeInsights: buildFinanceInsights(financial),
    reminders: const [],
    daysUntilEvent: days,
  );
  return EventCommandCenterV3Snapshot(
    event: base.event,
    planningProgress: base.planningProgress,
    financial: base.financial,
    vendorHealth: base.vendorHealth,
    guestHealth: base.guestHealth,
    publicMetrics: base.publicMetrics,
    activities: base.activities,
    vendorDetails: base.vendorDetails,
    operationsTasks: base.operationsTasks,
    financeInsights: base.financeInsights,
    reminders: buildEventReminders(base),
    daysUntilEvent: base.daysUntilEvent,
  );
}
