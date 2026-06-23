import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'events_api.dart';
import 'operations_api.dart';
import 'vendor_events_api.dart';
import 'vendors_api.dart';

bool allowMockPersistenceFallback() =>
    (dotenv.env['ALLOW_MOCK_PERSISTENCE_FALLBACK'] ?? 'false').trim().toLowerCase() == 'true';

final eventsApiProvider = Provider<EventsApi>((ref) => EventsApi());
final vendorEventsApiProvider = Provider<VendorEventsApi>((ref) => VendorEventsApi());
final operationsApiProvider = Provider<OperationsApi>((ref) => OperationsApi());
final vendorsApiProvider = Provider<VendorsApi>((ref) => VendorsApi());
