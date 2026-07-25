import 'package:go_router/go_router.dart';

import '../screens/attendee_activity_screen.dart';
import '../screens/attendee_business_card_screen.dart';
import '../screens/attendee_checkout_screen.dart';
import '../screens/attendee_event_detail_screen.dart';
import '../screens/attendee_event_entry_screen.dart';
import '../screens/attendee_event_rentals_screen.dart';
import '../screens/attendee_find_ticket_screen.dart';
import '../screens/attendee_live_event_hub_screen.dart';
import '../screens/attendee_my_events_screen.dart';
import '../screens/attendee_my_passes_screen.dart';
import '../screens/attendee_networking_notifications_screen.dart';
import '../screens/attendee_onboarding_screen.dart';
import '../screens/attendee_order_detail_screen.dart';
import '../screens/attendee_orders_screen.dart';
import '../screens/attendee_payment_pending_screen.dart';
import '../screens/attendee_payment_success_screen.dart';
import '../screens/attendee_peer_profile_screen.dart';
import '../screens/attendee_people_hub_screen.dart';
import '../screens/attendee_personal_history_screen.dart';
import '../screens/attendee_profile_edit_screen.dart';
import '../screens/attendee_registrations_screen.dart';
import '../screens/attendee_services_home_screen.dart';
import '../screens/attendee_ticket_select_screen.dart';
import '../screens/attendee_event_recap_screen.dart';

/// Top-level attendee commerce routes — flat paths for reliable GoRouter resolution.
List<RouteBase> attendeeCommerceRoutes() => [
      GoRoute(
        path: '/attendee/find-ticket',
        builder: (context, state) => const AttendeeFindTicketScreen(),
      ),
      GoRoute(
        path: '/attendee/profile',
        builder: (context, state) => const AttendeeProfileEditScreen(),
      ),
      GoRoute(
        path: '/attendee/my-events',
        builder: (context, state) => const AttendeeMyEventsScreen(),
      ),
      GoRoute(
        path: '/attendee/passes',
        builder: (context, state) => const AttendeeMyPassesScreen(),
      ),
      GoRoute(
        path: '/attendee/passes/:ticketId',
        builder: (context, state) =>
            AttendeePassDetailScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(
        path: '/attendee/entry/:ticketId',
        builder: (context, state) =>
            AttendeeEventEntryScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(
        path: '/attendee/live/:eventId',
        builder: (context, state) =>
            AttendeeLiveEventHubScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/attendee/event/:eventId/people',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return AttendeePeopleHubScreen(
            eventId: state.pathParameters['eventId']!,
            initialTab: tab,
          );
        },
      ),
      GoRoute(
        path: '/attendee/event/:eventId/people/:userId',
        builder: (context, state) => AttendeePeerProfileScreen(
          eventId: state.pathParameters['eventId']!,
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/attendee/business-card',
        builder: (context, state) => AttendeeBusinessCardScreen(
          eventId: state.uri.queryParameters['eventId'],
        ),
      ),
      GoRoute(
        path: '/attendee/networking-notifications',
        builder: (context, state) => const AttendeeNetworkingNotificationsScreen(),
      ),
      GoRoute(
        path: '/attendee/services',
        builder: (context, state) => const AttendeeServicesHomeScreen(),
      ),
      GoRoute(
        path: '/attendee/services/bookings',
        builder: (context, state) => AttendeeServiceBookingsScreen(
          eventId: state.uri.queryParameters['eventId'],
        ),
      ),
      GoRoute(
        path: '/attendee/services/notifications',
        builder: (context, state) => const AttendeeServiceNotificationsScreen(),
      ),
      GoRoute(
        path: '/attendee/event/:eventId/services',
        builder: (context, state) =>
            AttendeeEventServicesHubScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/attendee/event/:eventId/services/rentals',
        builder: (context, state) =>
            AttendeeEventRentalsScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/attendee/registrations',
        builder: (context, state) => const AttendeeRegistrationsScreen(),
      ),
      GoRoute(
        path: '/attendee/registrations/:ticketId',
        builder: (context, state) =>
            AttendeeRegistrationDetailScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(
        path: '/attendee/activity',
        builder: (context, state) => const AttendeeActivityScreen(),
      ),
      GoRoute(
        path: '/attendee/checkout',
        builder: (context, state) => const AttendeeCheckoutScreen(),
      ),
      GoRoute(
        path: '/attendee/payment-success',
        builder: (context, state) => const AttendeePaymentSuccessScreen(),
      ),
      GoRoute(
        path: '/attendee/payment-pending',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return AttendeePaymentPendingScreen(
            orderId: q['orderId'] ?? '',
            clientActionUrl: q['payUrl'],
            orderIdempotencyKey: q['orderIdem'],
            paymentIdempotencyKey: q['payIdem'],
          );
        },
      ),
      GoRoute(
        path: '/attendee/orders',
        builder: (context, state) => const AttendeeOrdersScreen(),
      ),
      GoRoute(
        path: '/attendee/orders/:orderId',
        builder: (context, state) =>
            AttendeeOrderDetailScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/attendee/onboarding',
        builder: (context, state) => const AttendeeOnboardingScreen(),
      ),
      GoRoute(
        path: '/attendee/events/:eventId',
        builder: (context, state) =>
            AttendeeEventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/attendee/events/:eventId/recap',
        builder: (context, state) =>
            AttendeeEventRecapScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/attendee/history',
        builder: (context, state) => const AttendeePersonalHistoryScreen(),
      ),
      GoRoute(
        path: '/attendee/events/:eventId/tickets',
        builder: (context, state) =>
            AttendeeTicketSelectScreen(eventId: state.pathParameters['eventId']!),
      ),
    ];
