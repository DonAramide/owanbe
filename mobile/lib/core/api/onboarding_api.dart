import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'events_api.dart';
import 'owanbe_api_auth.dart';

class OnboardingApiException implements Exception {
  OnboardingApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'OnboardingApiException($code): $message';
}

class VendorApplication {
  const VendorApplication({
    required this.id,
    required this.vendorId,
    required this.status,
  });

  final String id;
  final String vendorId;
  final String status;
}

class OnboardingApi {
  OnboardingApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  static const devVendorId = '55555555-5555-4555-8555-555555555555';

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId(EventsApi.devTenantId);

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw OnboardingApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is OnboardingApiException) rethrow;
      throw OnboardingApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<VendorApplication> createApplication(String vendorId) async {
    final key = const Uuid().v4();
    final headers = await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId);
    headers['Idempotency-Key'] = key;
    final res = await _http.post(
      _u('vendors/$vendorId/onboarding/applications'),
      headers: headers,
      body: jsonEncode({'idempotencyKey': key}),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return VendorApplication(
      id: (body['id'] ?? '').toString(),
      vendorId: (body['vendorId'] ?? vendorId).toString(),
      status: (body['status'] ?? 'applied').toString(),
    );
  }

  Future<void> upsertBusiness({
    required String vendorId,
    required String applicationId,
    required String legalName,
    String? tradingName,
    required String countryCode,
    String? city,
    String? websiteUrl,
  }) async {
    final res = await _http.put(
      _u('vendors/$vendorId/onboarding/applications/$applicationId/business'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'legalName': legalName,
        if (tradingName != null) 'tradingName': tradingName,
        'countryCode': countryCode,
        if (city != null) 'city': city,
        if (websiteUrl != null) 'websiteUrl': websiteUrl,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<VendorApplication> submit({
    required String vendorId,
    required String applicationId,
  }) async {
    final res = await _http.post(
      _u('vendors/$vendorId/onboarding/applications/$applicationId/submit'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return VendorApplication(
      id: applicationId,
      vendorId: vendorId,
      status: (body['status'] ?? 'under_review').toString(),
    );
  }
}
