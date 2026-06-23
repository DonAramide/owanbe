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
}

AuthErrorMessage formatAuthError(Object error, {String roleLabel = 'this portal'}) {
  final raw = error.toString().toLowerCase();

  if (raw.contains('failed to fetch') ||
      raw.contains('clientexception') ||
      raw.contains('authretryablefetchexception') ||
      raw.contains('socketexception') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection refused')) {
    return const AuthErrorMessage(
      title: 'Unable to reach the sign-in service',
      body:
          'We could not connect to Supabase authentication. This is usually a network or configuration issue, not your password.',
      steps: [
        'Confirm you are online and the Supabase project is not paused (Dashboard → Project Settings).',
        'Verify mobile/assets/env/supabase.env points to the correct SUPABASE_URL for this project.',
        'Restart the Flutter app after changing environment variables.',
        'If you use localhost, ensure your browser allows requests to *.supabase.co.',
      ],
    );
  }

  if (raw.contains('database error querying schema') || raw.contains('unexpected_failure')) {
    return const AuthErrorMessage(
      title: 'Authentication database needs setup',
      body: 'Supabase Auth returned a server error while validating your account.',
      steps: [
        'In Supabase SQL Editor, run scripts/supabase/repair-auth-null-columns.sql.',
        'Then run scripts/supabase/seed-dev-auth-users.sql.',
        'Sign in again with password 123456.',
      ],
    );
  }

  if (raw.contains('invalid_credentials') || raw.contains('invalid login credentials')) {
    return const AuthErrorMessage(
      title: 'Invalid email or password',
      body: 'The credentials you entered could not be verified.',
      steps: [
        'For development, use the seeded accounts (password 123456).',
        'If the account does not exist, run scripts/supabase/seed-dev-auth-users.sql in Supabase.',
      ],
    );
  }

  if (raw.contains('role mismatch')) {
    return AuthErrorMessage(
      title: 'Wrong portal for this account',
      body: 'You signed in successfully, but this account is not authorized for $roleLabel.',
      steps: [
        'Select the correct role tab above, or',
        'Update app_metadata.roles in Supabase for this user.',
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

  if (raw.contains('too many requests') || raw.contains('rate limit')) {
    return const AuthErrorMessage(
      title: 'Too many sign-in attempts',
      body: 'Please wait a moment and try again.',
    );
  }

  return AuthErrorMessage(
    title: 'Sign-in failed',
    body: 'Something went wrong while signing you in. If this continues, contact your platform administrator.',
    steps: [
      'Try again in a few seconds.',
      'Sign out of other sessions and refresh the page.',
    ],
  );
}
