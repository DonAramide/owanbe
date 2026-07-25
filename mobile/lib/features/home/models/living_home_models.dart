import '../../../core/api/vendors_api.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/vendor/providers/vendor_providers.dart';
import '../../../identity/user_identity.dart';
import '../../../portals/customer/models/customer_event_models.dart';
import '../../../portals/customer/models/home_hub_models.dart';
import '../../../identity/workspace_models.dart';

/// Aggregated Living Owanbe Home snapshot (RC Phase 4).
class LivingHomeSnapshot {
  const LivingHomeSnapshot({
    required this.identity,
    this.attendeeStats,
    this.attendeeEvents = const [],
    this.invitations = const [],
    this.organizerStats,
    this.organizerAlerts = const [],
    this.organizerEvents = const [],
    this.draftEvents = const [],
    this.nearestOrganizerEvent,
    this.vendorStats,
    this.trendingVendors = const [],
    this.trendingEventTitles = const [],
    this.recentActivity = const [],
    this.announcements = const [],
    this.onboardingCards = const [],
    this.messagePreviews = const [],
    this.alertCount = 0,
  });

  final OwanbeUserIdentity identity;
  final AttendeeDashboardStats? attendeeStats;
  final List<AttendeeEventView> attendeeEvents;
  final List<CustomerInvitationCard> invitations;
  final OrganizerDashboardStats? organizerStats;
  final List<OrganizerAttentionItem> organizerAlerts;
  final List<CustomerEventSummary> organizerEvents;
  final List<CustomerEventSummary> draftEvents;
  final CustomerEventSummary? nearestOrganizerEvent;
  final VendorDashboardStats? vendorStats;
  final List<MarketplaceVendor> trendingVendors;
  final List<String> trendingEventTitles;
  final List<LivingHomeActivityItem> recentActivity;
  final List<LivingHomeAnnouncement> announcements;
  final List<LivingHomeOnboardingCard> onboardingCards;
  final List<LivingHomeMessagePreview> messagePreviews;
  final int alertCount;

  CustomerEventSummary? get heroEvent {
    if (nearestOrganizerEvent != null) return nearestOrganizerEvent;
    if (invitations.isEmpty) return null;
    final inv = invitations.first;
    return CustomerEventSummary(
      id: inv.eventId,
      title: inv.eventTitle,
      startsAt: inv.startsAt,
      city: inv.city,
      venue: inv.venue,
      status: CustomerEventStatus.published,
      guestCount: 0,
      progress: 0,
      coverGradientStart: 0xFF4A148C,
      coverGradientEnd: 0xFF7B1FA2,
      isLive: false,
    );
  }

  int get activatedWorkspaceCount =>
      ExperienceWorkspace.values.where((ws) => identity.canAccess(ws)).length;
}

class LivingHomeActivityItem {
  const LivingHomeActivityItem({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    this.workspace,
  });

  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String icon;
  final ExperienceWorkspace? workspace;
}

class LivingHomeAnnouncement {
  const LivingHomeAnnouncement({
    required this.title,
    required this.body,
    this.severity = 'INFO',
  });

  final String title;
  final String body;
  final String severity;
}

class LivingHomeOnboardingCard {
  const LivingHomeOnboardingCard({
    required this.workspace,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  final ExperienceWorkspace workspace;
  final String title;
  final String subtitle;
  final String actionLabel;
}

class LivingHomeMessagePreview {
  const LivingHomeMessagePreview({
    required this.sender,
    required this.preview,
    required this.sentAt,
    this.unread = true,
  });

  final String sender;
  final String preview;
  final DateTime sentAt;
  final bool unread;
}
