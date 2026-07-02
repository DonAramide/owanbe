import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/platform/services/service_context.dart';
import 'package:owambe/platform/services/service_registry.dart';
import 'package:owambe/platform/services/user_service.dart';
import 'package:owambe/platform/services/audit_service.dart';

void main() {
  group('Business Services Platform (BSP) Tests', () {
    late ServiceContext mockContext;

    setUp(() {
      ServiceRegistry.instance.registerAllDefaultServices();
      mockContext = const ServiceContext(
        userContext: null,
        tenantId: 'tenant-123',
        workspaceId: 'workspace-456',
        permissions: ['read', 'write'],
        correlationId: 'corr-789',
        locale: 'en',
        featureFlags: {},
      );
    });

    test('UserService should register user and write an audit event log', () async {
      final userService = ServiceRegistry.instance.resolve<IUserService>();
      final result = await userService.registerUser(mockContext, 'test@example.com', 'password123');

      expect(result.isSuccess, isTrue);
      expect(result.data, isTrue);
      
      // Verify audit event log entry was created
      final logs = AuditService.instance.logs;
      expect(logs.any((e) => e.operation == 'UserRegistration'), isTrue);
    });

    test('UserService should fail account suspension if permissions are missing', () async {
      final userService = ServiceRegistry.instance.resolve<IUserService>();
      final result = await userService.suspendAccount(mockContext, 'user-999');

      expect(result.isFailure, isTrue);
      expect(result.message, contains('Admin privileges required'));
    });
  });
}
