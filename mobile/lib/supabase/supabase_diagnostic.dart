/// Classified Supabase configuration / connectivity failure.
enum SupabaseFailureKind {
  configMissing,
  missingUrl,
  missingAnonKey,
  whitespaceInUrl,
  whitespaceInAnonKey,
  invalidUri,
  notHttps,
  invalidHostname,
  malformedProjectRef,
  internetUnavailable,
  dnsFailure,
  tlsFailure,
  timeout,
  supabaseUnavailable,
  unknown,
}

/// User-facing + developer diagnostic for Supabase startup/auth failures.
class SupabaseDiagnostic {
  const SupabaseDiagnostic({
    required this.kind,
    required this.title,
    required this.message,
    this.configuredUrl,
    this.technicalDetail,
    this.steps = const [],
  });

  final SupabaseFailureKind kind;
  final String title;
  final String message;
  final String? configuredUrl;
  final String? technicalDetail;
  final List<String> steps;

  bool get isConfigurationError =>
      kind == SupabaseFailureKind.configMissing ||
      kind == SupabaseFailureKind.missingUrl ||
      kind == SupabaseFailureKind.missingAnonKey ||
      kind == SupabaseFailureKind.whitespaceInUrl ||
      kind == SupabaseFailureKind.whitespaceInAnonKey ||
      kind == SupabaseFailureKind.invalidUri ||
      kind == SupabaseFailureKind.notHttps ||
      kind == SupabaseFailureKind.invalidHostname ||
      kind == SupabaseFailureKind.malformedProjectRef;

  List<String> get resolvedSteps {
    if (steps.isNotEmpty) return steps;
    if (isConfigurationError) {
      return const [
        'Fix SUPABASE_URL / SUPABASE_ANON_KEY in mobile/assets/env/supabase.env.',
        'Ensure both Customer and Admin use the same env asset.',
        'Rebuild or hot-restart the app after changes.',
      ];
    }
    return switch (kind) {
      SupabaseFailureKind.internetUnavailable => const [
          'Check Wi-Fi or mobile data.',
          'Disable airplane mode.',
          'Try again when the device is online.',
        ],
      SupabaseFailureKind.dnsFailure => const [
          'Confirm the device has working DNS (try opening a website in the browser).',
          'Verify SUPABASE_URL hostname in assets/env/supabase.env.',
          'Hot restart the app after fixing network or configuration.',
        ],
      SupabaseFailureKind.tlsFailure => const [
          'Check device date/time settings.',
          'If on a corporate network, confirm HTTPS is not blocked.',
          'Retry after network conditions improve.',
        ],
      SupabaseFailureKind.timeout ||
      SupabaseFailureKind.supabaseUnavailable => const [
          'Confirm the Supabase project is not paused (Dashboard -> Project Settings).',
          'Retry in a few moments.',
          'If this persists, check status.supabase.com.',
          'On Flutter Web: open the Supabase URL in the same browser, or run with -d windows / Android.',
        ],
      _ => const [
          'Retry when the network is stable.',
          'If this continues, capture logs for engineering.',
        ],
    };
  }

  /// Short label for diagnostics UI / logs.
  String get kindLabel => switch (kind) {
        SupabaseFailureKind.configMissing ||
        SupabaseFailureKind.missingUrl ||
        SupabaseFailureKind.missingAnonKey ||
        SupabaseFailureKind.whitespaceInUrl ||
        SupabaseFailureKind.whitespaceInAnonKey ||
        SupabaseFailureKind.invalidUri ||
        SupabaseFailureKind.notHttps ||
        SupabaseFailureKind.invalidHostname ||
        SupabaseFailureKind.malformedProjectRef =>
          'Invalid configuration',
        SupabaseFailureKind.internetUnavailable => 'No Internet Connection',
        SupabaseFailureKind.dnsFailure => 'DNS failure',
        SupabaseFailureKind.tlsFailure => 'TLS failure',
        SupabaseFailureKind.timeout => 'Request timeout',
        SupabaseFailureKind.supabaseUnavailable => 'Supabase unavailable',
        SupabaseFailureKind.unknown => 'Unknown connectivity error',
      };
}
