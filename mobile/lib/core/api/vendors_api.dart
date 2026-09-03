import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owambe_api_auth.dart';

class VendorsApiException implements Exception {
  VendorsApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() {
    if (code.toUpperCase() == 'INTERNAL' || message.toLowerCase().contains('internal server error')) {
      return 'Internal Server Error';
    }
    return message;
  }
}

/// First-class bookable offering from `vendor_services` (+ optional package price).
class ServiceCapability {
  const ServiceCapability({required this.key, required this.label, this.provided = true, this.enabled = true});

  final String key;
  final String label;
  final bool provided;
  final bool enabled;

  factory ServiceCapability.fromJson(Map<String, dynamic> json) {
    return ServiceCapability(
      key: (json['key'] ?? json['id'] ?? '').toString(),
      label: (json['label'] ?? json['name'] ?? json['key'] ?? '').toString(),
      provided: json['provided'] == true,
      enabled: json['enabled'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        if (provided) 'provided': provided,
      };
}

class BookedRange {
  const BookedRange({required this.startsAt, required this.endsAt, this.kind});

  final DateTime startsAt;
  final DateTime endsAt;
  final String? kind;

  factory BookedRange.fromJson(Map<String, dynamic> json) {
    return BookedRange(
      startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
      endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      kind: json['kind']?.toString(),
    );
  }
}

String formatServiceAvailability(String? status) {
  switch ((status ?? '').toUpperCase()) {
    case 'BOOKED':
      return 'BOOKED';
    case 'CONFLICTING':
      return 'CONFLICTING';
    case 'UNAVAILABLE':
      return 'UNAVAILABLE';
    case 'AVAILABLE':
      return 'AVAILABLE';
    default:
      return status ?? '';
  }
}

/// True when the organizer should not send a new request for this window.
bool serviceWindowBlocksNewRequest(String? status) {
  final s = (status ?? '').toUpperCase();
  return s == 'BOOKED' || s == 'CONFLICTING' || s == 'UNAVAILABLE';
}

/// True when the service offer itself is not bookable (inactive / missing).
bool serviceOfferInactive(String? offerStatus) {
  final s = (offerStatus ?? '').toLowerCase().trim();
  return s.isNotEmpty && s != 'active';
}

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _longMonths = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String formatClock(DateTime d) {
  final local = d.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String formatLongDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_shortMonths[local.month - 1]} ${local.year}';
}

String formatTimeRange(DateTime start, DateTime? end) {
  if (end == null) return formatClock(start);
  return '${formatClock(start)} – ${formatClock(end)}';
}

/// Date plus clock window. Display-only — does not classify availability.
String formatDateTimeWindow(DateTime start, DateTime? end) {
  if (end == null) return '${formatLongDate(start)} · ${formatClock(start)}';
  final a = start.toLocal();
  final b = end.toLocal();
  if (a.year == b.year && a.month == b.month && a.day == b.day) {
    return '${formatLongDate(a)} · ${formatTimeRange(a, b)}';
  }
  return '${formatLongDate(a)} ${formatClock(a)} – ${formatLongDate(b)} ${formatClock(b)}';
}

String formatMonthHeading(DateTime d) {
  final local = d.toLocal();
  return '${_longMonths[local.month - 1]} ${local.year}';
}

String formatDayHeading(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_longMonths[local.month - 1]}';
}

String formatDateWindow(DateTime start, DateTime? end) {
  String fmt(DateTime d) {
    final local = d.toLocal();
    return '${local.day} ${_shortMonths[local.month - 1]}';
  }

  if (end == null) return fmt(start);
  final a = start.toLocal();
  final b = end.toLocal();
  if (a.year == b.year && a.month == b.month && a.day == b.day) return fmt(a);
  return '${fmt(a)}–${fmt(b)}';
}

/// Presentation of server CONFLICTING status + bookedRanges. No overlap math.
String? availabilityConflictExplanation(String? status, List<BookedRange> ranges) {
  if ((status ?? '').toUpperCase() != 'CONFLICTING' || ranges.isEmpty) return null;
  final first = ranges.first;
  return 'Vendor is already booked from ${formatTimeRange(first.startsAt, first.endsAt)}.';
}

class MarketplaceVendorService {
  const MarketplaceVendorService({
    required this.id,
    required this.serviceKey,
    required this.serviceName,
    this.serviceCode,
    this.description,
    this.priceFromMinor,
    this.currency,
    this.offerStatus = 'active',
    this.availabilityStatus,
    this.bookedRanges = const [],
    this.unavailableRanges = const [],
    this.capabilities = const [],
  });

