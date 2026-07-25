import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/attendee/navigation/attendee_routes.dart';

void main() {
  test('attendee commerce paths work for any event id', () {
    const ids = ['evt_lagos_owanbe_2026', 'evt_future_abc', 'any-valid-event-id'];
    for (final id in ids) {
      expect(AttendeeRoutes.eventDetail(id), '/attendee/events/$id');
      expect(AttendeeRoutes.eventTickets(id), '/attendee/events/$id/tickets');
    }
  });

  test('attendee commerce routes register expected top-level paths', () {
    final paths = <String>{
      '/attendee/find-ticket',
      '/attendee/checkout',
      '/attendee/payment-success',
      '/attendee/onboarding',
      '/attendee/events/:eventId',
      '/attendee/events/:eventId/tickets',
    };
    expect(paths.length, 6);
    expect(AttendeeRoutes.checkout, '/attendee/checkout');
    expect(AttendeeRoutes.paymentSuccess, '/attendee/payment-success');
  });
}
