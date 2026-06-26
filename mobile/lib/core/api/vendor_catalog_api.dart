import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/vendor/models/vendor_models.dart';
import 'events_api.dart';
import 'owanbe_api_auth.dart';

class VendorCatalogApi {
  VendorCatalogApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId(EventsApi.devTenantId);

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw EventsApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is EventsApiException) rethrow;
      throw EventsApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<List<VendorCatalogItem>> listPackages() async {
    final res = await _http.get(
      _u('vendor/packages'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => mapVendorCatalogItem(e as Map<String, dynamic>))
        .toList();
  }

  Future<VendorCatalogItem> createPackage({
    required String name,
    required String description,
    required String category,
    required int priceMinor,
    String currency = 'NGN',
  }) async {
    final res = await _http.post(
      _u('vendor/packages'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({
        'name': name,
        'description': description,
        'category': category,
        'priceMinor': priceMinor,
        'currency': currency,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return mapVendorCatalogItem(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorCatalogItem> setActive(String packageId, bool isActive) async {
    final res = await _http.patch(
      _u('vendor/packages/$packageId'),
      headers: await OwanbeApiAuth.authorizedHeaders(tenantId: _tenantId),
      body: jsonEncode({'isActive': isActive}),
    );
    if (res.statusCode >= 400) _throw(res);
    return mapVendorCatalogItem(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

VendorCatalogItem mapVendorCatalogItem(Map<String, dynamic> json) {
  final metadata = json['metadata'];
  String category = 'General';
  if (metadata is Map<String, dynamic> && metadata['category'] != null) {
    category = metadata['category'].toString();
  }
  return VendorCatalogItem(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    category: category,
    priceMinor: (json['unitAmountMinor'] as num?)?.toInt() ?? 0,
    currency: (json['currency'] ?? 'NGN').toString(),
    status: json['isActive'] == true ? VendorCatalogStatus.active : VendorCatalogStatus.paused,
  );
}
