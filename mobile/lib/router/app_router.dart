import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_session.dart';
import '../auth/password_recovery.dart';
import '../auth/user_role.dart';
import '../platform/bootstrap/bootstrap.dart';
import '../features/super_admin/screens/platform_configuration_screen.dart';
import '../features/super_admin/screens/vendor_governance_screen.dart';
import '../features/super_admin/super_admin_home_screen.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/admin/screens/admin_vendor_pricing_screen.dart';
import '../features/admin/screens/admin_vendor_categories_screen.dart';
import '../features/super_admin/screens/vendor_configuration_hub_screen.dart';
import '../features/super_admin/screens/vendor_business_capabilities_screen.dart';
import '../features/super_admin/screens/vendor_offering_categories_screen.dart';
import '../features/super_admin/screens/vendor_resource_catalogue_screen.dart';
import '../features/admin/screens/admin_vendor_capability_detail_screen.dart';
import '../shared/widgets/unsaved_changes.dart';
import '../portals/attendee/navigation/attendee_commerce_routes.dart';
import '../features/public/screens/attendee_dashboard_screen.dart';
import '../features/public/screens/checkout_screen.dart';
import '../features/public/screens/discover_screen.dart';
import '../portals/customer/screens/customer_event_ai_planner_screen.dart';
import '../portals/customer/screens/customer_event_budget_screen.dart';
import '../portals/customer/screens/marketplace_screen.dart';
import '../portals/customer/screens/marketplace_vendor_detail_screen.dart';
import '../portals/customer/screens/customer_event_edit_screen.dart';
import '../portals/customer/screens/customer_event_guests_screen.dart';
import '../portals/customer/screens/customer_event_invitations_screen.dart';
import '../portals/customer/screens/event_rsvp_screen.dart';
import '../portals/customer/screens/customer_event_route_screen.dart';
import '../portals/customer/screens/customer_event_day_screen.dart';
import '../portals/customer/screens/customer_event_website_screen.dart';
import '../portals/customer/screens/customer_event_wall_screen.dart';
import '../portals/customer/screens/customer_event_wall_display_screen.dart';
import '../portals/customer/screens/customer_event_attire_screen.dart';
import '../portals/customer/screens/customer_event_rentals_screen.dart';
import '../portals/customer/screens/customer_event_seating_screen.dart';
import '../portals/customer/screens/customer_event_program_screen.dart';
import '../portals/customer/screens/customer_event_tickets_manage_screen.dart';
import '../portals/customer/screens/customer_event_vendor_pipeline_screen.dart';
import '../features/operations/screens/check_in_center_screen.dart';
import '../features/operations/screens/incident_center_screen.dart';
import '../features/operations/screens/live_event_feed_screen.dart';
import '../features/operations/screens/qr_scan_screen.dart';
import '../portals/customer/screens/customer_event_ops_module_screen.dart';
import '../../../portals/customer/screens/marketplace_rentals_screen.dart';
import '../features/vendor/screens/vendor_fashion_attire_screen.dart';
import '../features/vendor/screens/vendor_crm_screen.dart';
import '../applications/owanbe_customer/screens/onboarding_form_screen.dart';
import '../features/vendor/screens/vendor_onboarding_screen.dart';
import '../features/vendor/screens/vendor_my_offerings_screen.dart';
import '../features/vendor/screens/vendor_rentals_screen.dart';
import '../features/vendor/screens/vendor_calendar_screen.dart';
import '../features/vendor/screens/vendor_services_availability_screen.dart';
import '../features/public/screens/splash_screen.dart';
import '../features/public/screens/supabase_diagnostics_route.dart';
import '../features/public/screens/walkthrough_screen.dart';
import '../features/public/screens/payment_success_screen.dart';
import '../features/public/screens/ticket_select_screen.dart';
import '../features/identity/screens/forgot_password_screen.dart';
import '../features/identity/screens/organizer_onboarding_screen.dart';
import '../features/identity/screens/recovery_password_screen.dart';
import '../features/organizer/screens/organizer_home_screen.dart';
import '../features/organizer/wizard_v2/event_create_wizard_v2_screen.dart';
import '../features/organizer/screens/event_workspace_screen.dart';
import '../features/vendor/vendor_home_screen.dart';
import '../portals/customer/router/customer_routes.dart';
import '../portals/customer/screens/organizer_portfolio_workspace_screen.dart';
import '../portals/customer/router/customer_shell_route.dart';
import '../portals/customer/router/event_route_registry.dart';
import '../features/auth/screens/universal_auth_screen.dart';
import '../features/auth/screens/admin_auth_screen.dart';
import '../features/home/screens/owanbe_home_screen.dart';
import '../features/activation/screens/workspace_activation_screen.dart';
import '../identity/identity_provider.dart';
import '../identity/user_identity.dart';
import '../identity/workspace_lifecycle.dart';
import '../identity/workspace_models.dart';
import '../router/experience_routes.dart';
import 'experience_onboarding.dart';
import 'portal_routes.dart';
import 'router_notifier.dart';
import 'deep_link_listener.dart';

