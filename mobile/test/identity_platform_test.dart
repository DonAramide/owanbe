import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/platform/identity/identity_models.dart';
import 'package:owambe/auth/user_role.dart';

void main() {
  group('Identity Platform - UserContext Mapping Tests', () {
    test('UserContext should instantiate correctly with explicit active role', () {
      const context = UserContext(
        userId: 'test-user-123',
        displayName: 'John Doe',
        email: 'john@iips.dev',
        avatarUrl: 'https://iips.dev/avatar.png',
        roles: [UserRole.client, UserRole.organizer],
        activeRole: UserRole.client,
      );

      expect(context.userId, equals('test-user-123'));
      expect(context.displayName, equals('John Doe'));
      expect(context.email, equals('john@iips.dev'));
      expect(context.roles, contains(UserRole.organizer));
      expect(context.activeRole, equals(UserRole.client));
    });

    test('UserContext copyWith should correctly map state updates', () {
      const context = UserContext(
        userId: 'test-user-123',
        displayName: 'John Doe',
        email: 'john@iips.dev',
        avatarUrl: null,
        roles: [UserRole.client, UserRole.organizer],
        activeRole: UserRole.client,
      );

      final updated = context.copyWith(activeRole: UserRole.organizer);
      expect(updated.activeRole, equals(UserRole.organizer));
      expect(updated.displayName, equals('John Doe'));
    });
  });
}
