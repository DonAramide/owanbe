/// Canonical attendee workspace routes — stay inside `/attendee` shell.
abstract final class AttendeeRoutes {
  static const dashboard = '/attendee';
  static const findTicket = '/attendee/find-ticket';
  static const onboarding = '/attendee/onboarding';
  static const checkout = '/attendee/checkout';
  static const paymentSuccess = '/attendee/payment-success';
  static const paymentPending = '/attendee/payment-pending';
  static const orders = '/attendee/orders';
  static const myEvents = '/attendee/my-events';
  static const passes = '/attendee/passes';
  static const registrations = '/attendee/registrations';
  static const activity = '/attendee/activity';
  static const profile = '/attendee/profile';

  /// Legacy public path — redirects into workspace find-ticket flow.
  static const legacyAttending = '/attending';

  static String eventDetail(String eventId) => '/attendee/events/$eventId';

  static String eventTickets(String eventId) => '/attendee/events/$eventId/tickets';

  static String eventRecap(String eventId) => '/attendee/events/$eventId/recap';

  static const personalHistory = '/attendee/history';

  static String orderDetail(String orderId) => '/attendee/orders/$orderId';

  static String registrationDetail(String ticketId) => '/attendee/registrations/$ticketId';

  static String passDetail(String ticketId) => '/attendee/passes/$ticketId';

  static String entry(String ticketId) => '/attendee/entry/$ticketId';

  static String live(String eventId) => '/attendee/live/$eventId';

  static String people(String eventId, {int tab = 0}) =>
      tab == 0 ? '/attendee/event/$eventId/people' : '/attendee/event/$eventId/people?tab=$tab';

  static String peerProfile(String eventId, String userId) =>
      '/attendee/event/$eventId/people/$userId';

  static String businessCard([String? eventId]) => eventId == null || eventId.isEmpty
      ? '/attendee/business-card'
      : '/attendee/business-card?eventId=$eventId';

  static const networkingNotifications = '/attendee/networking-notifications';

  static const services = '/attendee/services';

  static String eventServices(String eventId) => '/attendee/event/$eventId/services';

  static String eventRentals(String eventId) => '/attendee/event/$eventId/services/rentals';

  static String serviceBookings([String? eventId]) => eventId == null || eventId.isEmpty
      ? '/attendee/services/bookings'
      : '/attendee/services/bookings?eventId=$eventId';

  static const serviceNotifications = '/attendee/services/notifications';
}
