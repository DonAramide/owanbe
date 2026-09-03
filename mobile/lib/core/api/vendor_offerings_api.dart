import 'dart:convert';

import 'package:http/http.dart' as http;

import 'event_config_api.dart';
import 'owambe_api_auth.dart';

class VendorOfferingsApiException implements Exception {
  VendorOfferingsApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VendorOfferingsApi {
  VendorOfferingsApi(this._http);
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();
  Uri _u(String path) => Uri.parse('$_base/${path.startsWith('/') ? path.substring(1) : path}');

  Future<Map<String, String>> _headers() =>
      OwambeApiAuth.authorizedHeaders(tenantId: OwambeApiAuth.resolveTenantId(EventConfigApi.devTenantId));

  Future<Map<String, dynamic>> _json(http.Response res) async {
    if (res.statusCode >= 400) {
      throw VendorOfferingsApiException(EventConfigApiException(res.statusCode, res.body).toString());
    }
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConfig(String vendorId) async {
    final res = await _http.get(_u('vendors/$vendorId/offerings-config'), headers: await _headers());
    return _json(res);
  }

  Future<void> putCapabilities(String vendorId, List<String> capabilityKeys) async {
    final res = await _http.put(
      _u('vendors/$vendorId/business-capabilities'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'capabilityKeys': capabilityKeys}),
    );
    await _json(res);
  }

  Future<void> putCategories(String vendorId, List<String> categoryIds) async {
    final res = await _http.put(
      _u('vendors/$vendorId/offering-categories'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'categoryIds': categoryIds}),
    );
    await _json(res);
  }

  Future<List<Map<String, dynamic>>> listServices(String vendorId) async {
    final res = await _http.get(_u('vendors/$vendorId/offering-services'), headers: await _headers());
    final body = await _json(res);
    return (body['items'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createService({
    required String vendorId,
    required String serviceName,
    required String categoryId,
    String? description,
  }) async {
    final res = await _http.post(
      _u('vendors/$vendorId/services'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'serviceName': serviceName,
        'categoryId': categoryId,
        if (description != null) 'description': description,
      }),
    );
    return _json(res);
  }

  Future<Map<String, dynamic>> getBlueprint(String vendorId, String serviceId) async {
    final res = await _http.get(
      _u('vendors/$vendorId/services/$serviceId/blueprint'),
      headers: await _headers(),
    );
    return _json(res);
  }

  Future<Map<String, dynamic>> putBlueprint({
    required String vendorId,
    required String serviceId,
    required List<Map<String, dynamic>> resources,
  }) async {
    final res = await _http.put(
      _u('vendors/$vendorId/services/$serviceId/blueprint'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'resources': resources}),
    );
    return _json(res);
  }

  Future<List<Map<String, dynamic>>> listPackages(String vendorId) async {
    final res = await _http.get(_u('vendors/$vendorId/rental-packages'), headers: await _headers());
    final body = await _json(res);
    return (body['items'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> upsertPackage({
    required String vendorId,
    String? id,
    required String name,
    required String categorySlug,
    String? description,
    int rentalFeeMinor = 0,
    int depositMinor = 0,
    required List<Map<String, dynamic>> components,
  }) async {
    final res = await _http.post(
      _u('vendors/$vendorId/rental-packages'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        if (id != null) 'id': id,
        'name': name,
        'categorySlug': categorySlug,
        'description': description ?? '',
        'rentalFeeMinor': rentalFeeMinor,
        'depositMinor': depositMinor,
        'components': components,
      }),
    );
    return _json(res);
  }
}
