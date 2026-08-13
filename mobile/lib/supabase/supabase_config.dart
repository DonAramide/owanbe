import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'supabase_diagnostic.dart';

/// Authoritative Supabase public configuration — single load path for Customer and Admin.
///
/// Source of truth: `assets/env/owanbe_config` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
///
/// Named without a `.env` suffix so Flutter Web can fetch the asset (many
/// servers return 404 for `*.env`).
class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    required this.uri,
    required this.host,
    required this.projectRef,
  });

  static const assetFileName = 'assets/env/owanbe_config';

  final String url;
  final String anonKey;
  final Uri uri;
  final String host;
  final String projectRef;

  static SupabaseConfig? _cached;
  static bool _dotenvLoaded = false;

  /// Last successfully validated config (null until [load] succeeds).
  static SupabaseConfig? get current => _cached;

  /// Loads dotenv once, validates, and caches. Throws [SupabaseConfigException] on failure.
  static Future<SupabaseConfig> load({String fileName = assetFileName}) async {
    if (_cached != null) return _cached!;

    try {
      if (!_dotenvLoaded) {
        await dotenv.load(fileName: fileName);
        _dotenvLoaded = true;
      }
    } catch (e) {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.configMissing,
          title: 'Supabase configuration is invalid.',
          message:
              'Could not load $fileName. Ensure the asset is listed in pubspec.yaml and rebuild the app.',
          technicalDetail: '$e',
        ),
      );
    }

    final config = parseAndValidate(Map<String, String>.from(dotenv.env));
    _cached = config;
    return config;
  }

  /// Pure validation — used by unit tests and startup checks.
  static SupabaseConfig parseAndValidate(Map<String, String> env) {
    final urlRaw = env['SUPABASE_URL'];
    final anonRaw = env['SUPABASE_ANON_KEY'];

    if (urlRaw == null || urlRaw.isEmpty) {
      throw const SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.missingUrl,
          title: 'Supabase configuration is invalid.',
          message: 'SUPABASE_URL is missing from assets/env/owanbe_config.',
        ),
      );
    }
    if (anonRaw == null || anonRaw.isEmpty) {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.missingAnonKey,
          title: 'Supabase configuration is invalid.',
          message: 'SUPABASE_ANON_KEY is missing from assets/env/owanbe_config.',
          configuredUrl: urlRaw,
        ),
      );
    }

    if (urlRaw != urlRaw.trim() || RegExp(r'\s').hasMatch(urlRaw)) {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.whitespaceInUrl,
          title: 'Supabase configuration is invalid.',
          message: 'SUPABASE_URL contains leading/trailing or embedded whitespace.',
          configuredUrl: urlRaw,
          technicalDetail:
              'rawLength=${urlRaw.length} trimmedLength=${urlRaw.trim().length}',
        ),
      );
    }
    if (anonRaw != anonRaw.trim() || RegExp(r'\s').hasMatch(anonRaw)) {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.whitespaceInAnonKey,
          title: 'Supabase configuration is invalid.',
          message: 'SUPABASE_ANON_KEY contains leading/trailing or embedded whitespace.',
          configuredUrl: urlRaw.trim(),
        ),
      );
    }

    final url = urlRaw.trim();
    final anon = anonRaw.trim();

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.invalidUri,
          title: 'Supabase configuration is invalid.',
          message: 'SUPABASE_URL is not a valid URI.',
          configuredUrl: url,
        ),
      );
    }
    if (uri.scheme.toLowerCase() != 'https') {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.notHttps,
          title: 'Supabase configuration is invalid.',
          message: 'SUPABASE_URL must use HTTPS (got "${uri.scheme}").',
          configuredUrl: url,
        ),
      );
    }

    final host = uri.host;
    if (!_isValidHostname(host)) {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.invalidHostname,
          title: 'Supabase configuration is invalid.',
          message: 'SUPABASE_URL hostname "$host" is not a valid host name.',
          configuredUrl: url,
        ),
      );
    }

    final projectRef = _extractProjectRef(host);
    if (projectRef == null) {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.malformedProjectRef,
          title: 'Supabase configuration is invalid.',
          message:
              'SUPABASE_URL hostname does not look like a Supabase project '
              '(expected <project-ref>.supabase.co). Got "$host".',
          configuredUrl: url,
        ),
      );
    }

    final jwtRef = _projectRefFromAnonJwt(anon);
    if (jwtRef != null && jwtRef != projectRef) {
      throw SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.malformedProjectRef,
          title: 'Supabase configuration is invalid.',
          message:
              'SUPABASE_ANON_KEY project ref "$jwtRef" does not match URL project ref "$projectRef".',
          configuredUrl: url,
          technicalDetail: 'urlRef=$projectRef jwtRef=$jwtRef',
        ),
      );
    }

    return SupabaseConfig(
      url: url,
      anonKey: anon,
      uri: uri,
      host: host,
      projectRef: projectRef,
    );
  }

  /// Test helper — do not call from production UI.
  static void debugReset() {
    _cached = null;
    _dotenvLoaded = false;
  }

  static bool _isValidHostname(String host) {
    if (host.isEmpty || host.length > 253) return false;
    if (host.startsWith('.') || host.endsWith('.')) return false;
    if (RegExp(r'\s').hasMatch(host)) return false;
    final labels = host.split('.');
    if (labels.length < 2) return false;
    for (final label in labels) {
      if (label.isEmpty || label.length > 63) return false;
      if (label.length == 1) {
        if (!RegExp(r'^[a-zA-Z0-9]$').hasMatch(label)) return false;
        continue;
      }
      if (!RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$').hasMatch(label)) {
        return false;
      }
    }
    return true;
  }

  /// Returns project ref for `*.supabase.co`, else null.
  static String? _extractProjectRef(String host) {
    final lower = host.toLowerCase();
    if (!lower.endsWith('.supabase.co')) return null;
    final ref = lower.substring(0, lower.length - '.supabase.co'.length);
    if (ref.isEmpty || ref.contains('.')) return null;
    if (!RegExp(r'^[a-z0-9]{10,32}$').hasMatch(ref)) return null;
    return ref;
  }

  static String? _projectRefFromAnonJwt(String anonKey) {
    try {
      final parts = anonKey.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final pad = payload.length % 4;
      if (pad > 0) payload = payload.padRight(payload.length + (4 - pad), '=');
      final json = utf8.decode(base64.decode(payload));
      final map = jsonDecode(json);
      if (map is Map && map['ref'] != null) {
        return map['ref'].toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Thrown when bundled Supabase configuration fails validation.
class SupabaseConfigException implements Exception {
  const SupabaseConfigException(this.diagnostic);

  final SupabaseDiagnostic diagnostic;

  @override
  String toString() =>
      'SupabaseConfigException(${diagnostic.kind.name}): ${diagnostic.message}';
}
