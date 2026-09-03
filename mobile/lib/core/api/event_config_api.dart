import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/models/event_access_mode.dart';
import 'owambe_api_auth.dart';

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
    this.isActive = true,
    this.offeringKind = 'unclassified',
    this.parentId,
    this.capabilities = const [],
  });

  final String id;
  final String slug;
  final String label;
  final String iconKey;
  final bool isActive;
  final String offeringKind;
  final String? parentId;
  final List<VendorCategoryCapability> capabilities;

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
      isActive: json['isActive'] != false,
      offeringKind: (json['offeringKind'] ?? json['offering_kind'] ?? 'unclassified').toString(),
      parentId: json['parentId']?.toString() ?? json['parent_id']?.toString(),
      capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => VendorCategoryCapability.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.key.isNotEmpty)
          .toList(),
    );
  }
}

class VendorBusinessCapabilityConfig {
  const VendorBusinessCapabilityConfig({
    required this.id,
    required this.capabilityKey,
    required this.label,
    this.description = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String capabilityKey;
  final String label;
  final String description;
  final bool isActive;
  final int sortOrder;

  factory VendorBusinessCapabilityConfig.fromJson(Map<String, dynamic> json) {
    return VendorBusinessCapabilityConfig(
      id: (json['id'] ?? '').toString(),
      capabilityKey: (json['capabilityKey'] ?? json['capability_key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isActive: json['isActive'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class VendorResourceCatalogItem {
  const VendorResourceCatalogItem({
    required this.id,
    required this.slug,
    required this.label,
    this.description = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String slug;
  final String label;
  final String description;
  final bool isActive;
  final int sortOrder;

  factory VendorResourceCatalogItem.fromJson(Map<String, dynamic> json) {
    return VendorResourceCatalogItem(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isActive: json['isActive'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class VendorCategoryCapability {
  const VendorCategoryCapability({
    required this.key,
    required this.label,
    this.enabled = true,
    this.tier = 'core',
  });

  final String key;
  final String label;
  final bool enabled;
  /// Admin-owned: `core` | `optional`.
  final String tier;

  bool get isCore => tier != 'optional';
  bool get isOptional => tier == 'optional';

  factory VendorCategoryCapability.fromJson(Map<String, dynamic> json) {
    final rawTier = (json['tier'] ?? json['kind'] ?? 'core').toString().toLowerCase();
    final tier = (rawTier == 'optional' || rawTier == 'additional' || rawTier == 'extra')
        ? 'optional'
        : 'core';
    return VendorCategoryCapability(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? json['key'] ?? '').toString(),
      enabled: json['enabled'] != false,
      tier: tier,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'enabled': enabled,
        'tier': tier,
      };

  VendorCategoryCapability copyWith({bool? enabled, String? tier, String? label}) {
    return VendorCategoryCapability(
      key: key,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      tier: tier ?? this.tier,
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

  String get _base => OwambeApiAuth.resolveApiBase();

  Uri _u(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p');
  }

  Future<Map<String, String>> _headers() async {
    return OwambeApiAuth.authorizedHeaders(tenantId: OwambeApiAuth.resolveTenantId(devTenantId));
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

  Future<List<VendorCategoryConfig>> adminListVendorCategories() async {
    final res = await _http.get(_u('admin/settings/vendor-categories'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => VendorCategoryConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> adminSaveVendorCategoryCapabilities({
    required String id,
    required List<VendorCategoryCapability> capabilities,
    bool? isActive,
  }) async {
    final res = await _http.post(
      _u('admin/settings/vendor-categories'),
      headers: {
        ...await _headers(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id': id,
        'capabilities': [
          for (final c in capabilities)
            {'key': c.key, 'label': c.label, 'enabled': c.enabled, 'tier': c.tier},
        ],
        if (isActive != null) 'isActive': isActive,
      }),
    );
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
  }

  Future<List<VendorBusinessCapabilityConfig>> adminListBusinessCapabilities() async {
    final res = await _http.get(_u('admin/settings/vendor-business-capabilities'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => VendorBusinessCapabilityConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VendorBusinessCapabilityConfig> adminPatchBusinessCapability({
    required String capabilityKey,
    required bool isActive,
    String? label,
    String? description,
  }) async {
    final res = await _http.post(
      _u('admin/settings/vendor-business-capabilities'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'capabilityKey': capabilityKey,
        'isActive': isActive,
        if (label != null) 'label': label,
        if (description != null) 'description': description,
      }),
    );
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    return VendorBusinessCapabilityConfig.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<VendorCategoryConfig>> adminListOfferingCategories({String? kind}) async {
    final q = kind == null || kind.isEmpty ? '' : '?kind=${Uri.encodeQueryComponent(kind)}';
    final res = await _http.get(_u('admin/settings/vendor-offering-categories$q'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => VendorCategoryConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VendorCategoryConfig> adminUpsertOfferingCategory({
    String? id,
    required String label,
    String? slug,
    required String offeringKind,
    bool isActive = true,
    String? iconKey,
    String? parentId,
    int? sortOrder,
  }) async {
    final res = await _http.post(
      _u('admin/settings/vendor-offering-categories'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        if (id != null) 'id': id,
        'label': label,
        if (slug != null) 'slug': slug,
        'offeringKind': offeringKind,
        'isActive': isActive,
        if (iconKey != null) 'iconKey': iconKey,
        if (parentId != null) 'parentId': parentId,
        if (sortOrder != null) 'sortOrder': sortOrder,
      }),
    );
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    return VendorCategoryConfig.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<VendorResourceCatalogItem>> adminListResourceCatalog() async {
    final res = await _http.get(_u('admin/settings/vendor-resource-catalog'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => VendorResourceCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VendorResourceCatalogItem> adminUpsertResource({
    String? id,
    required String label,
    String? slug,
    String? description,
    bool isActive = true,
    int? sortOrder,
  }) async {
    final res = await _http.post(
      _u('admin/settings/vendor-resource-catalog'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        if (id != null) 'id': id,
        'label': label,
        if (slug != null) 'slug': slug,
        if (description != null) 'description': description,
        'isActive': isActive,
        if (sortOrder != null) 'sortOrder': sortOrder,
      }),
    );
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    return VendorResourceCatalogItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<VendorBusinessCapabilityConfig>> listPublicBusinessCapabilities() async {
    final res = await _http.get(_u('event-config/vendor-business-capabilities'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => VendorBusinessCapabilityConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VendorCategoryConfig>> listPublicOfferingCategories({required String kind}) async {
    final q = '?kind=${Uri.encodeQueryComponent(kind)}';
    final res = await _http.get(_u('event-config/vendor-offering-categories$q'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => VendorCategoryConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VendorResourceCatalogItem>> listPublicResourceCatalog() async {
    final res = await _http.get(_u('event-config/vendor-resource-catalog'), headers: await _headers());
    if (res.statusCode >= 400) throw EventConfigApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => VendorResourceCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class EventConfigApiException implements Exception {
  EventConfigApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() {
    if (statusCode >= 500) return 'Internal Server Error';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded.containsKey('message')) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return 'Error ($statusCode)';
  }
}
