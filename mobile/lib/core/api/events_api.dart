import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import '../../features/organizer/models/organizer_models.dart';
import '../../features/public/models/public_models.dart';
import '../../../shared/models/event_access_mode.dart';
import 'owambe_api_auth.dart';
import 'owambe_http_client.dart';

class EventsApiException implements Exception {
  EventsApiException({required this.code, required this.message});
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

class EventsApi {
  EventsApi({http.Client? client}) : _http = client ?? createOwambeHttpClient();
  final http.Client _http;

  static const devTenantId = '11111111-1111-4111-8111-111111111111';
  static const devOrganizerUserId = '22222222-2222-4222-8222-222222222222';
  static const devVendorUserId = '22222222-2222-4222-8222-222222222222';

  String get _base => OwambeApiAuth.resolveApiBase();

  String get _tenantId => OwambeApiAuth.resolveTenantId(devTenantId);

  Future<Map<String, String>> _headers({
    AuthSession? session,
    bool vendor = false,
  }) async {
    return OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);
  }

  Uri _u(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: query);
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

  Future<List<PublicEvent>> listPublicEvents({String? query, String? category}) async {
    final res = await _http.get(
      _u('events', {
        if (query != null && query.isNotEmpty) 'q': query,
        if (category != null && category.isNotEmpty) 'category': category,
      }),
      headers: OwambeApiAuth.publicHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => mapPublicEvent(e as Map<String, dynamic>))
        .toList();
  }

