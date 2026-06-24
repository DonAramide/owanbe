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
    this.priceToMinor,
    this.currency,
    this.countryCode,
    this.imageUrl,
    this.videoPreviewUrl,
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
  final int? priceToMinor;
  final String? currency;
  final String? countryCode;
  final String? imageUrl;
  final String? videoPreviewUrl;

  bool get isVerified => status == 'active';

  String get categoryLabel => _categoryFromSlug(slug ?? businessName);

  /// Fashion & Attire subcategory when applicable.
  String? get fashionSubcategory => _fashionSubcategoryFromSlug(slug ?? businessName);

  /// Rentals & Event Equipment subcategory when applicable.
  String? get rentalSubcategory => _rentalSubcategoryFromSlug(slug ?? businessName);

  bool get isFashionAttireVendor =>
      categoryLabel == 'Fashion & Attire' || fashionSubcategory != null;

  bool get isRentalEquipmentVendor =>
      categoryLabel == 'Rentals & Event Equipment' || rentalSubcategory != null;

  static String _categoryFromSlug(String raw) {
    final rental = _rentalSubcategoryFromSlug(raw);
    if (rental != null) return rental == 'Rentals & Event Equipment' ? rental : 'Rentals & Event Equipment';
    final fashion = _fashionSubcategoryFromSlug(raw);
    if (fashion != null) return fashion == 'Fashion & Attire' ? fashion : 'Fashion & Attire';
    final lower = raw.toLowerCase();
    if (lower.contains('venue') || lower.contains('hall') || lower.contains('ballroom')) return 'Venue';
    if (lower.contains('cater') || lower.contains('jollof') || lower.contains('food')) return 'Catering';
    if (lower.contains('dj') || lower.contains('music')) return 'DJ';
    if (lower.contains('photo')) return 'Photographer';
    if (lower.contains('decor') || lower.contains('décor')) return 'Decorator';
    if (lower.contains('cake')) return 'Cake';
    if (lower.contains('drink') || lower.contains('bar')) return 'Drinks';
    if (lower.contains('mc') || lower.contains('host')) return 'MC';
    if (lower.contains('security') || lower.contains('bouncer')) return 'Security';
    if (lower.contains('usher')) return 'Ushers';
    if (lower.contains('band') || lower.contains('live')) return 'Live Band';
    if (lower.contains('floral')) return 'Florist';
    return 'Celebration vendor';
  }

  static String? _fashionSubcategoryFromSlug(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('aso') && lower.contains('ebi')) return 'Aso-Ebi';
    if (lower.contains('aso-ebi') || lower.contains('asoebi')) return 'Aso-Ebi';
    if (lower.contains('traditional')) return 'Traditional Wear';
    if (lower.contains('wedding') && lower.contains('gown')) return 'Wedding Gowns';
    if (lower.contains('bridesmaid')) return 'Bridesmaid Dresses';
    if (lower.contains('suit')) return 'Suits';
    if (lower.contains('gele')) return 'Gele';
    if (lower.contains('accessor')) return 'Accessories';
    if (lower.contains('tailor')) return 'Tailoring';
    if (lower.contains('fabric') || lower.contains('attire') || lower.contains('fashion')) {
      return 'Fashion & Attire';
    }
    return null;
  }

  static String? _rentalSubcategoryFromSlug(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('chair')) return 'Chairs';
    if (lower.contains('table')) return 'Tables';
    if (lower.contains('canop')) return 'Canopies';
    if (lower.contains('tent')) return 'Tents';
    if (lower.contains('stage')) return 'Stage Platforms';
    if (lower.contains('led') || lower.contains('screen')) return 'LED Screens';
    if (lower.contains('sound') || lower.contains('speaker')) return 'Sound Systems';
    if (lower.contains('light')) return 'Lighting Systems';
    if (lower.contains('generator')) return 'Generators';
    if (lower.contains('toilet')) return 'Mobile Toilets';
    if (lower.contains('fan')) return 'Cooling Fans';
    if (lower.contains('air-condition') || lower.contains('ac-rental')) return 'Air Conditioners';
    if (lower.contains('dance')) return 'Dance Floors';
    if (lower.contains('cutlery') || lower.contains('crockery')) return 'Cutlery & Crockery';
    if (lower.contains('throne')) return 'Thrones & VIP Seating';
    if (lower.contains('backdrop')) return 'Backdrops';
    if (lower.contains('photo-booth') || lower.contains('photobooth')) return 'Photo Booths';
    if (lower.contains('rental') || lower.contains('equipment')) return 'Rentals & Event Equipment';
    return null;
  }

  bool matchesService(String serviceLabel) {
    final needle = serviceLabel.toLowerCase();
    final hay = '${slug ?? ''} ${businessName.toLowerCase()} ${categoryLabel.toLowerCase()} '
        '${fashionSubcategory?.toLowerCase() ?? ''} ${rentalSubcategory?.toLowerCase() ?? ''}';
    if (hay.contains(needle)) return true;
    if (needle == 'fashion & attire' && isFashionAttireVendor) return true;
    if (needle == 'rentals & event equipment' && isRentalEquipmentVendor) return true;
    if (rentalSubcategory != null && rentalSubcategory!.toLowerCase() == needle) return true;
    if (fashionSubcategory != null && fashionSubcategory!.toLowerCase() == needle) return true;
    return categoryLabel.toLowerCase() == needle ||
        categoryLabel.toLowerCase().contains(needle);
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
    priceToMinor: (json['priceToMinor'] as num?)?.toInt(),
    currency: json['currency']?.toString() ?? 'NGN',
    countryCode: json['countryCode']?.toString(),
    imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
    videoPreviewUrl: json['videoPreviewUrl']?.toString() ?? json['video_preview_url']?.toString(),
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