String? _unifiedIdentityRedirect({
  required AuthSession? session,
  required String loc,
  String? pendingDeepLink,
  OwanbeUserIdentity? identity,
  bool recoveryActive = false,
}) {
  final recoveryDecision = passwordRecoveryRedirect(
    isAdminApp: SharedBootstrap.isAdmin,
    recoveryActive: recoveryActive,
    hasAuthSession: session != null,
    location: loc,
  );
  if (recoveryDecision.kind == RecoveryRedirectKind.allow) return null;
  if (recoveryDecision.kind == RecoveryRedirectKind.go) {
    return recoveryDecision.location;
  }

  if (pendingDeepLink != null && loc != pendingDeepLink && loc != '/') {
    return pendingDeepLink;
  }

  // —— Admin Flutter binary ——
  if (SharedBootstrap.isAdmin) {
    if (ExperienceRoutes.isDiagnosticsPath(loc)) return null;
    if (session == null) {
      if (loc == '/' || loc == ExperienceRoutes.adminAuth) return null;
      if (loc == '/walkthrough' ||
          ExperienceRoutes.isCustomerAuthPath(loc) ||
          ExperienceRoutes.isLegacyPortalAuthPath(loc) ||
          ExperienceRoutes.isHubPath(loc) ||
          ExperienceRoutes.workspaceFromPath(loc) != null ||
          ExperienceRoutes.isActivationPath(loc)) {
        return ExperienceRoutes.adminAuth;
      }
      if (ExperienceRoutes.isAdminHomePath(loc)) {
        return ExperienceRoutes.adminAuth;
      }
      return ExperienceRoutes.adminAuth;
    }
    // Authenticated admin session
    if (ExperienceRoutes.isCustomerAuthPath(loc) ||
        ExperienceRoutes.isLegacyPortalAuthPath(loc) ||
        ExperienceRoutes.isHubPath(loc) ||
        ExperienceRoutes.workspaceFromPath(loc) != null ||
        ExperienceRoutes.isActivationPath(loc) ||
        loc == '/walkthrough' ||
        loc == ExperienceRoutes.adminAuth) {
      return ExperienceRoutes.adminHome;
    }
    if (ExperienceRoutes.isAdminHomePath(loc)) return null;
    return ExperienceRoutes.adminHome;
  }

  // —— Customer Flutter binary ——
  if (session != null) {
    final wsGuard = experienceWorkspaceRouteGuard(
      loc: loc,
      session: session,
      identity: identity,
    );
    if (wsGuard != null) return wsGuard;
  }

  if (ExperienceRoutes.isAdminAuthPath(loc) || ExperienceRoutes.isAdminHomePath(loc)) {
    // Customer binary never hosts Admin login / Control Tower.
    return session != null ? ExperienceRoutes.hub : ExperienceRoutes.auth;
  }

  if (ExperienceRoutes.isPublicPath(loc) ||
      ExperienceRoutes.isActivationPath(loc) ||
      PortalRoutes.isOnboardingPath(loc)) {
    if (session == null && !ExperienceRoutes.isPublicPath(loc)) {
      return ExperienceRoutes.auth;
    }
    return null;
  }

  if (ExperienceRoutes.isLegacyPortalAuthPath(loc)) {
    return session != null ? ExperienceRoutes.hub : ExperienceRoutes.auth;
  }

  if (session == null) {
    return ExperienceRoutes.auth;
  }

  if (loc == ExperienceRoutes.auth ||
      loc == PortalRoutes.gate ||
      loc == '/walkthrough') {
    return WorkspaceLifecycle.postLoginDestination(identity);
  }

  if (ExperienceRoutes.isHubPath(loc)) {
    return null;
  }

  final ws = ExperienceRoutes.workspaceFromPath(loc);
  if (ws != null) {
    return null;
  }

  return ExperienceRoutes.hub;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(deepLinkListenerProvider);
  final refresh = RouterNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final pendingDeepLink = ref.read(pendingDeepLinkProvider);
      final loc = state.matchedLocation;

      final redirectLoc = _unifiedIdentityRedirect(
              session: session,
              loc: loc,
              pendingDeepLink: pendingDeepLink,
              identity: ref.read(userIdentityProvider).valueOrNull,
              recoveryActive: ref.read(passwordRecoveryActiveProvider),
            );
      if (pendingDeepLink != null && redirectLoc == pendingDeepLink) {
        ref.read(pendingDeepLinkProvider.notifier).state = null;
      }
      return redirectLoc;
    },
    routes: [
      customerShellRoute(),
      GoRoute(
        path: EventRouteRegistry.portfolio,
        builder: (context, state) => const OrganizerPortfolioWorkspaceScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: ExperienceRoutes.supabaseDiagnostics,
        builder: (context, state) => const SupabaseDiagnosticsScreen(),
      ),
      GoRoute(path: ExperienceRoutes.auth, builder: (context, state) => const UniversalAuthScreen()),
      GoRoute(
        path: ExperienceRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: ExperienceRoutes.passwordRecovery,
        builder: (context, state) => const RecoveryPasswordScreen(),
      ),
      GoRoute(path: ExperienceRoutes.adminAuth, builder: (context, state) => const AdminAuthScreen()),
      GoRoute(path: ExperienceRoutes.hub, builder: (context, state) => const OwanbeHomeScreen()),
      GoRoute(
        path: '/activate/attendee',
        builder: (context, state) =>
            const WorkspaceActivationScreen(workspace: ExperienceWorkspace.attendee),
      ),
      GoRoute(
        path: '/activate/organizer',
        builder: (context, state) =>
            const WorkspaceActivationScreen(workspace: ExperienceWorkspace.organizer),
      ),
      GoRoute(
        path: '/activate/vendor',
        builder: (context, state) =>
            const WorkspaceActivationScreen(workspace: ExperienceWorkspace.vendor),
      ),
      GoRoute(path: PortalRoutes.gate, redirect: (context, state) => ExperienceRoutes.hub),
      GoRoute(path: '/walkthrough', builder: (context, state) => const WalkthroughScreen()),
      GoRoute(
        path: '/events',
        builder: (context, state) => const DiscoverScreen(),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) {
              final id = state.pathParameters['id'];
              if (id == 'mine') return CustomerRoutes.myEvents;
              if (id == 'create') return CustomerRoutes.createEvent;
              return null;
            },
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerEventRouteScreen(eventId: id);
            },
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => CustomerEventEditScreen(
                  eventId: state.pathParameters['id']!,
                ),
                onExit: (context, state) {
                  return UnsavedChangesRegistry.confirmLeave(
                    context,
                    binder: UnsavedChangesRegistry.eventDetails,
                  );
                },
              ),
              GoRoute(
                path: 'tickets',
                builder: (context, state) => TicketSelectScreen(eventId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'manage',
                    builder: (context, state) => CustomerEventTicketsManageScreen(
                      eventId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'budget',
                builder: (context, state) => CustomerEventBudgetScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'guests',
                builder: (context, state) => CustomerEventGuestsScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'invitations',
                builder: (context, state) => CustomerEventInvitationsScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'rsvp',
                builder: (context, state) => EventRsvpScreen(
                  eventId: state.pathParameters['id']!,
                  token: state.uri.queryParameters['token'],
                  action: state.uri.queryParameters['action'],
                ),
              ),
              GoRoute(
                path: 'ai-planner',
                builder: (context, state) => CustomerEventAiPlannerScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'day',
                builder: (context, state) => CustomerEventDayScreen(
                  eventId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'check-in',
                    builder: (context, state) {
                      final eventId = state.pathParameters['id']!;
                      return CustomerEventOpsModuleScreen(
                        eventId: eventId,
                        title: 'Check-in',
                        subtitle: 'Guest arrivals and entry',
                        body: CheckInCenterScreen(eventId: eventId),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'scan',
                    builder: (context, state) {
                      final eventId = state.pathParameters['id']!;
                      return CustomerEventOpsModuleScreen(
                        eventId: eventId,
                        title: 'Scan tickets',
                        subtitle: 'QR check-in',
                        body: QrScanScreen(eventId: eventId),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'incidents',
                    builder: (context, state) {
                      final eventId = state.pathParameters['id']!;
                      return CustomerEventOpsModuleScreen(
                        eventId: eventId,
                        title: 'Incidents',
                        subtitle: 'Operational issues',
                        body: IncidentCenterScreen(eventId: eventId),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'feed',
                    builder: (context, state) {
                      final eventId = state.pathParameters['id']!;
                      return CustomerEventOpsModuleScreen(
                        eventId: eventId,
                        title: 'Command feed',
                        subtitle: 'Live operational timeline',
                        body: LiveEventFeedScreen(eventId: eventId),
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'website',
                builder: (context, state) => CustomerEventWebsiteScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'wall',
                builder: (context, state) => CustomerEventWallScreen(
                  eventId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'display',
                    builder: (context, state) => CustomerEventWallDisplayScreen(
                      eventId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'attire',
                builder: (context, state) => CustomerEventAttireScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'rentals',
                builder: (context, state) => CustomerEventRentalsScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'seating',
                builder: (context, state) => CustomerEventSeatingScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'program',
                builder: (context, state) => CustomerEventProgramScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'vendor-pipeline',
                builder: (context, state) => CustomerEventVendorPipelineScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'aso-ebi',
                redirect: (context, state) =>
                    '/events/${state.pathParameters['id']}/attire',
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/vendors',
        builder: (context, state) => MarketplaceScreen(
          eventId: state.uri.queryParameters['eventId'],
          initialCategory: state.uri.queryParameters['category'],
          vendorBuyerMode: state.uri.queryParameters['vendorBuyer'] == '1',
        ),
        routes: [
          GoRoute(
            path: 'rentals',
            builder: (context, state) => MarketplaceRentalsScreen(
              eventId: state.uri.queryParameters['eventId'],
              vendorBuyerMode: state.uri.queryParameters['vendorBuyer'] == '1',
            ),
          ),
          GoRoute(
            path: ':vendorId',
            builder: (context, state) => MarketplaceVendorDetailScreen(
              vendorId: state.pathParameters['vendorId']!,
              eventId: state.uri.queryParameters['eventId'],
              initialService: state.uri.queryParameters['service'],
              vendorBuyerMode: state.uri.queryParameters['vendorBuyer'] == '1',
            ),
          ),
        ],
      ),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/auth/attendee',
        redirect: (context, state) => ExperienceRoutes.auth,
      ),
      GoRoute(
        path: '/auth/organizer',
        redirect: (context, state) => ExperienceRoutes.auth,
      ),
      GoRoute(
        path: '/auth/vendor',
        redirect: (context, state) => ExperienceRoutes.auth,
      ),
      // /auth/admin is registered above as AdminAuthScreen (Admin Flutter entry).
      GoRoute(
        path: '/onboarding/complete',
        redirect: (context, state) {
          final role = state.uri.queryParameters['role'];
          if (role == UserRole.vendor.name) return PortalRoutes.onboardingFor(UserRole.vendor);
          return null;
        },
        builder: (context, state) {
          final roleName = state.uri.queryParameters['role'] ?? UserRole.client.name;
          final role = UserRole.values.byName(roleName);
          return OnboardingFormScreen(role: role);
        },
      ),
      GoRoute(path: '/payment/success', builder: (context, state) => const PaymentSuccessScreen()),
      ...attendeeCommerceRoutes(),
      GoRoute(
        path: '/attendee',
        builder: (context, state) => const AttendeeDashboardScreen(),
      ),
      GoRoute(
        path: '/attending',
        redirect: (context, state) => '/attendee/find-ticket',
      ),
      GoRoute(
        path: '/staff/login',
        redirect: (context, state) => PortalRoutes.authFor(UserRole.admin),
      ),
      GoRoute(path: '/login', redirect: (context, state) => PortalRoutes.gate),
      GoRoute(
        path: '/vendor',
        builder: (context, state) => const VendorHomeScreen(),
        routes: [
          GoRoute(
            path: 'fashion-attire',
            builder: (context, state) => const VendorFashionAttireScreen(),
          ),
          GoRoute(
            path: 'rentals',
            builder: (context, state) => const VendorRentalsScreen(),
          ),
          GoRoute(
            path: 'crm',
            builder: (context, state) => const VendorCrmScreen(),
          ),
          GoRoute(
            path: 'services',
            builder: (context, state) => const VendorServicesAvailabilityScreen(),
            onExit: (context, state) {
              return UnsavedChangesRegistry.confirmLeave(
                context,
                binder: UnsavedChangesRegistry.vendorServices,
              );
            },
          ),
          GoRoute(
            path: 'calendar',
            builder: (context, state) => const VendorCalendarScreen(),
          ),
          GoRoute(
            path: 'onboarding',
            builder: (context, state) => const VendorOnboardingScreen(),
          ),
          GoRoute(
            path: 'offerings',
            builder: (context, state) => const VendorMyOfferingsScreen(),
          ),
          GoRoute(
            path: 'marketplace',
            redirect: (context, state) {
              final eventId = state.uri.queryParameters['eventId'];
              if (eventId != null && eventId.isNotEmpty) {
                return '/vendors?eventId=${Uri.encodeComponent(eventId)}&vendorBuyer=1';
              }
              return '/vendors?vendorBuyer=1';
            },
          ),
        ],
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
      GoRoute(path: '/super-admin', builder: (context, state) => const SuperAdminHomeScreen()),
      GoRoute(
        path: '/super-admin/commerce/vendor-pricing',
        builder: (context, state) => const AdminVendorPricingScreen(),
      ),
      GoRoute(
        path: '/super-admin/commerce/vendor-configuration',
        builder: (context, state) => const VendorConfigurationHubScreen(),
        routes: [
          GoRoute(
            path: 'capabilities',
            builder: (context, state) => const VendorBusinessCapabilitiesScreen(),
          ),
          GoRoute(
            path: 'service-categories',
            builder: (context, state) => const VendorOfferingCategoriesScreen(offeringKind: 'service'),
          ),
          GoRoute(
            path: 'rental-categories',
            builder: (context, state) => const VendorOfferingCategoriesScreen(offeringKind: 'rental'),
          ),
          GoRoute(
            path: 'resources',
            builder: (context, state) => const VendorResourceCatalogueScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/super-admin/commerce/vendor-capabilities',
        builder: (context, state) => const AdminVendorCategoriesScreen(),
        routes: [
          GoRoute(
            path: ':categoryId',
            builder: (context, state) => AdminVendorCapabilityDetailScreen(
              categoryId: state.pathParameters['categoryId'] ?? '',
            ),
            onExit: (context, state) {
              return UnsavedChangesRegistry.confirmLeave(
                context,
                binder: UnsavedChangesRegistry.adminCapabilityDetail,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/super-admin/platform-config',
        builder: (context, state) => const PlatformConfigurationScreen(),
      ),
      GoRoute(
        path: '/super-admin/vendor-governance',
        builder: (context, state) => const VendorGovernanceScreen(),
      ),
      GoRoute(
        path: '/organizer',
        builder: (context, state) => const OrganizerHomeScreen(),
        routes: [
          GoRoute(
            path: 'onboarding',
            builder: (context, state) => const OrganizerOnboardingScreen(),
          ),
          GoRoute(
            path: 'events/new',
            builder: (context, state) => const EventCreateWizardV2Screen(),
          ),
          GoRoute(
            path: 'events/:eventId',
            builder: (context, state) => EventWorkspaceScreen(
              eventId: state.pathParameters['eventId']!,
              initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0,
              initialTabKey: state.uri.queryParameters['tabKey'],
            ),
          ),
        ],
      ),
    ],
  );
});