  Future<PublicEvent?> getPublicEvent(String eventId) async {
    final res = await _http.get(
      _u('events/$eventId'),
      headers: OwambeApiAuth.publicHeaders(tenantId: _tenantId),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) _throw(res);
    return mapPublicEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Public agenda / program (no manage auth) — includes day snapshot + recent activity.
  Future<Map<String, dynamic>> fetchPublicProgram(String eventId) async {
    final res = await _http.get(
      _u('events/$eventId/program'),
      headers: OwambeApiAuth.publicHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Attendee-safe live announcements / schedule alerts (Phase 7).
  Future<List<Map<String, dynamic>>> fetchLiveUpdates(String eventId) async {
    final res = await _http.get(
      _u('events/$eventId/live-updates'),
      headers: OwambeApiAuth.publicHeaders(tenantId: _tenantId),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Attendee report — reuses existing incidents endpoint.
  Future<void> reportEvent({
    required String eventId,
    required String title,
    required String category,
    String? description,
    AuthSession? session,
  }) async {
    final res = await _http.post(
      _u('events/$eventId/incidents'),
      headers: await _headers(session: session),
      body: jsonEncode({
        'title': title,
        'category': category,
        'priority': 'medium',
        'description': description,
        'reporter': 'attendee',
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<List<OrganizerEvent>> listOrganizerEvents({
    AuthSession? session,
    String? q,
    String? status,
    String? sort,
  }) async {
    final query = <String, String>{};
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (sort != null && sort.isNotEmpty) query['sort'] = sort;
    final res = await _http.get(
      _u('organizers/me/events', query.isEmpty ? null : query),
      headers: await _headers(session: session),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => mapOrganizerEvent(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrganizerEvent?> getOrganizerEvent(String eventId, {AuthSession? session}) async {
    final res = await _http.get(_u('events/$eventId/manage'), headers: await _headers(session: session));
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) _throw(res);
    return mapOrganizerEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OrganizerEvent> createEvent(Map<String, dynamic> body, {AuthSession? session}) async {
    final res = await _http.post(
      _u('events'),
      headers: await _headers(session: session),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return mapOrganizerEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OrganizerEvent> patchEvent(String eventId, Map<String, dynamic> body, {AuthSession? session}) async {
    final res = await _http.patch(
      _u('events/$eventId'),
      headers: await _headers(session: session),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    return mapOrganizerEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Soft-discards a draft event (status → cancelled). Hidden from normal organizer lists.
  Future<void> discardEvent(String eventId, {AuthSession? session}) async {
    final res = await _http.post(
      _u('events/$eventId/discard'),
      headers: await _headers(session: session),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<OrganizerEvent> publishEvent(String eventId, {AuthSession? session}) async {
    final res = await _http.post(_u('events/$eventId/publish'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
    return mapOrganizerEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OrganizerEvent> goLiveEvent(String eventId, {AuthSession? session}) async {
    final res = await _http.post(_u('events/$eventId/go-live'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
    return mapOrganizerEvent(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OrganizerTicketTier> createTier(String eventId, Map<String, dynamic> body, {AuthSession? session}) async {
    final res = await _http.post(
      _u('events/$eventId/tiers'),
      headers: await _headers(session: session),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
    final created = jsonDecode(res.body) as Map<String, dynamic>;
    final tiers = await listOrganizerTiers(eventId, session: session);
    return tiers.firstWhere(
      (t) => t.dbTierId == created['id'] || t.id == (created['externalTierId'] ?? body['id']),
      orElse: () => mapOrganizerTier(body, dbTierId: created['id'] as String?),
    );
  }

  Future<List<OrganizerTicketTier>> listOrganizerTiers(String eventId, {AuthSession? session}) async {
    final res = await _http.get(_u('events/$eventId/tiers/manage'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((e) => mapOrganizerTier(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> patchTier(String dbTierId, Map<String, dynamic> body, {AuthSession? session}) async {
    final res = await _http.patch(
      _u('tiers/$dbTierId'),
      headers: await _headers(session: session),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> deleteTier(String dbTierId, {AuthSession? session}) async {
    final res = await _http.delete(_u('tiers/$dbTierId'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> archiveTier(String dbTierId, {AuthSession? session}) async {
    final res = await _http.post(_u('tiers/$dbTierId/archive'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> unarchiveTier(String dbTierId, {AuthSession? session}) async {
    final res = await _http.post(_u('tiers/$dbTierId/unarchive'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
  }

  Future<OrganizerTicketTier> duplicateTier(String dbTierId, {AuthSession? session}) async {
    final res = await _http.post(_u('tiers/$dbTierId/duplicate'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
    final created = jsonDecode(res.body) as Map<String, dynamic>;
    // Reload manage list is caller's job; return a stub with new ids.
    return OrganizerTicketTier(
      id: (created['externalTierId'] ?? '').toString(),
      dbTierId: created['id']?.toString(),
      name: 'Copy',
      description: '',
      priceMinor: 0,
      currency: 'NGN',
      capacity: 0,
      remaining: 0,
    );
  }

  Future<void> reorderTiers(String eventId, List<String> orderedExternalIds, {AuthSession? session}) async {
    final res = await _http.post(
      _u('events/$eventId/tiers/reorder'),
      headers: await _headers(session: session),
      body: jsonEncode({'orderedExternalIds': orderedExternalIds}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<List<Map<String, dynamic>>> fetchTierSales(String eventId, {AuthSession? session}) async {
    final res = await _http.get(_u('events/$eventId/tiers/sales'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> fetchDashboard({AuthSession? session}) async {
    final res = await _http.get(_u('organizers/me/dashboard'), headers: await _headers(session: session));
    if (res.statusCode >= 400) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

String eventPublicId(Map<String, dynamic> json) =>
    (json['externalRef'] ?? json['external_ref'] ?? json['id'] ?? '').toString();

OrganizerEventStatus mapEventStatus(String raw) => switch (raw) {
      'published' => OrganizerEventStatus.published,
      'live' => OrganizerEventStatus.live,
      'completed' => OrganizerEventStatus.completed,
      'cancelled' => OrganizerEventStatus.cancelled,
      _ => OrganizerEventStatus.draft,
    };

VenueType mapVenueType(String raw) => switch (raw) {
      'virtual' => VenueType.virtual,
      'hybrid' => VenueType.hybrid,
      _ => VenueType.physical,
    };

TicketTierType mapTierType(String raw) => switch (raw) {
      'vip' => TicketTierType.vip,
      'vvip' => TicketTierType.vvip,
      'earlyBird' => TicketTierType.earlyBird,
      'group' => TicketTierType.group,
      'corporate' => TicketTierType.corporate,
      'table' => TicketTierType.table,
      'complimentary' => TicketTierType.complimentary,
      _ => TicketTierType.regular,
    };

TicketVisibility mapTierVisibility(String raw) =>
    raw == 'hidden' ? TicketVisibility.hidden : TicketVisibility.publicListing;

OrganizerTicketTier mapOrganizerTier(Map<String, dynamic> json, {String? dbTierId}) {
  final meta = json['metadata'] as Map<String, dynamic>? ?? {};
  return OrganizerTicketTier(
    id: (json['id'] ?? json['externalTierId'] ?? '').toString(),
    dbTierId: dbTierId ?? json['tierId'] as String?,
    name: (json['name'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    priceMinor: int.tryParse((json['priceMinor'] ?? '0').toString()) ?? 0,
    currency: (json['currency'] ?? 'NGN').toString(),
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    tierType: mapTierType((json['tierType'] ?? 'regular').toString()),
    visibility: mapTierVisibility((json['visibility'] ?? meta['visibility'] ?? 'publicListing').toString()),
    salesWindowStart: _parseDate(json['salesStartAt'] ?? meta['salesStartAt']),
    salesWindowEnd: _parseDate(json['salesEndAt'] ?? meta['salesEndAt']),
    salesPaused: json['salesPaused'] == true,
    archived: json['archived'] == true || meta['archived'] == true,
    unlimitedCapacity: json['unlimitedCapacity'] == true || meta['unlimitedCapacity'] == true,
    minQuantity: (json['minQuantity'] as num?)?.toInt() ?? (meta['minQuantity'] as num?)?.toInt() ?? 1,
    maxQuantity: (json['maxQuantity'] as num?)?.toInt() ?? (meta['maxQuantity'] as num?)?.toInt(),
    maxPerUser: (json['maxPerUser'] as num?)?.toInt() ?? (meta['maxPerUser'] as num?)?.toInt(),
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? (meta['sortOrder'] as num?)?.toInt() ?? 0,
  );
}

OrganizerEvent mapOrganizerEvent(Map<String, dynamic> json) {
  final tiers = (json['ticketTiers'] as List<dynamic>? ?? [])
      .map((e) => mapOrganizerTier(e as Map<String, dynamic>))
      .toList();
  final attendees = (json['attendees'] as List<dynamic>? ?? [])
      .whereType<Map>()
      .map((e) {
        final m = Map<String, dynamic>.from(e);
        final purchasedAt = m['purchasedAt'] != null ? _parseDate(m['purchasedAt']) : null;
        final tierName = (m['tierName'] ?? 'Ticket').toString();
        final amount = int.tryParse((m['amountMinor'] ?? '0').toString()) ?? 0;
        return OrganizerAttendee(
          id: (m['id'] ?? '').toString(),
          name: (m['name'] ?? 'Attendee').toString(),
          email: (m['email'] ?? '').toString(),
          tierName: tierName,
          ticketId: (m['ticketId'] ?? m['ticket_code'] ?? '').toString(),
          checkedIn: m['checkedIn'] == true || (m['entitlementStatus'] ?? m['status']) == 'checked_in',
          purchasedAt: purchasedAt,
          purchases: purchasedAt == null
              ? const []
              : [
                  AttendeePurchase(
                    item: tierName,
                    amountMinor: amount,
                    purchasedAt: purchasedAt,
                  ),
                ],
          timeline: [
            if (purchasedAt != null) AttendeeTimelineEvent(label: 'Purchased', at: purchasedAt),
            if (m['checkedIn'] == true || (m['entitlementStatus'] ?? m['status']) == 'checked_in')
              AttendeeTimelineEvent(label: 'Checked in', at: purchasedAt ?? DateTime.now()),
          ],
        );
      })
      .toList();
  return OrganizerEvent(
    id: eventPublicId(json),
    title: (json['title'] ?? '').toString(),
    tagline: (json['tagline'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    venue: (json['venue'] ?? '').toString(),
    startsAt: DateTime.parse((json['startsAt'] ?? DateTime.now().toIso8601String()).toString()),
    endsAt: json['endsAt'] != null
        ? DateTime.parse(json['endsAt'].toString())
        : DateTime.parse((json['startsAt'] ?? DateTime.now().toIso8601String()).toString())
            .add(const Duration(hours: 4)),
    category: (json['category'] ?? 'Festival').toString(),
    status: mapEventStatus((json['status'] ?? 'draft').toString()),
    venueType: mapVenueType((json['venueType'] ?? 'physical').toString()),
    tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    bannerLabel: (json['bannerLabel'] ?? 'Default banner').toString(),
    mediaLabels: (json['mediaLabels'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    coverGradientStart: (json['coverGradientStart'] as num?)?.toInt() ?? 0xFF4B2C6F,
    coverGradientEnd: (json['coverGradientEnd'] as num?)?.toInt() ?? 0xFFD4A853,
    ticketTiers: tiers,
    vendors: const [],
    attendees: attendees,
    isFeatured: json['isFeatured'] == true,
    createdAt: _parseDate(json['createdAt']),
    publishedAt: _parseDate(json['publishedAt']),
    eventAccessMode: EventAccessModeX.fromApi(json['eventAccessMode']?.toString()),
    budgetMinor: int.tryParse((json['budgetMinor'] ?? '0').toString()) ?? 0,
    expectedGuests: (json['expectedGuests'] as num?)?.toInt() ?? 0,
    categorySlug: (json['categorySlug'] ?? '').toString(),
    venueName: (json['venueName'] ?? json['venue'] ?? '').toString(),
    venueAddress: (json['venueAddress'] ?? '').toString(),
    venueLatitude: (json['venueLatitude'] as num?)?.toDouble(),
    venueLongitude: (json['venueLongitude'] as num?)?.toDouble(),
    googlePlaceId: json['googlePlaceId']?.toString(),
    celebrantImageUrl: json['celebrantImageUrl']?.toString(),
    language: (json['language'] ?? 'en').toString(),
    ageRestrictionMin: (json['ageRestrictionMin'] as num?)?.toInt() ?? 0,
    listingVisibility: (json['listingVisibility'] ?? 'invite_only').toString(),
    registrationEnabled: json['registrationEnabled'] != false,
    checkInEnabled: json['checkInEnabled'] != false,
    themeColor: (json['themeColor'] ?? '#4B2C6F').toString(),
    requiredServices: (json['requiredServices'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    venueDeferred: json['venueDeferred'] == true,
    state: (json['state'] ?? '').toString(),
    lga: (json['lga'] ?? '').toString(),
    selectedTemplateSlug: (json['selectedTemplateSlug'] ?? '').toString(),
    reportedTicketsSold: (json['ticketsSold'] as num?)?.toInt() ?? (json['attendeeCount'] as num?)?.toInt(),
    reportedRevenueMinor: int.tryParse((json['revenueMinor'] ?? '').toString()),
    reportedOrdersCount: (json['ordersCount'] as num?)?.toInt(),
    reportedBuyersCount: (json['buyersCount'] as num?)?.toInt(),
  );
}

PublicEvent mapPublicEvent(Map<String, dynamic> json) {
  final tiers = (json['ticketTiers'] as List<dynamic>? ?? [])
      .where((t) {
        final m = t as Map<String, dynamic>;
        return m['salesPaused'] != true && (m['visibility'] ?? 'publicListing') != 'hidden';
      })
      .map((t) {
        final m = t as Map<String, dynamic>;
        return TicketTier(
          id: (m['id'] ?? '').toString(),
          name: (m['name'] ?? '').toString(),
          description: (m['description'] ?? '').toString(),
          priceMinor: int.tryParse((m['priceMinor'] ?? '0').toString()) ?? 0,
          currency: (m['currency'] ?? 'NGN').toString(),
          remaining: (m['remaining'] as num?)?.toInt() ?? 0,
          salesStartAt: _parseDate(m['salesStartAt']),
          salesEndAt: _parseDate(m['salesEndAt']),
          benefits: _stringList(m['benefits']),
          accessLevel: m['accessLevel']?.toString(),
          perks: _stringList(m['perks']),
          restrictions: _stringList(m['restrictions']),
        );
      })
      .toList();
  final status = (json['status'] ?? 'upcoming').toString();
  final ticketsSold = (json['ticketsSold'] as num?)?.toInt() ?? 0;
  return PublicEvent(
    id: eventPublicId(json),
    title: (json['title'] ?? '').toString(),
    tagline: (json['tagline'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    venue: (json['venue'] ?? '').toString(),
    startsAt: DateTime.parse((json['startsAt'] ?? DateTime.now().toIso8601String()).toString()),
    endsAt: json['endsAt'] != null
        ? DateTime.parse(json['endsAt'].toString())
        : DateTime.parse((json['startsAt'] ?? DateTime.now().toIso8601String()).toString())
            .add(const Duration(hours: 4)),
    coverGradientStart: (json['coverGradientStart'] as num?)?.toInt() ?? 0xFF4B2C6F,
    coverGradientEnd: (json['coverGradientEnd'] as num?)?.toInt() ?? 0xFFD4A853,
    category: (json['category'] ?? 'Festival').toString(),
    isFeatured: json['isFeatured'] == true,
    attendeeCount: ticketsSold > 0 ? ticketsSold : (json['attendeeCount'] as num?)?.toInt(),
    status: status == 'live' || status == 'completed' ? status : 'upcoming',
    ticketTiers: tiers,
    venueType: (json['venueType'] ?? 'physical').toString().toLowerCase(),
    tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    organizerId: json['organizerId']?.toString(),
    venueLatitude: (json['venueLatitude'] as num?)?.toDouble(),
    venueLongitude: (json['venueLongitude'] as num?)?.toDouble(),
    ticketsSold: ticketsSold,
    venueAddress: json['venueAddress']?.toString(),
    celebrantImageUrl: json['celebrantImageUrl']?.toString(),
    galleryMedia: _galleryList(json['galleryMedia']),
    speakers: _speakers(json['speakers']),
    sponsors: _sponsors(json['sponsors']),
    faqs: _faqs(json['faqs']),
    organizerName: json['organizerName']?.toString(),
    organizerContactEmail: json['organizerContactEmail']?.toString(),
    organizerContactPhone: json['organizerContactPhone']?.toString(),
  );
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
}

List<EventGalleryItem> _galleryList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) {
        final map = Map<String, dynamic>.from(m);
        final url = (map['url'] ?? '').toString();
        if (url.isEmpty) return null;
        return EventGalleryItem(
          url: url,
          type: (map['type'] ?? 'image').toString(),
          label: map['label']?.toString(),
        );
      })
      .whereType<EventGalleryItem>()
      .toList();
}

List<EventSpeaker> _speakers(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) {
        final map = Map<String, dynamic>.from(m);
        final name = (map['name'] ?? '').toString();
        if (name.isEmpty) return null;
        return EventSpeaker(
          name: name,
          title: map['title']?.toString(),
          bio: map['bio']?.toString(),
          imageUrl: map['imageUrl']?.toString(),
        );
      })
      .whereType<EventSpeaker>()
      .toList();
}

List<EventSponsor> _sponsors(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) {
        final map = Map<String, dynamic>.from(m);
        final name = (map['name'] ?? '').toString();
        if (name.isEmpty) return null;
        return EventSponsor(
          name: name,
          tier: map['tier']?.toString(),
          logoUrl: map['logoUrl']?.toString(),
          websiteUrl: map['websiteUrl']?.toString(),
        );
      })
      .whereType<EventSponsor>()
      .toList();
}

List<EventFaq> _faqs(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) {
        final map = Map<String, dynamic>.from(m);
        final q = (map['question'] ?? '').toString();
        final a = (map['answer'] ?? '').toString();
        if (q.isEmpty) return null;
        return EventFaq(question: q, answer: a);
      })
      .whereType<EventFaq>()
      .toList();
}

class OrganizerDashboardStats {
  const OrganizerDashboardStats({
    required this.activeEvents,
    required this.upcomingEvents,
    required this.ticketsSold,
    required this.revenueMinor,
    required this.vendorCount,
    required this.attendeeCount,
  });

  final int activeEvents;
  final int upcomingEvents;
  final int ticketsSold;
  final int revenueMinor;
  final int vendorCount;
  final int attendeeCount;
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
