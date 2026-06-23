import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owanbe_api_auth.dart';

class VendorsApiException implements Exception {
  VendorsApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'VendorsApiException($code): $message';
}

class MarketplaceVendor {
  const MarketplaceVendor({
    required this.id,
    required this.businessName,
    this.city,
    this.status = 'active',
    this.ratingAverage,
    this.slug,
    this.description,
    this.reviewCount,
    this.priceFromMinor,
    this.currency,
    this.countryCode,
  });

  final String id;
  final String businessName;
  final String? city;
  final String status;
  final double? ratingAverage;
  final String? slug;
  final String? description;
  final int? reviewCount;
  final int? priceFromMinor;
  final String? currency;
  final String? countryCode;

  bool get isVerified => status == 'active';

  String get categoryLabel => _categoryFromSlug(slug ?? businessName);

  static String _categoryFromSlug(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('cater')) return 'Catering';
    if (lower.contains('dj') || lower.contains('music')) return 'DJ & Music';
    if (lower.contains('photo')) return 'Photography';
    if (lower.contains('decor')) return 'Décor';
    if (lower.contains('cake')) return 'Cakes';
    return 'Celebration vendor';
  }
}

MarketplaceVendor mapMarketplaceVendor(Map<String, dynamic> json) {
  return MarketplaceVendor(
    id: (json['id'] ?? '').toString(),
    businessName: (json['businessName'] ?? json['business_name'] ?? '').toString(),
    city: json['city']?.toString(),
    status: (json['status'] ?? 'active').toString(),
    ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
    slug: json['slug']?.toString(),
    description: json['description']?.toString(),
    reviewCount: (json['reviewCount'] as num?)?.toInt(),
    priceFromMinor: (json['priceFromMinor'] as num?)?.toInt(),
    currency: json['currency']?.toString() ?? 'NGN',
    countryCode: json['countryCode']?.toString(),
  );
}

class VendorsApi {
  VendorsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base => OwanbeApiAuth.resolveApiBase();
  String get _tenantId => OwanbeApiAuth.resolveTenantId(devTenantId);

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw VendorsApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is VendorsApiException) rethrow;
      throw VendorsApiException(code: 'HTTP_${res.statusCode}', message: res.body);
    }
  }

  Future<List<MarketplaceVendor>> listCatalog({String? query, String? city}) async {
    final res = await _http.get(
      _u('vendors', {
        if (query != null && query.isNotEmpty) 'q': query,
        if (city != null && city.isNotEmpty) 'city': city,
      }),
      headers: OwanbeApiAuth.publicHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => mapMarketplaceVendor(e as Map<String, dynamic>))
        .toList();
  }

  Future<MarketplaceVendor?> getVendor(String vendorId) async {
    final items = await listCatalog();
    for (final item in items) {
      if (item.id == vendorId) return item;
    }
    return null;
  }
}
