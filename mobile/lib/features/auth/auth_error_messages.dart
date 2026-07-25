import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api/identity_api.dart';
import '../../core/api/owanbe_api_auth.dart';
import '../../supabase/supabase_config.dart';
import '../../supabase/supabase_connectivity.dart';
import '../../supabase/supabase_diagnostic.dart';

/// User-facing auth error copy — never show raw Supabase/HTTP exceptions in the UI.
class AuthErrorMessage {
  const AuthErrorMessage({
    required this.title,
    required this.body,
    this.steps = const [],
  });

  final String title;
  final String body;
  final List<String> steps;

  @override
  String toString() => '$title\n$body';

  factory AuthErrorMessage.fromDiagnostic(SupabaseDiagnostic d) {
    return AuthErrorMessage(
      title: d.title,
      body: d.message,
      steps: d.resolvedSteps,
    );
  }
}

/// Maps auth failures to contextual UX copy.
///
/// [isSignUp] — email create-account flow (vs returning sign-in).
/// [afterSupabaseAuth] — Supabase succeeded; failure is from Owambe API / profile sync.
AuthErrorMessage formatAuthError(
  Object error, {
  String roleLabel = 'this portal',
  bool isSignUp = false,
  bool afterSupabaseAuth = false,
}) {
  final apiBase = OwambeApiAuth.resolveApiBase();

  if (error is SupabaseConfigException) {
    return AuthErrorMessage.fromDiagnostic(error.diagnostic);
  }

  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    // AuthException sometimes wraps network failures.
    if (_looksLikeNetworkFailure(msg) || _looksLikeNetworkFailure(error.toString())) {
      final diagnostic = SupabaseConnectivity.classifyNetworkError(error);
      return AuthErrorMessage.fromDiagnostic(diagnostic);
    }
    if (error.statusCode == 429 ||
        msg.contains('rate limit') ||
        msg.contains('over_email') ||
        msg.contains('too many requests')) {
      final isEmailSendLimit = msg.contains('over_email') || msg.contains('email rate limit');
      return AuthErrorMessage(
        title: isSignUp
            ? 'Supabase development rate limit reached'
            : 'Supabase rate limit reached',
        body: isSignUp
            ? (isEmailSendLimit
                ? 'Supabase Auth blocked this sign-up because the project email-send quota was exceeded. '
                    'This is a Supabase Auth limit — not an Owanbe application failure. '
                    'Your account was not created and Owambe was never contacted.'
                : 'Supabase Auth is temporarily limiting requests from this device. '
                    'This is not an Owanbe application failure.')
            : 'Supabase Auth is temporarily limiting sign-in attempts. '
                'This is not an Owanbe application failure.',
        steps: isSignUp
            ? const [
                'Wait about 1 hour for the built-in email quota to reset (2 emails/hour on default Supabase SMTP).',
                'Dev shortcut: use an existing seeded account — attendee@owanbe.dev / 123456.',
                'Or create the user manually in Supabase Dashboard → Authentication → Users.',
                'Long-term: configure custom SMTP and raise Auth → Rate Limits in Supabase Dashboard.',
              ]
            : const [
                'Wait a few minutes, then try again.',
                'If this persists, check Supabase Dashboard → Authentication → Rate Limits.',
              ],
      );
    }
    if (msg.contains('email not confirmed') || msg.contains('email_not_confirmed')) {
      return const AuthErrorMessage(
        title: 'Email not confirmed',
        body: 'Please confirm your email address before signing in.',
        steps: [
          'Check your inbox for a confirmation link from Supabase, or',
          'In development, confirm the user in Supabase Dashboard → Authentication.',
        ],
      );
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered') ||
        msg.contains('email already')) {
      return const AuthErrorMessage(
        title: 'Email already in use',
        body: 'An account with this email already exists.',
        steps: [
          'Switch to Sign in if you already have an account.',
          'Use Forgot password if you need to reset your password.',
        ],
      );
    }
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return AuthErrorMessage(
        title: isSignUp ? 'Could not create account' : 'Invalid email or password',
        body: isSignUp
            ? 'We could not create an account with these credentials.'
            : 'Supabase rejected these credentials (${error.message}).',
        steps: isSignUp
            ? const [
                'Try a different email or a stronger password.',
                'If you already have an account, switch to Sign in.',
              ]
            : const [
                'Check for typos — password is 123456 for dev accounts.',
                'Hot restart the app (press R in flutter run), then try again.',
                'Dev: attendee@owanbe.dev / 123456',
              ],
      );
    }
    return AuthErrorMessage(
      title: isSignUp ? 'Sign-up failed' : 'Sign-in failed',
      body: error.message,
      steps: const ['Try again in a few seconds.'],
    );
  }

  if (error is IdentityApiException) {
    if (error.isRoleMismatch) {
      return AuthErrorMessage(
        title: 'Access denied',
        body: error.message,
        steps: [
          'This email is already registered for a different Owambe portal.',
          'Sign out and use the portal your account was created with.',
        ],
      );
    }
    if (error.isNotRegistered) {
      return AuthErrorMessage(
        title: isSignUp ? 'Finish creating your account' : 'Account not ready',
        body: error.message,
        steps: isSignUp
            ? const ['Try again in a few seconds.', 'Contact support if this continues.']
            : const [
                'Switch to “Create account” if you are new to Owanbe.',
                'Otherwise sign in with the email you registered.',
              ],
      );
    }
    if (error.isUserPersistFailed) {
      return AuthErrorMessage(
        title: isSignUp ? 'Account setup incomplete' : 'Profile sync failed',
        body: error.message,
        steps: [
          'Your sign-in was accepted but your Owanbe profile could not be saved.',
          'Check that the Owambe API is running at $apiBase.',
          'Try signing in again — your account may already exist.',
        ],
      );
    }
    if (error.isApiUnavailable || error.code.toUpperCase().startsWith('HTTP_')) {
      return AuthErrorMessage(
        title: 'Cannot reach Owanbe',
        body: 'We could not connect to the Owanbe API at $apiBase.',
        steps: [
          'Confirm the API server is running.',
          'On a physical device, set OWANBE_API_BASE in mobile/assets/env/supabase.env to your PC IP or use adb reverse.',
          'Hot restart the app after changing environment variables.',
        ],
      );
    }
    return AuthErrorMessage(
      title: isSignUp ? 'Sign-up failed' : 'Sign-in failed',
      body: error.message,
      steps: const ['Try again in a few seconds.'],
    );
  }

  final raw = error.toString().toLowerCase();

  if (raw.contains('account created') && raw.contains('verify')) {
    return const AuthErrorMessage(
      title: 'Confirm your email',
      body: 'Your account was created. Please verify your email before signing in.',
      steps: [
        'Check your inbox for a confirmation link.',
        'In development, confirm the user in Supabase Dashboard → Authentication.',
        'Then return here and sign in.',
      ],
    );
  }

  if (raw.contains('account created') && raw.contains('confirm')) {
    return const AuthErrorMessage(
      title: 'Confirm your email',
      body: 'Your account was created. Please confirm your email before signing in.',
      steps: [
        'Check your inbox for a confirmation link.',
        'Then return here and sign in.',
      ],
    );
  }

  if (afterSupabaseAuth &&
      (raw.contains('invalid or expired token') || raw.contains('invalid_token'))) {
    return const AuthErrorMessage(
      title: 'Almost signed in',
      body: 'Authentication succeeded, but profile sync hit a temporary session race. '
          'Please try Sign in once more.',
      steps: [
        'Tap Sign in again.',
        'If it keeps failing, refresh the page and retry.',
      ],
    );
  }

  if (afterSupabaseAuth &&
      (raw.contains('socket') ||
          raw.contains('connection') ||
          raw.contains('failed host lookup') ||
          raw.contains('clientexception') ||
          raw.contains('timeout'))) {
    return AuthErrorMessage(
      title: 'Signed in — profile sync pending',
      body: 'Authentication succeeded but Owanbe could not finish setting up your profile.',
      steps: [
        'Verify the API is running at $apiBase.',
        'Try signing in again in a few seconds.',
      ],
    );
  }

  if (_looksLikeNetworkFailure(raw)) {
    if (afterSupabaseAuth) {
      return AuthErrorMessage(
        title: 'Cannot reach Owanbe API',
        body: 'You are signed in to Owanbe Auth but the profile service at $apiBase is unreachable.',
        steps: const [
          'Start the NestJS API (services/api).',
          'On Android USB debugging run: adb reverse tcp:8080 tcp:8080',
          'Hot restart the app.',
        ],
      );
    }
    final diagnostic = SupabaseConnectivity.classifyNetworkError(error);
    return AuthErrorMessage.fromDiagnostic(diagnostic);
  }

  if (raw.contains('database error querying schema') || raw.contains('unexpected_failure')) {
    return AuthErrorMessage(
      title: 'Authentication database needs setup',
      body: 'Supabase Auth returned a server error while validating your account.',
      steps: const [
        'In Supabase SQL Editor, run scripts/supabase/repair-auth-null-columns.sql if needed.',
        'Then run scripts/supabase/seed-dev-auth-users.sql for development accounts.',
        'Sign in again after seeding.',
      ],
    );
  }

  if (raw.contains('user already registered') ||
      raw.contains('email already') ||
      raw.contains('already been registered')) {
    return const AuthErrorMessage(
      title: 'Email already in use',
      body: 'An account with this email already exists.',
      steps: [
        'Switch to Sign in if you already have an account.',
        'Use Forgot password if you need to reset your password.',
      ],
    );
  }

  if (raw.contains('invalid_credentials') || raw.contains('invalid login credentials')) {
    return AuthErrorMessage(
      title: isSignUp ? 'Could not create account' : 'Invalid email or password',
      body: isSignUp
          ? 'We could not create an account with these credentials.'
          : 'The credentials you entered could not be verified.',
      steps: isSignUp
          ? const [
              'Try a different email or a stronger password.',
              'If you already have an account, switch to Sign in.',
            ]
          : const [
              'Check your email and password, or use Forgot password.',
              'Contact your administrator if you need a new account.',
            ],
    );
  }

  if (raw.contains('role mismatch') || raw.contains('role_mismatch')) {
    return AuthErrorMessage(
      title: 'Wrong portal for this account',
      body: 'You signed in successfully, but this account is not authorized for $roleLabel.',
      steps: const [
        'Use the workspace your account was created for.',
        'Contact support if you need access to another experience.',
      ],
    );
  }

  if (raw.contains('email not confirmed')) {
    return const AuthErrorMessage(
      title: 'Email not confirmed',
      body: 'Please confirm your email address before signing in.',
      steps: [
        'Check your inbox for a confirmation link from Supabase, or',
        'In development, confirm the user in Supabase Dashboard → Authentication.',
      ],
    );
  }

  if (raw.contains('too many requests') ||
      raw.contains('rate limit') ||
      raw.contains('over_email_send_rate_limit') ||
      raw.contains('over_email')) {
    final isEmailSend = raw.contains('over_email') || raw.contains('email rate limit');
    return AuthErrorMessage(
      title: isSignUp
          ? 'Supabase development rate limit reached'
          : 'Supabase rate limit reached',
      body: isSignUp
          ? (isEmailSend
              ? 'Supabase Auth blocked this sign-up because the project email-send quota was exceeded. '
                  'This is a Supabase Auth limit — not an Owanbe application failure.'
              : 'Supabase Auth is temporarily limiting sign-up requests. '
                  'This is not an Owanbe application failure.')
          : 'Supabase Auth is temporarily limiting requests. '
              'This is not an Owanbe application failure.',
      steps: isSignUp
          ? const [
              'Wait about 1 hour for the built-in email quota to reset (2 emails/hour on default Supabase SMTP).',
              'Dev shortcut: attendee@owanbe.dev / 123456.',
              'Or create the user in Supabase Dashboard → Authentication → Users.',
              'Long-term: configure custom SMTP and raise Auth → Rate Limits in Supabase Dashboard.',
            ]
          : const ['Wait a few minutes and try again.'],
    );
  }

  if (raw.contains('password') && (raw.contains('weak') || raw.contains('short'))) {
    return const AuthErrorMessage(
      title: 'Password too weak',
      body: 'Choose a stronger password and try again.',
      steps: [
        'Use at least 8 characters with letters and numbers.',
      ],
    );
  }

  return AuthErrorMessage(
    title: isSignUp ? 'Sign-up failed' : 'Sign-in failed',
    body: isSignUp
        ? 'Something went wrong while creating your account. If this continues, contact support.'
        : 'Something went wrong while signing you in. If this continues, contact support.',
    steps: const [
      'Try again in a few seconds.',
      'Sign out of other sessions and refresh the app.',
    ],
  );
}

bool _looksLikeNetworkFailure(String raw) {
  return raw.contains('failed to fetch') ||
      raw.contains('clientexception') ||
      raw.contains('authretryablefetchexception') ||
      raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network is unreachable') ||
      raw.contains('network unreachable') ||
      raw.contains('connection refused') ||
      raw.contains('connection reset') ||
      raw.contains('no route to host') ||
      raw.contains('handshakeexception') ||
      raw.contains('tlsexception') ||
      raw.contains('timeout') ||
      raw.contains('timed out');
}
