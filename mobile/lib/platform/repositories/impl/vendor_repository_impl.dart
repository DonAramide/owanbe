import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendor_bookings_api.dart';
import '../../../core/api/vendor_catalog_api.dart';
import '../../../core/api/vendor_events_api.dart';
import '../../../features/vendor/models/vendor_models.dart';
import '../i_vendor_repository.dart';

class VendorRepositoryImpl implements IVendorRepository {
  const VendorRepositoryImpl({
    required VendorEventsApi eventsApi,
    required VendorBookingsApi bookingsApi,
    required VendorCatalogApi catalogApi,
  })  : _eventsApi = eventsApi,
        _bookingsApi = bookingsApi,
        _catalogApi = catalogApi;

  final VendorEventsApi _eventsApi;
  final VendorBookingsApi _bookingsApi;
  final VendorCatalogApi _catalogApi;

  @override
  Future<List<VendorEventParticipation>> listParticipations() => _eventsApi.listEvents();
  @override
  Future<List<VendorOrder>> listOrders() => _bookingsApi.listOrders();
  @override
  Future<List<VendorCatalogItem>> listCatalog() => _catalogApi.listPackages();
  @override
  Future<VendorProfile> getProfile() async {
    if (allowMockPersistenceFallback()) {
      return const VendorProfile(
        id: 'vendor_jollof',
        businessName: 'Jollof & Co',
        category: 'Catering',
        vendorType: VendorCatalogType.catering,
        tier: 'Gold',
        city: 'Lagos',
        tagline: 'Premium event catering for celebrations.',
        rating: 4.9,
        completedEvents: 42,
      );
    }
    throw UnimplementedError('VendorProfile API endpoint not yet available — see TECHNICAL_DEBT_REGISTER.md');
  }
}
