import 'customer_event_models.dart';
import 'command_center_models.dart';
import 'home_hub_models.dart';

enum CustomerWorkspaceReminderKind { countdown, vendor, attendee, recommendation }

enum CustomerWorkspaceReminderSeverity { info, warning, critical }

class CustomerWorkspaceReminder {
  const CustomerWorkspaceReminder({
    required this.kind,
    required this.headline,
    required this.detail,
    this.severity = CustomerWorkspaceReminderSeverity.info,
    this.actionTabKey,
    this.actionLabel,
  });

  final CustomerWorkspaceReminderKind kind;
  final String headline;
  final String detail;
  final CustomerWorkspaceReminderSeverity severity;
  final String? actionTabKey;
  final String? actionLabel;
}

String formatBudgetMinor(int minor) {
  final naira = minor / 100;
  if (naira >= 1000000) return '₦${(naira / 1000000).toStringAsFixed(1)}M';
  if (naira >= 1000) return '₦${(naira / 1000).toStringAsFixed(0)}K';
  return '₦${naira.toStringAsFixed(0)}';
}

int daysUntilCustomerEvent(CustomerEvent event) {
  return event.startsAt.difference(DateTime.now()).inDays.clamp(0, 999);
}

List<CustomerWorkspaceReminder> buildCustomerWorkspaceReminders(EventCommandCenterSnapshot snap) {
  final reminders = <CustomerWorkspaceReminder>[];
  final event = snap.event;
  final days = daysUntilCustomerEvent(event);

  if (days > 0) {
    final urgency = days <= 7
        ? CustomerWorkspaceReminderSeverity.critical
        : days <= 21
            ? CustomerWorkspaceReminderSeverity.warning
            : CustomerWorkspaceReminderSeverity.info;
    reminders.add(
      CustomerWorkspaceReminder(
        kind: CustomerWorkspaceReminderKind.countdown,
        headline: '$days day${days == 1 ? '' : 's'} to ${event.title}',
        detail: days <= 14
            ? 'Final stretch — confirm vendors, chase RSVPs, and review your run-sheet.'
            : 'Your celebration is on ${formatEventDate(event.startsAt)}. Keep momentum on bookings and guest outreach.',
        severity: urgency,
        actionTabKey: 'operations',
        actionLabel: 'View checklist',
      ),
    );
  } else if (event.status == CustomerEventStatus.live) {
    reminders.add(
      const CustomerWorkspaceReminder(
        kind: CustomerWorkspaceReminderKind.countdown,
        headline: 'Celebration day is here',
        detail: 'Monitor check-ins, vendor arrivals, and live operations from the Ops tab.',
        severity: CustomerWorkspaceReminderSeverity.critical,
        actionTabKey: 'operations',
        actionLabel: 'Open operations',
      ),
    );
  }

  final incompleteTasks = snap.tasks.where((t) => !t.done).map((t) => t.label).toList();
  if (incompleteTasks.isNotEmpty) {
    final listed = incompleteTasks.take(4).join(', ');
    final extra = incompleteTasks.length > 4 ? ' +${incompleteTasks.length - 4} more' : '';
    reminders.add(
      CustomerWorkspaceReminder(
        kind: CustomerWorkspaceReminderKind.vendor,
        headline: '${incompleteTasks.length} planning task${incompleteTasks.length == 1 ? '' : 's'} still open',
        detail: '$listed$extra — browse Marketplace to seal the deal.',
        severity: days <= 21 ? CustomerWorkspaceReminderSeverity.critical : CustomerWorkspaceReminderSeverity.warning,
        actionTabKey: 'marketplace',
        actionLabel: 'Find vendors',
      ),
    );
  }

  final openDeals = event.vendors
      .where(
        (v) =>
            v.status == CustomerVendorSlotStatus.invited || v.status == CustomerVendorSlotStatus.pending,
      )
      .map((v) => v.businessName)
      .toList();
  if (openDeals.isNotEmpty) {
    final names = openDeals.take(3).join(', ');
    final suffix = openDeals.length > 3 ? ' and ${openDeals.length - 3} more' : '';
    reminders.add(
      CustomerWorkspaceReminder(
        kind: CustomerWorkspaceReminderKind.vendor,
        headline: '${openDeals.length} vendor deal${openDeals.length == 1 ? '' : 's'} still open',
        detail: '$names$suffix — follow up to confirm vendor acceptance.',
        severity: CustomerWorkspaceReminderSeverity.warning,
        actionTabKey: 'vendors',
        actionLabel: 'Review vendors',
      ),
    );
  }

  final rsvpPending = (snap.guestInvited - snap.guestRsvp).clamp(0, snap.guestInvited);
  if (rsvpPending > 0) {
    reminders.add(
      CustomerWorkspaceReminder(
        kind: CustomerWorkspaceReminderKind.attendee,
        headline: '$rsvpPending guest${rsvpPending == 1 ? '' : 's'} awaiting RSVP',
        detail: days <= 30
            ? 'Send a gentle reminder — only $days day${days == 1 ? '' : 's'} left to finalise headcount.'
            : 'Nudge pending guests so catering and seating stay accurate.',
        severity: days <= 14 ? CustomerWorkspaceReminderSeverity.critical : CustomerWorkspaceReminderSeverity.warning,
        actionTabKey: 'attendees',
        actionLabel: 'Remind guests',
      ),
    );
  }

  if (snap.guestInvited > 0) {
    final responsePercent = snap.guestInvited == 0 ? 0.0 : (snap.guestRsvp / snap.guestInvited) * 100;
    if (responsePercent < 70 && days <= 45) {
      reminders.add(
        CustomerWorkspaceReminder(
          kind: CustomerWorkspaceReminderKind.attendee,
          headline: 'RSVP rate at ${responsePercent.round()}%',
          detail: 'Aim for 80%+ before the final vendor headcount lock ($days days left).',
          severity: CustomerWorkspaceReminderSeverity.info,
          actionTabKey: 'attendees',
          actionLabel: 'Guest list',
        ),
      );
    }
  }

  if (snap.budgetMinor > 0) {
    final utilization = snap.committedMinor / snap.budgetMinor;
    if (utilization > 0.85 && snap.remainingMinor > 0) {
      reminders.add(
        CustomerWorkspaceReminder(
          kind: CustomerWorkspaceReminderKind.recommendation,
          headline: 'Budget nearly allocated',
          detail: '${formatBudgetMinor(snap.remainingMinor)} left — hold reserves for last-minute guest adds.',
          severity: CustomerWorkspaceReminderSeverity.warning,
          actionTabKey: 'finance',
          actionLabel: 'Review budget',
        ),
      );
    }
  }

  if (snap.progress < 0.5 && days <= 60) {
    reminders.add(
      CustomerWorkspaceReminder(
        kind: CustomerWorkspaceReminderKind.recommendation,
        headline: 'Planning ${(snap.progress * 100).round()}% complete',
        detail: 'Publish invitations, confirm core vendors, and set your venue to stay on track.',
        severity: CustomerWorkspaceReminderSeverity.info,
        actionTabKey: 'overview',
        actionLabel: 'Planning tasks',
      ),
    );
  }

  if (event.isPublicTicketed && event.totalCapacity > 0) {
    final conv = (event.ticketsSold / event.totalCapacity) * 100;
    if (conv < 20) {
      reminders.add(
        CustomerWorkspaceReminder(
          kind: CustomerWorkspaceReminderKind.recommendation,
          headline: 'Ticket sales below target',
          detail: 'Only ${conv.round()}% sold — promote your listing or adjust tiers.',
          severity: CustomerWorkspaceReminderSeverity.warning,
          actionTabKey: 'tickets',
          actionLabel: 'Ticket settings',
        ),
      );
    }
  }

  return reminders;
}

class CustomerWorkspaceRemindersSnapshot {
  const CustomerWorkspaceRemindersSnapshot({
    required this.reminders,
    required this.daysUntilEvent,
  });

  final List<CustomerWorkspaceReminder> reminders;
  final int daysUntilEvent;
}

CustomerWorkspaceRemindersSnapshot buildCustomerWorkspaceRemindersSnapshot(
  EventCommandCenterSnapshot snap,
) {
  return CustomerWorkspaceRemindersSnapshot(
    reminders: buildCustomerWorkspaceReminders(snap),
    daysUntilEvent: daysUntilCustomerEvent(snap.event),
  );
}