  final String id;
  final String serviceKey;
  final String serviceName;
  final String? serviceCode;
  final String? description;
  final int? priceFromMinor;
  final String? currency;
  final String offerStatus;
  final String? availabilityStatus;
  final List<BookedRange> bookedRanges;
  final List<BookedRange> unavailableRanges;
  final List<ServiceCapability> capabilities;

  factory MarketplaceVendorService.fromJson(Map<String, dynamic> json) {
    return MarketplaceVendorService(
      id: (json['id'] ?? '').toString(),
      serviceKey: (json['serviceKey'] ?? json['service_key'] ?? '').toString(),
      serviceName: (json['serviceName'] ?? json['service_name'] ?? '').toString(),
      serviceCode: json['serviceCode']?.toString() ?? json['service_code']?.toString(),
      description: json['description']?.toString(),
      priceFromMinor: (json['priceFromMinor'] as num?)?.toInt(),
      currency: json['currency']?.toString() ?? 'NGN',
      offerStatus: (json['offerStatus'] ?? json['status'] ?? 'active').toString(),
      availabilityStatus: json['availabilityStatus']?.toString(),
      bookedRanges: (json['bookedRanges'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => BookedRange.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      unavailableRanges: (json['unavailableRanges'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => BookedRange.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => ServiceCapability.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.key.isNotEmpty)
          .toList(),
    );
  }

  bool matchesLabel(String label) {
    final needle = label.toLowerCase().trim();
    if (needle.isEmpty || needle == 'all') return false;
    final name = serviceName.toLowerCase();
    final key = serviceKey.toLowerCase();
    final keyNeedle = needle.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    if (name == needle ||
        name.contains(needle) ||
        needle.contains(name) ||
        key == keyNeedle ||
        key.contains(keyNeedle) ||
        keyNeedle.contains(key)) {
      return true;
    }
    for (final c in capabilities) {
      if (c.label.toLowerCase().contains(needle) || c.key.toLowerCase().contains(keyNeedle)) {
        return true;
      }
    }
    return false;
  }
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
    this.category,
    this.servicesOffered = const [],
    this.services = const [],
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
  final String? category;
  final List<String> servicesOffered;
  final List<MarketplaceVendorService> services;

  MarketplaceVendor copyWith({
    List<String>? servicesOffered,
    List<MarketplaceVendorService>? services,
    String? description,
    double? ratingAverage,
    int? reviewCount,
    int? priceFromMinor,
    int? priceToMinor,
    String? currency,
    String? countryCode,
    String? imageUrl,
    String? videoPreviewUrl,
    String? category,
  }) {
    return MarketplaceVendor(
      id: id,
      businessName: businessName,
      city: city,
      status: status,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      slug: slug,
      description: description ?? this.description,
      reviewCount: reviewCount ?? this.reviewCount,
      priceFromMinor: priceFromMinor ?? this.priceFromMinor,
      priceToMinor: priceToMinor ?? this.priceToMinor,
      currency: currency ?? this.currency,
      countryCode: countryCode ?? this.countryCode,
      imageUrl: imageUrl ?? this.imageUrl,
      videoPreviewUrl: videoPreviewUrl ?? this.videoPreviewUrl,
      category: category ?? this.category,
      servicesOffered: servicesOffered ?? this.servicesOffered,
      services: services ?? this.services,
    );
  }

  bool get isVerified => status == 'active';

  String get categoryLabel {
    if (category != null && category!.trim().isNotEmpty) {
      final parts = category!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
      if (parts.isNotEmpty) return parts.first;
    }
    return _categoryFromSlug(slug ?? businessName);
  }

  String? get fashionSubcategory => _fashionSubcategoryFromSlug(slug ?? businessName);

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
    final needle = serviceLabel.toLowerCase().trim();
    if (needle.isEmpty || needle == 'all') return true;

    for (final s in services) {
      if (s.matchesLabel(serviceLabel)) return true;
    }

    for (final s in servicesOffered) {
      if (s.toLowerCase().contains(needle) || needle.contains(s.toLowerCase())) return true;
    }
    if (category != null) {
      for (final part in category!.split(',')) {
        final c = part.trim().toLowerCase();
        if (c.isNotEmpty && (c.contains(needle) || needle.contains(c))) return true;
      }
    }

    final aliases = <String>{needle};
    if (needle.contains('photo')) {
      aliases.addAll(['photo', 'photography', 'photographer']);
    }
    if (needle == 'dj' || needle.contains('entertainment') || needle.contains('music')) {
      aliases.addAll(['dj', 'entertainment', 'music', 'band']);
    }
    if (needle.contains('cater') || needle.contains('food') || needle.contains('jollof')) {
      aliases.addAll(['cater', 'catering', 'food', 'jollof']);
    }
    if (needle.contains('decor') || needle.contains('décor') || needle.contains('styl')) {
      aliases.addAll(['decor', 'décor', 'decorator', 'styling']);
    }
    if (needle == 'mc' || needle.contains('officiant') || needle.contains('host')) {
      aliases.addAll(['mc', 'officiant', 'host']);
    }

    final hay = '${slug ?? ''} ${businessName.toLowerCase()} ${categoryLabel.toLowerCase()} '
        '${fashionSubcategory?.toLowerCase() ?? ''} ${rentalSubcategory?.toLowerCase() ?? ''} '
        '${servicesOffered.join(' ').toLowerCase()}';

    for (final a in aliases) {
      if (hay.contains(a)) return true;
      if (categoryLabel.toLowerCase() == a) return true;
    }
    if (needle == 'fashion & attire' && isFashionAttireVendor) return true;
    if (needle == 'rentals & event equipment' && isRentalEquipmentVendor) return true;
    if (rentalSubcategory != null && rentalSubcategory!.toLowerCase() == needle) return true;
    if (fashionSubcategory != null && fashionSubcategory!.toLowerCase() == needle) return true;
    return categoryLabel.toLowerCase().contains(needle);
  }

  bool matchesSearchQuery(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    // Public vendor marketplace fields only — never slug/account-holder identity.
    if (businessName.toLowerCase().contains(q)) return true;
    if (categoryLabel.toLowerCase().contains(q)) return true;
    if ((city ?? '').toLowerCase().contains(q)) return true;
    if ((countryCode ?? '').toLowerCase().contains(q)) return true;
    if ((description ?? '').toLowerCase().contains(q)) return true;
    if (id.toLowerCase().contains(q)) return true;
    if ((category ?? '').toLowerCase().contains(q)) return true;
    if ((fashionSubcategory ?? '').toLowerCase().contains(q)) return true;
    if ((rentalSubcategory ?? '').toLowerCase().contains(q)) return true;
    for (final s in servicesOffered) {
      if (s.toLowerCase().contains(q)) return true;
    }
    for (final s in services) {
      if (s.serviceName.toLowerCase().contains(q)) return true;
      if (s.serviceKey.toLowerCase().contains(q)) return true;
      if ((s.serviceCode ?? '').toLowerCase().contains(q)) return true;
      if ((s.description ?? '').toLowerCase().contains(q)) return true;
      for (final c in s.capabilities) {
        if (c.label.toLowerCase().contains(q) || c.key.toLowerCase().contains(q)) return true;
      }
    }
    return false;
  }
}

MarketplaceVendor mapMarketplaceVendor(Map<String, dynamic> json) {
  final offered = <String>[];
  final raw = json['servicesOffered'] ?? json['services_offered'];
  if (raw is List) {
    for (final e in raw) {
      final s = e.toString().trim();
      if (s.isNotEmpty) offered.add(s);
    }
  }
  final services = <MarketplaceVendorService>[];
  final servicesRaw = json['services'];
  if (servicesRaw is List) {
    for (final e in servicesRaw) {
      if (e is Map<String, dynamic>) {
        final s = MarketplaceVendorService.fromJson(e);
        if (s.id.isNotEmpty && s.serviceName.isNotEmpty) services.add(s);
      } else if (e is Map) {
        final s = MarketplaceVendorService.fromJson(Map<String, dynamic>.from(e));
        if (s.id.isNotEmpty && s.serviceName.isNotEmpty) services.add(s);
      }
    }
  }
  if (offered.isEmpty && services.isNotEmpty) {
    offered.addAll(services.map((s) => s.serviceName));
  }
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
    category: json['category']?.toString(),
    servicesOffered: offered,
    services: services,
  );
}

class VendorsApi {
  VendorsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId(devTenantId);

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

  Future<List<MarketplaceVendor>> listCatalog({
    String? query,
    String? city,
    String? service,
  }) async {
    final res = await _http.get(
      _u('vendors', {
        if (query != null && query.isNotEmpty) 'q': query,
        if (city != null && city.isNotEmpty) 'city': city,
        if (service != null && service.isNotEmpty && service != 'All') 'service': service,
      }),
      headers: OwambeApiAuth.publicHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => mapMarketplaceVendor(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MarketplaceVendorService>> listVendorServices(
    String vendorId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _http.get(
      _u('vendors/$vendorId/services', {
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      }),
      headers: OwambeApiAuth.publicHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map((e) => MarketplaceVendorService.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty && s.serviceName.isNotEmpty)
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
