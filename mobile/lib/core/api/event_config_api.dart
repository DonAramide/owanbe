import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/models/event_access_mode.dart';
import 'owanbe_api_auth.dart';

class EventCategoryConfig {
  const EventCategoryConfig({
    required this.id,
    required this.slug,
    required this.label,
    required this.iconKey,
    required this.accessMode,
    this.description = '',
  });

  final String id;
  final String slug;
  final String label;
  final String iconKey;
  final EventAccessMode accessMode;
  final String description;

  static List<EventCategoryConfig> get fallbackDefaults => [
        const EventCategoryConfig(
          id: 'wedding',
          slug: 'wedding',
          label: 'Wedding',
          iconKey: 'heart',
          accessMode: EventAccessMode.privateInvitation,
        ),
        const EventCategoryConfig(
          id: 'birthday',
          slug: 'birthday',
          label: 'Birthday',
          iconKey: 'cake',
          accessMode: EventAccessMode.privateInvitation,
        ),
        const EventCategoryConfig(
          id: 'naming-ceremony',
          slug: 'naming-ceremony',
          label: 'Naming Ceremony',
          iconKey: 'child',
          accessMode: EventAccessMode.privateInvitation,
        ),
        const EventCategoryConfig(
          id: 'corporate',
          slug: 'corporate',
          label: 'Corporate Event',
          iconKey: 'business',
          accessMode: EventAccessMode.privateInvitation,
        ),
        const EventCategoryConfig(
          id: 'festival',
          slug: 'festival',
          label: 'Festival',
          iconKey: 'festival',
          accessMode: EventAccessMode.publicTicketed,
        ),
        const EventCategoryConfig(
          id: 'conference',
          slug: 'conference',
          label: 'Conference',
          iconKey: 'groups',
          accessMode: EventAccessMode.publicTicketed,
        ),
        const EventCategoryConfig(
          id: 'other',
          slug: 'other',
          label: 'Other',
          iconKey: 'celebration',
          accessMode: EventAccessMode.privateInvitation,
        ),
      ];

