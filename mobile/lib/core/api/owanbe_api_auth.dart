import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when an API call requires a Supabase session but none is active.
class OwanbeAuthRequiredException implements Exception {
  OwanbeAuthRequiredException([this.message = 'Sign in required']);
  final String message;

  @override
  String toString() => 'OwanbeAuthRequiredException: $message';
}

/// Shared JWT + tenant headers for Owanbe REST clients (Phase 8 — no dev headers).
class OwanbeApiAuth {
  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  static String resolveApiBase([String fallback = 'http://localhost:8080/v1']) {
    final raw = (dotenv.env['OWANBE_API_BASE'] ?? fallback).trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
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
      throw OwanbeAuthRequiredException();
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
