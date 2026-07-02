import '../../core/api/events_api.dart';
import '../../core/api/identity_api.dart';
import '../../core/api/operations_api.dart';
import '../../core/api/ticket_commerce_api.dart';
import '../../core/api/vendor_bookings_api.dart';
import '../../core/api/vendor_catalog_api.dart';
import '../../core/api/vendor_events_api.dart';
import '../../core/api/vendors_api.dart';
import '../../core/api/owambe_http_client.dart';
import '../repositories/impl/commerce_repository_impl.dart';
import '../repositories/impl/events_repository_impl.dart';
import '../repositories/impl/identity_repository_impl.dart';
import '../repositories/impl/marketplace_repository_impl.dart';
import '../repositories/impl/operations_repository_impl.dart';
import '../repositories/impl/vendor_repository_impl.dart';
import '../repositories/i_commerce_repository.dart';
import '../repositories/i_events_repository.dart';
import '../repositories/i_identity_repository.dart';
import '../repositories/i_marketplace_repository.dart';
import '../repositories/i_operations_repository.dart';
import '../repositories/i_vendor_repository.dart';
import 'ai_advisor_service.dart';
import 'commerce_service.dart';
import 'event_service.dart';
import 'marketplace_service.dart';
import 'notification_service.dart';
import 'organizer_service.dart';
import 'ticket_service.dart';
import 'user_service.dart';
import 'vendor_service.dart';

class ServiceRegistry {
  ServiceRegistry._();
  static final ServiceRegistry instance = ServiceRegistry._();

  final Map<Type, dynamic> _registry = {};

  void register<T>(T service) {
    _registry[T] = service;
  }

  T resolve<T>() {
    final service = _registry[T];
    if (service == null) {
      throw StateError('No registered service found for type $T. Call registerAllDefaultServices() first.');
    }
    return service as T;
  }

  bool isRegistered<T>() => _registry.containsKey(T);

  void registerAllDefaultServices() {
    final client = createOwambeHttpClient();

    // ── Repositories ──────────────────────────────────────────────
    final eventsRepo = EventsRepositoryImpl(EventsApi(client: client));
    final vendorRepo = VendorRepositoryImpl(
      eventsApi: VendorEventsApi(client: client),
      bookingsApi: VendorBookingsApi(client: client),
      catalogApi: VendorCatalogApi(client: client),
    );
    final opsRepo = OperationsRepositoryImpl(OperationsApi(client: client));
    final marketplaceRepo = MarketplaceRepositoryImpl(VendorsApi(client: client));
    final identityRepo = IdentityRepositoryImpl(IdentityApi(client: client));
    final commerceRepo = CommerceRepositoryImpl(TicketCommerceApi(client: client));

    register<IEventsRepository>(eventsRepo);
    register<IVendorRepository>(vendorRepo);
    register<IOperationsRepository>(opsRepo);
    register<IMarketplaceRepository>(marketplaceRepo);
    register<IIdentityRepository>(identityRepo);
    register<ICommerceRepository>(commerceRepo);

    // ── BSP Services ──────────────────────────────────────────────
    register<IOrganizerService>(OrganizerService(eventsRepo));
    register<IVendorService>(VendorService(vendorRepo));
    register<IEventService>(EventService(opsRepo));
    register<IMarketplaceService>(MarketplaceService(marketplaceRepo));
    register<IUserService>(const UserService());
    register<ITicketService>(const TicketService());
    register<ICommerceService>(const CommerceService());
    register<INotificationService>(const NotificationService());
    register<IAiAdvisorService>(const AiAdvisorService());
  }
}
