import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/i_events_repository.dart';
import '../repositories/i_vendor_repository.dart';
import '../repositories/i_operations_repository.dart';
import '../repositories/i_marketplace_repository.dart';
import '../repositories/i_identity_repository.dart';
import '../repositories/i_commerce_repository.dart';
import 'ai_advisor_service.dart';
import 'commerce_service.dart';
import 'event_service.dart';
import 'marketplace_service.dart';
import 'notification_service.dart';
import 'organizer_service.dart';
import 'service_registry.dart';
import 'ticket_service.dart';
import 'user_service.dart';
import 'vendor_service.dart';

// ── Repository Providers ──────────────────────────────────────────────────────
final eventsRepositoryProvider = Provider<IEventsRepository>(
  (ref) => ServiceRegistry.instance.resolve<IEventsRepository>(),
);

final vendorRepositoryProvider = Provider<IVendorRepository>(
  (ref) => ServiceRegistry.instance.resolve<IVendorRepository>(),
);

final operationsRepositoryProvider = Provider<IOperationsRepository>(
  (ref) => ServiceRegistry.instance.resolve<IOperationsRepository>(),
);

final marketplaceRepositoryProvider = Provider<IMarketplaceRepository>(
  (ref) => ServiceRegistry.instance.resolve<IMarketplaceRepository>(),
);

final identityRepositoryProvider = Provider<IIdentityRepository>(
  (ref) => ServiceRegistry.instance.resolve<IIdentityRepository>(),
);

final commerceRepositoryProvider = Provider<ICommerceRepository>(
  (ref) => ServiceRegistry.instance.resolve<ICommerceRepository>(),
);

// ── BSP Service Providers ─────────────────────────────────────────────────────
final organizerServiceProvider = Provider<IOrganizerService>(
  (ref) => ServiceRegistry.instance.resolve<IOrganizerService>(),
);

final vendorServiceProvider = Provider<IVendorService>(
  (ref) => ServiceRegistry.instance.resolve<IVendorService>(),
);

final eventServiceProvider = Provider<IEventService>(
  (ref) => ServiceRegistry.instance.resolve<IEventService>(),
);

final marketplaceServiceProvider = Provider<IMarketplaceService>(
  (ref) => ServiceRegistry.instance.resolve<IMarketplaceService>(),
);

final userServiceProvider = Provider<IUserService>(
  (ref) => ServiceRegistry.instance.resolve<IUserService>(),
);

final ticketServiceProvider = Provider<ITicketService>(
  (ref) => ServiceRegistry.instance.resolve<ITicketService>(),
);

final commerceServiceProvider = Provider<ICommerceService>(
  (ref) => ServiceRegistry.instance.resolve<ICommerceService>(),
);

final notificationServiceProvider = Provider<INotificationService>(
  (ref) => ServiceRegistry.instance.resolve<INotificationService>(),
);

final aiAdvisorServiceProvider = Provider<IAiAdvisorService>(
  (ref) => ServiceRegistry.instance.resolve<IAiAdvisorService>(),
);
