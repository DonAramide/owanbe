import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'supabase_config.dart';
import 'supabase_diagnostic.dart';

/// Result of a startup / pre-auth connectivity probe.
class SupabaseConnectivityResult {
  const SupabaseConnectivityResult.ok()
      : ok = true,
        diagnostic = null;

  const SupabaseConnectivityResult.fail(this.diagnostic) : ok = false;

  final bool ok;
  final SupabaseDiagnostic? diagnostic;
}

/// HTTPS-only connectivity verification for Supabase Auth.
///
/// Does **not** use [InternetAddress.lookup] — on many Android Wi‑Fi networks
/// Dart DNS lookups hang/timeout even when HTTPS to Supabase works (or when
/// the OS Wi‑Fi indicator is “connected”). Health HTTP is the sole gate.
class SupabaseConnectivity {
  SupabaseConnectivity._();

  static const _healthTimeout = Duration(seconds: 15);

  /// Verifies the configured Supabase project Auth endpoint responds.
  static Future<SupabaseConnectivityResult> verify(SupabaseConfig config) async {
    final healthUri = config.uri.replace(path: '/auth/v1/health');

    try {
      final response = await http
          .get(
            healthUri,
            headers: {
              'apikey': config.anonKey,
              'Authorization': 'Bearer ${config.anonKey}',
            },
          )
          .timeout(_healthTimeout);

      if (response.statusCode >= 500) {
        return SupabaseConnectivityResult.fail(
          SupabaseDiagnostic(
            kind: SupabaseFailureKind.supabaseUnavailable,
            title: 'Authentication service is temporarily unavailable.',
            message:
                'Supabase Auth health returned HTTP ${response.statusCode}. '
                'The project may be paused or degraded.',
            configuredUrl: config.url,
            technicalDetail: 'GET $healthUri → ${response.statusCode}',
          ),
        );
      }

      if (kDebugMode) {
        debugPrint(
          'Supabase connectivity OK: host=${config.host} health=${response.statusCode}',
        );
      }
      return const SupabaseConnectivityResult.ok();
    } on TimeoutException catch (e) {
      return SupabaseConnectivityResult.fail(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.timeout,
          title: 'Authentication service is temporarily unavailable.',
          message:
              'Timed out reaching Supabase Auth at ${config.host}. '
              'Wi-Fi may show connected without a working internet path.',
          configuredUrl: config.url,
          technicalDetail: '$e',
        ),
      );
    } on http.ClientException catch (e) {
      return SupabaseConnectivityResult.fail(
        classifyNetworkError(e, configuredUrl: config.url),
      );
    } catch (e) {
      return SupabaseConnectivityResult.fail(
        classifyNetworkError(e, configuredUrl: config.url),
      );
    }
  }

  /// Maps raw network exceptions to a typed diagnostic (auth + startup).
  static SupabaseDiagnostic classifyNetworkError(
    Object error, {
    String? configuredUrl,
  }) {
    final typeName = error.runtimeType.toString().toLowerCase();
    final raw = error.toString().toLowerCase();
    final url = configuredUrl ?? SupabaseConfig.current?.url;

    if (typeName.contains('handshake') ||
        typeName.contains('tls') ||
        raw.contains('handshake') ||
        raw.contains('certificate') ||
        (raw.contains('ssl') && !raw.contains('socket')) ||
        raw.contains('tls')) {
      return SupabaseDiagnostic(
        kind: SupabaseFailureKind.tlsFailure,
        title: 'Supabase TLS connection failed.',
        message: 'A secure connection to Supabase could not be established.',
        configuredUrl: url,
        technicalDetail: '$error',
      );
    }

    if (typeName.contains('timeoutexception') ||
        raw.contains('timeout') ||
        raw.contains('timed out') ||
        raw.contains('future not completed')) {
      return SupabaseDiagnostic(
        kind: SupabaseFailureKind.timeout,
        title: 'Authentication service is temporarily unavailable.',
        message: 'The request to Supabase timed out.',
        configuredUrl: url,
        technicalDetail: '$error',
      );
    }

    if (raw.contains('failed host lookup') ||
        raw.contains('name or service not known') ||
        raw.contains('nodename nor servname') ||
        raw.contains('no address associated')) {
      return SupabaseDiagnostic(
        kind: SupabaseFailureKind.dnsFailure,
        title: 'Supabase host could not be resolved.',
        message:
            'Could not reach Supabase by hostname. Confirm Wi-Fi has working '
            'internet (open a website in the browser), not only that Wi-Fi is on.',
        configuredUrl: url,
        technicalDetail: '$error',
      );
    }

    if (raw.contains('network is unreachable') ||
        raw.contains('network unreachable') ||
        raw.contains('no route to host') ||
        raw.contains('software caused connection abort')) {
      return SupabaseDiagnostic(
        kind: SupabaseFailureKind.internetUnavailable,
        title: 'No Internet Connection',
        message: 'This device appears to be offline.',
        configuredUrl: url,
        technicalDetail: '$error',
      );
    }

    if (raw.contains('connection refused') ||
        raw.contains('connection reset') ||
        raw.contains('failed to fetch') ||
        raw.contains('clientexception') ||
        raw.contains('authretryablefetchexception') ||
        raw.contains('socketexception')) {
      final isWebFetch = kIsWeb && raw.contains('failed to fetch');
      return SupabaseDiagnostic(
        kind: SupabaseFailureKind.supabaseUnavailable,
        title: 'Authentication service is temporarily unavailable.',
        message: isWebFetch
            ? 'This browser could not reach Supabase Auth (Failed to fetch). '
                'The project itself is usually fine — Chrome/Web often blocks or loses '
                'outbound HTTPS while the host PC still has internet.'
            : 'Could not reach Supabase authentication right now.',
        configuredUrl: url,
        technicalDetail: '$error',
        steps: isWebFetch
            ? const [
                'In the same Chrome window, open your SUPABASE_URL and confirm it loads.',
                'Prefer a native target: flutter run -d windows  (or a physical Android device).',
                'If you must use Web, disable VPN/ad-block for localhost and supabase.co, then hard-refresh.',
                'Confirm the Supabase project is not paused in the Dashboard.',
              ]
            : const [],
      );
    }

    return SupabaseDiagnostic(
      kind: SupabaseFailureKind.unknown,
      title: 'Unable to reach the sign-in service',
      message: 'A network error prevented contacting Supabase.',
      configuredUrl: url,
      technicalDetail: '$error',
    );
  }
}