  factory EventCategoryConfig.fromJson(Map<String, dynamic> json) {
    return EventCategoryConfig(
      id: (json['id'] ?? json['slug'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      iconKey: (json['iconKey'] ?? 'celebration').toString(),
      accessMode: EventAccessModeX.fromApi((json['accessMode'] ?? '').toString()),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class EventTagConfig {
  const EventTagConfig({required this.id, required this.slug, required this.label});

  final String id;
  final String slug;
  final String label;

  static List<EventTagConfig> get fallbackDefaults => const [
        EventTagConfig(id: 'outdoor', slug: 'outdoor', label: 'outdoor'),
        EventTagConfig(id: 'family', slug: 'family', label: 'family'),
        EventTagConfig(id: 'live-music', slug: 'live-music', label: 'live music'),
      ];

  factory EventTagConfig.fromJson(Map<String, dynamic> json) {
    return EventTagConfig(
      id: (json['id'] ?? json['slug'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

class VendorCategoryConfig {
  const VendorCategoryConfig({
    required this.id,
    required this.slug,
    required this.label,
    this.iconKey = 'storefront',
  });

  final String id;
  final String slug;
  final String label;
  final String iconKey;

  static List<VendorCategoryConfig> get fallbackDefaults => const [
        VendorCategoryConfig(id: 'venue', slug: 'venue', label: 'Venue', iconKey: 'apartment'),
        VendorCategoryConfig(id: 'decorator', slug: 'decorator', label: 'Decorator', iconKey: 'brush'),
        VendorCategoryConfig(id: 'photographer', slug: 'photographer', label: 'Photographer', iconKey: 'photo_camera'),
        VendorCategoryConfig(id: 'dj', slug: 'dj', label: 'DJ', iconKey: 'music_note'),
        VendorCategoryConfig(id: 'mc', slug: 'mc', label: 'MC', iconKey: 'mic'),
        VendorCategoryConfig(id: 'security', slug: 'security', label: 'Security', iconKey: 'shield'),
        VendorCategoryConfig(id: 'cake', slug: 'cake', label: 'Cake', iconKey: 'cake'),
        VendorCategoryConfig(id: 'drinks', slug: 'drinks', label: 'Drinks', iconKey: 'local_bar'),
        VendorCategoryConfig(id: 'ushers', slug: 'ushers', label: 'Ushers', iconKey: 'groups'),
        VendorCategoryConfig(id: 'live-band', slug: 'live-band', label: 'Live Band', iconKey: 'nightlife'),
        VendorCategoryConfig(id: 'catering', slug: 'catering', label: 'Catering', iconKey: 'restaurant'),
        VendorCategoryConfig(id: 'fashion-attire', slug: 'fashion-attire', label: 'Fashion & Attire', iconKey: 'checkroom'),
        VendorCategoryConfig(id: 'aso-ebi', slug: 'aso-ebi', label: 'Aso-Ebi', iconKey: 'style'),
        VendorCategoryConfig(id: 'traditional-wear', slug: 'traditional-wear', label: 'Traditional Wear', iconKey: 'dry_cleaning'),
        VendorCategoryConfig(id: 'wedding-gowns', slug: 'wedding-gowns', label: 'Wedding Gowns', iconKey: 'favorite_border'),
        VendorCategoryConfig(id: 'bridesmaid-dresses', slug: 'bridesmaid-dresses', label: 'Bridesmaid Dresses', iconKey: 'groups'),
        VendorCategoryConfig(id: 'suits', slug: 'suits', label: 'Suits', iconKey: 'business_center'),
        VendorCategoryConfig(id: 'gele', slug: 'gele', label: 'Gele', iconKey: 'face_retouching_natural'),
        VendorCategoryConfig(id: 'fashion-accessories', slug: 'fashion-accessories', label: 'Accessories', iconKey: 'diamond'),
        VendorCategoryConfig(id: 'tailoring', slug: 'tailoring', label: 'Tailoring', iconKey: 'content_cut'),
      ];

  factory VendorCategoryConfig.fromJson(Map<String, dynamic> json) {
    return VendorCategoryConfig(
      id: (json['id'] ?? json['slug'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      iconKey: (json['iconKey'] ?? 'storefront').toString(),
    );
  }
}

class EventTemplateConfig {
  const EventTemplateConfig({
    required this.id,
    required this.slug,
    required this.label,
    required this.accessMode,
    this.categorySlug,
    this.vendorHints = const [],
  });

  final String id;
  final String slug;
  final String label;
  final String? categorySlug;
  final EventAccessMode accessMode;
  final List<String> vendorHints;

  factory EventTemplateConfig.fromJson(Map<String, dynamic> json) {
    final hints = (json['vendorHints'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    return EventTemplateConfig(
      id: (json['id'] ?? json['slug'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      categorySlug: json['categorySlug']?.toString(),
      accessMode: EventAccessModeX.fromApi((json['accessMode'] ?? '').toString()),
      vendorHints: hints,
    );
  }
}

class EventConfigApi {
  EventConfigApi(this._http);

  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';

  String get _base => OwanbeApiAuth.resolveApiBase();

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Future<Map<String, String>> _headers() async {
    return OwanbeApiAuth.authorizedHeaders(tenantId: OwanbeApiAuth.resolveTenantId(devTenantId));
  }

  Future<List<EventCategoryConfig>> listCategories() async {
    final res = await _http.get(_u('event-config/categories'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => EventCategoryConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventTagConfig>> listTags() async {
    final res = await _http.get(_u('event-config/tags'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => EventTagConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventTemplateConfig>> listTemplates() async {
    final res = await _http.get(_u('event-config/templates'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => EventTemplateConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VendorCategoryConfig>> listVendorCategories() async {
    final res = await _http.get(_u('event-config/vendor-categories'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => VendorCategoryConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class EventConfigApiException implements Exception {
  EventConfigApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'EventConfigApiException($statusCode)';
}
