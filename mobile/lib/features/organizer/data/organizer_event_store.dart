import '../models/organizer_models.dart';
import '../../../core/api/vendors_api.dart';

/// In-memory organizer event store — publishes to public marketplace when status is published/live.
class OrganizerEventStore {
  OrganizerEventStore._();
  static final OrganizerEventStore instance = OrganizerEventStore._();

  final List<OrganizerEvent> _events = _seed();

  List<OrganizerEvent> get all => List.unmodifiable(_events);

  List<OrganizerEvent> publishedForPublic() => _events
      .where((e) =>
          e.status == OrganizerEventStatus.published ||
          e.status == OrganizerEventStatus.live ||
          e.status == OrganizerEventStatus.completed)
      .toList();

  OrganizerEvent? byId(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  OrganizerEvent createDraft(EventWizardDraft draft) {
    final id = 'evt_${DateTime.now().millisecondsSinceEpoch}';
    final event = OrganizerEvent(
      id: id,
      title: draft.title,
      tagline: draft.tagline,
      description: draft.description,
      city: draft.city,
      venue: draft.venue,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      category: draft.category,
      venueType: draft.venueType,
      tags: List.from(draft.tags),
      bannerLabel: draft.bannerLabel,
      mediaLabels: List.from(draft.mediaLabels),
      status: OrganizerEventStatus.draft,
      coverGradientStart: 0xFF4B2C6F,
      coverGradientEnd: 0xFFD4A853,
      ticketTiers: draft.ticketTiers,
      vendors: const [],
      attendees: const [],
      createdAt: DateTime.now(),
    );
    _events.insert(0, event);
    return event;
  }

  OrganizerEvent update(String id, OrganizerEvent Function(OrganizerEvent e) transform) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx < 0) throw StateError('event not found');
    _events[idx] = transform(_events[idx]);
    return _events[idx];
  }

  OrganizerEvent publish(String id) {
    return update(
      id,
      (e) => e.copyWith(
        status: OrganizerEventStatus.published,
        publishedAt: DateTime.now(),
      ),
    );
  }

  OrganizerEvent setLive(String id) {
    return update(id, (e) => e.copyWith(status: OrganizerEventStatus.live));
  }

  OrganizerTicketTier addTicketTier(String eventId, OrganizerTicketTier tier) {
    return update(eventId, (e) => e.copyWith(ticketTiers: [...e.ticketTiers, tier])).ticketTiers.last;
  }

  OrganizerTicketTier updateTicketTier(String eventId, String tierId, OrganizerTicketTier Function(OrganizerTicketTier) fn) {
    return update(eventId, (e) {
      final tiers = e.ticketTiers.map((t) => t.id == tierId ? fn(t) : t).toList();
      return e.copyWith(ticketTiers: tiers);
    }).ticketTiers.firstWhere((t) => t.id == tierId);
  }

  OrganizerVendorSlot inviteVendor(String eventId, {required MarketplaceVendor vendor}) {
    final event = _events.firstWhere((e) => e.id == eventId);
    final alreadyInvited = event.vendors.any(
      (v) =>
          v.catalogVendorId == vendor.id ||
          v.businessName.toLowerCase() == vendor.businessName.toLowerCase(),
    );
    if (alreadyInvited) {
      throw StateError('${vendor.businessName} is already on this event');
    }
    final slot = OrganizerVendorSlot(
      id: 'v_${vendor.id}',
      catalogVendorId: vendor.id,
      businessName: vendor.businessName,
      category: vendor.categoryLabel,
      city: vendor.city,
      tier: vendor.isVerified ? 'verified' : 'standard',
      status: VendorSlotStatus.invited,
    );
    update(eventId, (e) => e.copyWith(vendors: [...e.vendors, slot]));
    return slot;
  }

  OrganizerVendorSlot setVendorStatus(String eventId, String vendorId, VendorSlotStatus status) {
    return update(eventId, (e) {
      final vendors = e.vendors.map((v) => v.id == vendorId ? v.copyWith(status: status) : v).toList();
      return e.copyWith(vendors: vendors);
    }).vendors.firstWhere((v) => v.id == vendorId);
  }

  List<OrganizerAttentionItem> attentionItems() {
    final items = <OrganizerAttentionItem>[];
    for (final e in _events) {
      if (e.status == OrganizerEventStatus.draft) {
        items.add(OrganizerAttentionItem(
          type: OrganizerAttentionType.unpublishedDraft,
          headline: 'Unpublished draft',
          message: '${e.title} is ready to publish',
          eventId: e.id,
          severity: 'INFO',
        ));
      }
      final pendingVendors = e.vendors.where((v) => v.status == VendorSlotStatus.pending).length;
      if (pendingVendors > 0) {
        items.add(OrganizerAttentionItem(
          type: OrganizerAttentionType.pendingVendorApproval,
          headline: '$pendingVendors vendor approval${pendingVendors == 1 ? '' : 's'}',
          message: e.title,
          eventId: e.id,
        ));
      }
      if (e.status == OrganizerEventStatus.published && e.sellThroughRate < 0.15 && e.totalCapacity > 0) {
        items.add(OrganizerAttentionItem(
          type: OrganizerAttentionType.lowTicketSales,
          headline: 'Low ticket sales',
          message: '${e.title} · ${(e.sellThroughRate * 100).toStringAsFixed(0)}% sold',
          eventId: e.id,
        ));
      }
      if (e.refundRequests > 0) {
        items.add(OrganizerAttentionItem(
          type: OrganizerAttentionType.refundRequest,
          headline: '${e.refundRequests} refund request${e.refundRequests == 1 ? '' : 's'}',
          message: e.title,
          eventId: e.id,
          severity: 'CRITICAL',
        ));
      }
    }
    return items;
  }

  EventAnalyticsSnapshot analyticsFor(String eventId) {
    final e = byId(eventId);
    if (e == null) {
      return EventAnalyticsSnapshot(
        eventId: eventId,
        pageViews: 0,
        ticketsSold: 0,
        revenueMinor: 0,
        checkInRate: 0,
        registrations: 0,
        checkIns: 0,
        noShows: 0,
        dailySales: const [0, 0, 0, 0, 0, 0, 0],
        weeklySales: const [0, 0, 0, 0],
        monthlySales: const [0, 0, 0],
        salesTrend: const [0, 0, 0, 0, 0, 0, 0],
        tierBreakdown: const {},
        tierTypeBreakdown: const {},
      );
    }
    final sold = e.ticketsSold;
    final checkIn = e.attendees.isEmpty ? 0.0 : e.checkedInCount / e.attendees.length;
    final breakdown = {for (final t in e.ticketTiers) t.name: t.capacity - t.remaining};
    final typeBreakdown = <TicketTierType, int>{};
    for (final t in e.ticketTiers) {
      typeBreakdown[t.tierType] = (typeBreakdown[t.tierType] ?? 0) + (t.capacity - t.remaining);
    }
    final trend = _syntheticTrend(sold);
    return EventAnalyticsSnapshot(
      eventId: eventId,
      pageViews: e.pageViews + sold * 3,
      ticketsSold: sold,
      revenueMinor: e.revenueMinor,
      checkInRate: checkIn,
      registrations: e.attendees.length,
      checkIns: e.checkedInCount,
      noShows: e.noShowCount,
      dailySales: trend,
      weeklySales: _weeklyFromDaily(trend),
      monthlySales: [sold * 0.4, sold * 0.7, sold.toDouble()],
      salesTrend: trend,
      tierBreakdown: breakdown,
      tierTypeBreakdown: typeBreakdown,
    );
  }

  List<double> _syntheticTrend(int sold) {
    if (sold == 0) return [0, 0, 0, 0, 0, 0, 0];
    final step = sold / 7;
    return List.generate(7, (i) => step * (i + 1));
  }

  List<double> _weeklyFromDaily(List<double> daily) {
    if (daily.length < 7) return [0, 0, 0, 0];
    return [
      daily[1],
      daily[3],
      daily[5],
      daily[6],
    ];
  }

  static List<OrganizerAttendee> _seedAttendees() {
    return List.generate(8, (i) {
      final purchased = DateTime.now().subtract(Duration(days: i));
      return OrganizerAttendee(
        id: 'att_$i',
        name: 'Guest ${i + 1}',
        email: 'guest$i@example.com',
        tierName: i.isEven ? 'General Admission' : 'VIP Lounge',
        ticketId: 'tkt_$i',
        checkedIn: i < 3,
        purchasedAt: purchased,
        purchases: [
          AttendeePurchase(
            item: i.isEven ? 'General Admission' : 'VIP Lounge',
            amountMinor: i.isEven ? 1500000 : 4500000,
            purchasedAt: purchased,
          ),
        ],
        timeline: [
          AttendeeTimelineEvent(label: 'Ticket purchased', at: purchased),
          if (i < 3) AttendeeTimelineEvent(label: 'Checked in at gate', at: purchased.add(const Duration(days: 1))),
        ],
      );
    });
  }

  static List<OrganizerEvent> _seed() {
    return [
      OrganizerEvent(
        id: 'evt_lagos_owanbe_2026',
        title: 'Lagos Sunset Owanbe',
        tagline: 'An evening of live Afrobeats, culture, and celebration',
        description:
            'Join thousands for Lagos\' most curated open-air experience. Premium sound, vendor village, and reserved seating zones.',
        city: 'Lagos',
        venue: 'Eko Atlantic Waterfront',
        venueType: VenueType.physical,
        tags: const ['afrobeats', 'festival', 'outdoor'],
        bannerLabel: 'Sunset gradient hero',
        mediaLabels: const ['Venue render', '2025 recap video', 'Lineup teaser'],
        startsAt: DateTime(2026, 8, 15, 18, 0),
        endsAt: DateTime(2026, 8, 15, 23, 30),
        category: 'Festival',
        status: OrganizerEventStatus.published,
        coverGradientStart: 0xFF4B2C6F,
        coverGradientEnd: 0xFFD4A853,
        isFeatured: true,
        pageViews: 12400,
        refundRequests: 1,
        publishedAt: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 2, 15),
        celebrantImageUrl: 'https://picsum.photos/seed/lagos-owanbe/400/500',
        ticketTiers: [
          OrganizerTicketTier(
            id: 'tier_ga',
            name: 'General Admission',
            description: 'Standing floor access + vendor village',
            priceMinor: 1500000,
            currency: 'NGN',
            capacity: 1000,
            remaining: 200,
            tierType: TicketTierType.regular,
            salesWindowStart: DateTime(2026, 3, 1),
            salesWindowEnd: DateTime(2026, 8, 14),
          ),
          OrganizerTicketTier(
            id: 'tier_vip',
            name: 'VIP Lounge',
            description: 'Reserved lounge, fast lane entry',
            priceMinor: 4500000,
            currency: 'NGN',
            capacity: 150,
            remaining: 30,
            tierType: TicketTierType.vip,
            salesWindowStart: DateTime(2026, 3, 1),
            salesWindowEnd: DateTime(2026, 8, 14),
          ),
          OrganizerTicketTier(
            id: 'tier_vvip',
            name: 'VVIP Royal Box',
            description: 'Private box + concierge',
            priceMinor: 12000000,
            currency: 'NGN',
            capacity: 20,
            remaining: 5,
            tierType: TicketTierType.vvip,
          ),
        ],
        vendors: const [
          OrganizerVendorSlot(
            id: 'v1',
            businessName: 'Jollof & Co',
            category: 'Catering',
            tier: 'premium',
            status: VendorSlotStatus.approved,
            contactEmail: 'ops@jollof.co',
            revenueMinor: 124000000,
            ordersCount: 18,
          ),
          OrganizerVendorSlot(
            id: 'v2',
            businessName: 'Lagos Lights AV',
            category: 'Production',
            tier: 'verified',
            status: VendorSlotStatus.approved,
            revenueMinor: 45000000,
            ordersCount: 4,
          ),
          OrganizerVendorSlot(
            id: 'v3',
            businessName: 'DecoHaus',
            category: 'Decoration',
            tier: 'standard',
            status: VendorSlotStatus.pending,
            contactEmail: 'hello@decohaus.ng',
          ),
        ],
        attendees: _seedAttendees(),
      ),
      OrganizerEvent(
        id: 'evt_abuja_wedding_expo',
        title: 'Abuja Wedding Expo',
        tagline: 'Plan your dream celebration with top vendors',
        description: 'Meet planners, caterers, and creatives.',
        city: 'Abuja',
        venue: 'Transcorp Hilton',
        venueType: VenueType.hybrid,
        tags: const ['wedding', 'expo'],
        bannerLabel: 'Wedding expo banner',
        startsAt: DateTime(2026, 7, 20, 10, 0),
        endsAt: DateTime(2026, 7, 20, 18, 0),
        category: 'Expo',
        status: OrganizerEventStatus.draft,
        coverGradientStart: 0xFF2E1A45,
        coverGradientEnd: 0xFF7B4FA3,
        ticketTiers: const [
          OrganizerTicketTier(
            id: 'tier_day',
            name: 'Day Pass',
            description: 'Full expo floor access',
            priceMinor: 500000,
            currency: 'NGN',
            capacity: 500,
            remaining: 500,
            tierType: TicketTierType.regular,
          ),
        ],
        vendors: const [],
        attendees: const [],
        createdAt: DateTime(2026, 4, 1),
        celebrantImageUrl: 'https://picsum.photos/seed/abuja-wedding/400/500',
      ),
    ];
  }
}
