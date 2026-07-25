import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when an API call requires a Supabase session but none is active.
class OwambeAuthRequiredException implements Exception {
  OwambeAuthRequiredException([this.message = 'Sign in required']);
  final String message;

  @override
  String toString() => 'OwambeAuthRequiredException: $message';
}

/// Shared JWT + tenant headers for Owambe REST clients (Phase 8 — no dev headers).
class OwambeApiAuth {
  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  /// Resolves API base URL. On a physical phone, `localhost` is the phone itself —
  /// use your PC's Wi‑Fi IP in `assets/env/supabase.env` (see OWANBE_API_BASE).
  static String resolveApiBase([String fallback = 'http://localhost:8080/v1']) {
    var raw = (dotenv.env['OWANBE_API_BASE'] ?? fallback).trim();
    if (!kIsWeb && Platform.isAndroid) {
      if (raw.contains('localhost')) {
        raw = raw.replaceAll('localhost', '10.0.2.2');
        debugPrint(
          'Owambe API: remapped localhost → 10.0.2.2 for Android emulator. '
          'On a real device, set OWANBE_API_BASE to your PC Wi‑Fi IP or run: adb reverse tcp:8080 tcp:8080',
        );
      } else if (raw.contains('127.0.0.1')) {
        debugPrint(
          'Owambe API: using 127.0.0.1 — on a physical Android device this only works with '
          'adb reverse tcp:8080 tcp:8080, otherwise set OWANBE_API_BASE to your PC Wi‑Fi IP.',
        );
      }
    }
    final resolved = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    debugPrint('Owambe API base: $resolved');
    return resolved;
  }

  static String resolveTenantId([String? fallback]) {
    final fromEnv = dotenv.env['OWANBE_TENANT_ID']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return fallback ?? devTenantId;
  }

  static String? accessToken() =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  static Future<Map<String, String>> authorizedHeaders({
    String? tenantId,
    bool json = true,
  }) async {
    final token = accessToken();
    if (token == null || token.isEmpty) {
      throw OwambeAuthRequiredException();
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Tenant-Id': tenantId ?? resolveTenantId(),
    };
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  static Map<String, String> publicHeaders({String? tenantId}) => {
        'Accept': 'application/json',
        'X-Tenant-Id': tenantId ?? resolveTenantId(),
      };
}
