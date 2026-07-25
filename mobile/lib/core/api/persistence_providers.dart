import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'events_api.dart';
import 'media_api.dart';
import 'event_guests_api.dart';
import 'event_services_api.dart';
import 'operations_api.dart';
import 'onboarding_api.dart';
import 'identity_api.dart';
import 'networking_api.dart';
import 'post_event_api.dart';
import 'vendor_bookings_api.dart';
import 'vendor_catalog_api.dart';
import 'vendor_events_api.dart';
import 'vendors_api.dart';

bool allowMockPersistenceFallback() =>
    (dotenv.env['ALLOW_MOCK_PERSISTENCE_FALLBACK'] ?? 'true').trim().toLowerCase() == 'true';

/// Explicit offline/dev mode — never inferred from API failures.
bool allowOfflineMockPersistence() =>
    (dotenv.env['ALLOW_OFFLINE_MOCK_PERSISTENCE'] ?? 'false').trim().toLowerCase() == 'true';

final eventsApiProvider = Provider<EventsApi>((ref) => EventsApi());
final mediaApiProvider = Provider<MediaApi>((ref) => MediaApi());
final eventGuestsApiProvider = Provider<EventGuestsApi>((ref) => EventGuestsApi());
final onboardingApiProvider = Provider<OnboardingApi>((ref) => OnboardingApi());
final identityApiProvider = Provider<IdentityApi>((ref) => IdentityApi());
final vendorEventsApiProvider = Provider<VendorEventsApi>((ref) => VendorEventsApi());
final vendorBookingsApiProvider = Provider<VendorBookingsApi>((ref) => VendorBookingsApi());
final vendorCatalogApiProvider = Provider<VendorCatalogApi>((ref) => VendorCatalogApi());
final operationsApiProvider = Provider<OperationsApi>((ref) => OperationsApi());
final vendorsApiProvider = Provider<VendorsApi>((ref) => VendorsApi());
final networkingApiProvider = Provider<NetworkingApi>((ref) => NetworkingApi());
final eventServicesApiProvider = Provider<EventServicesApi>((ref) => EventServicesApi());
final postEventApiProvider = Provider<PostEventApi>((ref) => PostEventApi());
