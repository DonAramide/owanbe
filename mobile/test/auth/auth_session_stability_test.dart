import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/auth/auth_session.dart';
import 'package:owambe/auth/user_role.dart';

void main() {
  const enriched = AuthSession(
    userId: 'user-1',
    displayName: 'Ada Lovelace',
    role: UserRole.organizer,
    email: 'ada@owanbe.test',
    onboardingComplete: true,
    signupPortal: 'organizer',
    roles: ['organizer', 'vendor'],
  );

  test('token refresh must not replace API-enriched session', () {
    expect(
      shouldReplaceAuthSessionForSupabaseEvent(
        isTokenRefresh: true,
        isInitialSession: false,
        currentUserId: enriched.userId,
        incomingUserId: enriched.userId,
      ),
      isFalse,
    );
  });

  test('initialSession for the same user must not replace enriched session', () {
    expect(
      shouldReplaceAuthSessionForSupabaseEvent(
        isTokenRefresh: false,
        isInitialSession: true,
        currentUserId: enriched.userId,
        incomingUserId: enriched.userId,
      ),
      isFalse,
    );
  });

  test('sign-in / user change still replaces session', () {
    expect(
      shouldReplaceAuthSessionForSupabaseEvent(
        isTokenRefresh: false,
        isInitialSession: false,
        currentUserId: null,
        incomingUserId: 'user-1',
      ),
      isTrue,
    );
    expect(
      shouldReplaceAuthSessionForSupabaseEvent(
        isTokenRefresh: false,
        isInitialSession: true,
        currentUserId: 'old-user',
        incomingUserId: 'user-1',
      ),
      isTrue,
    );
  });

  test('equal identity fields do not notify Riverpod', () {
    const again = AuthSession(
      userId: 'user-1',
      displayName: 'Ada Lovelace',
      role: UserRole.organizer,
      email: 'ada@owanbe.test',
      onboardingComplete: true,
      signupPortal: 'organizer',
      roles: ['organizer', 'vendor'],
    );
    expect(enriched, equals(again));
    expect(enriched == again, isTrue);
  });

  test('JWT-only session is not equal to API-enriched session', () {
    const jwtOnly = AuthSession(
      userId: 'user-1',
      displayName: 'ada@owanbe.test',
      role: UserRole.organizer,
      email: 'ada@owanbe.test',
      onboardingComplete: false,
      roles: [],
    );
    expect(enriched == jwtOnly, isFalse);
  });
}
