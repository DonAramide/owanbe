/// Domain events fired on PlatformEventBus after successful BSP operations.
/// Consumers: NotificationService, AnalyticsService, WorkflowEngine, AIAdvisorService
library;

// Organizer domain events
class EventPublished {
  const EventPublished({required this.eventId, required this.tenantId, required this.userId});
  final String eventId;
  final String tenantId;
  final String userId;
}

class EventCreated {
  const EventCreated({required this.eventId, required this.tenantId, required this.userId});
  final String eventId;
  final String tenantId;
  final String userId;
}

class EventWentLive {
  const EventWentLive({required this.eventId, required this.tenantId});
  final String eventId;
  final String tenantId;
}

// Vendor domain events
class VendorOnboarded {
  const VendorOnboarded({required this.vendorId, required this.tenantId});
  final String vendorId;
  final String tenantId;
}

class VendorPortfolioApproved {
  const VendorPortfolioApproved({required this.vendorId, required this.tenantId, required this.approvedBy});
  final String vendorId;
  final String tenantId;
  final String approvedBy;
}

// Commerce domain events
class CheckoutCompleted {
  const CheckoutCompleted({required this.orderId, required this.tenantId, required this.userId, required this.amountMinor});
  final String orderId;
  final String tenantId;
  final String userId;
  final int amountMinor;
}

class TicketIssued {
  const TicketIssued({required this.ticketId, required this.eventId, required this.userId});
  final String ticketId;
  final String eventId;
  final String userId;
}

// Check-in domain events
class AttendeeCheckedIn {
  const AttendeeCheckedIn({required this.eventId, required this.attendeeId, required this.ticketCode});
  final String eventId;
  final String attendeeId;
  final String ticketCode;
}

// Organizer onboarding
class OrganizerOnboarded {
  const OrganizerOnboarded({required this.organizerId, required this.tenantId});
  final String organizerId;
  final String tenantId;
}
