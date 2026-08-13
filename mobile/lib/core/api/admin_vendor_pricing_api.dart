import 'dart:convert';

import 'package:http/http.dart' as http;

import 'owambe_api_auth.dart';
import 'owambe_http_client.dart';

class VendorPricingRule {
  const VendorPricingRule({
    required this.id,
    required this.markupBps,
    required this.markupPercent,
    required this.isDefault,
    this.serviceKey,
    this.vendorId,
    this.vendorName,
    this.updatedAt,
  });

  final String id;
  final String? serviceKey;
  final String? vendorId;
  final String? vendorName;
  final int markupBps;
  final double markupPercent;
  final bool isDefault;
  final String? updatedAt;

  factory VendorPricingRule.fromJson(Map<String, dynamic> json) {
    return VendorPricingRule(
      id: (json['id'] ?? '').toString(),
      serviceKey: json['serviceKey']?.toString(),
      vendorId: json['vendorId']?.toString(),
      vendorName: json['vendorName']?.toString(),
      markupBps: (json['markupBps'] as num?)?.toInt() ?? 0,
      markupPercent: (json['markupPercent'] as num?)?.toDouble() ?? 0,
      isDefault: json['isDefault'] == true,
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class VendorPricingRulesSnapshot {
  const VendorPricingRulesSnapshot({
    required this.serviceRules,
    required this.vendorRules,
    required this.vendorServiceRules,
    required this.resolutionOrder,
    this.defaultRule,
  });

  final VendorPricingRule? defaultRule;
  final List<VendorPricingRule> serviceRules;
  final List<VendorPricingRule> vendorRules;
  final List<VendorPricingRule> vendorServiceRules;
  final List<String> resolutionOrder;

  factory VendorPricingRulesSnapshot.fromJson(Map<String, dynamic> json) {
    final defaultRaw = json['defaultRule'];
    List<VendorPricingRule> mapList(String key) => (json[key] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VendorPricingRule.fromJson)
        .toList();
    return VendorPricingRulesSnapshot(
      defaultRule: defaultRaw is Map<String, dynamic>
          ? VendorPricingRule.fromJson(defaultRaw)
          : null,
      serviceRules: mapList('serviceRules'),
      vendorRules: mapList('vendorRules'),
      vendorServiceRules: mapList('vendorServiceRules'),
      resolutionOrder: (json['resolutionOrder'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class AdminVendorPricingApiException implements Exception {
  AdminVendorPricingApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Admin-only client for `/admin/settings/vendor-pricing-rules`.
class AdminVendorPricingApi {
  AdminVendorPricingApi({http.Client? client})
      : _http = client ?? createOwambeHttpClient();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();

  String get _tenantId =>
      OwambeApiAuth.resolveTenantId(OwambeApiAuth.devTenantId);

  Future<Map<String, String>> _headers() async {
    try {
      return await OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);
    } on OwambeAuthRequiredException catch (e) {
      throw AdminVendorPricingApiException(
        code: 'AUTH_MISSING',
        message: e.message,
      );
    }
  }

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
  }

  Never _throwApi(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw AdminVendorPricingApiException(
        code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
        message: (body['message'] ?? 'Request failed').toString(),
      );
    } catch (e) {
      if (e is AdminVendorPricingApiException) rethrow;
      throw AdminVendorPricingApiException(
        code: 'HTTP_${res.statusCode}',
        message: 'Request failed',
      );
    }
  }

  Future<VendorPricingRulesSnapshot> listRules() async {
    final res = await _http.get(
      _u('admin/settings/vendor-pricing-rules'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return VendorPricingRulesSnapshot.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<VendorPricingRule> upsertDefault(double markupPercent) async {
    final res = await _http.put(
      _u('admin/settings/vendor-pricing-rules/default'),
      headers: await _headers(),
      body: jsonEncode({'markupPercent': markupPercent}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return VendorPricingRule.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VendorPricingRule> upsertServiceRule({
    required String serviceKey,
    required double markupPercent,
  }) async {
    final res = await _http.put(
      _u('admin/settings/vendor-pricing-rules/service'),
      headers: await _headers(),
      body: jsonEncode({
        'serviceKey': serviceKey,
        'markupPercent': markupPercent,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return VendorPricingRule.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteServiceRule(String serviceKey) async {
    final encoded = Uri.encodeComponent(serviceKey);
    final res = await _http.delete(
      _u('admin/settings/vendor-pricing-rules/service/$encoded'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }

  Future<VendorPricingRule> upsertVendorRule({
    required String vendorId,
    required double markupPercent,
    String? serviceKey,
  }) async {
    final res = await _http.put(
      _u('admin/settings/vendor-pricing-rules/vendor'),
      headers: await _headers(),
      body: jsonEncode({
        'vendorId': vendorId,
        'markupPercent': markupPercent,
        if (serviceKey != null && serviceKey.isNotEmpty) 'serviceKey': serviceKey,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
    return VendorPricingRule.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteVendorRule({
    required String vendorId,
    String? serviceKey,
  }) async {
    final encoded = Uri.encodeComponent(vendorId);
    final res = await _http.delete(
      _u(
        'admin/settings/vendor-pricing-rules/vendor/$encoded',
        {
          if (serviceKey != null && serviceKey.isNotEmpty) 'serviceKey': serviceKey,
        },
      ),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwApi(res);
  }
}
