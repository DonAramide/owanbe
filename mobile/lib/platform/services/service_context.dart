import '../../platform/identity/identity_models.dart';

class ServiceContext {
  const ServiceContext({
    required this.userContext,
    required this.tenantId,
    required this.workspaceId,
    required this.permissions,
    required this.correlationId,
    required this.locale,
    required this.featureFlags,
  });

  final UserContext? userContext;
  final String tenantId;
  final String workspaceId;
  final List<String> permissions;
  final String correlationId;
  final String locale;
  final Map<String, bool> featureFlags;
}
