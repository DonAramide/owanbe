import '../../../../core/api/vendors_api.dart';
import '../../../../core/utils/money.dart';
import '../../../../portals/customer/models/marketplace_models.dart';

class EventCenterOption {
  const EventCenterOption({
    required this.id,
    required this.name,
    required this.state,
    required this.lga,
    required this.city,
    required this.address,
    required this.priceFromMinor,
    this.priceToMinor,
    this.imageUrl,
    this.videoPreviewUrl,
    this.rating = 4.5,
    this.reviewCount = 24,
  });

  final String id;
  final String name;
  final String state;
  final String lga;
  final String city;
  final String address;
  final int priceFromMinor;
  final int? priceToMinor;
  final String? imageUrl;
  final String? videoPreviewUrl;
  final double rating;
  final int reviewCount;

  String get priceLabel => 'From ${formatRevenue(priceFromMinor)}';

  String coverImageUrl() => imageUrl ?? vendorCoverImageUrl(
        MarketplaceVendor(id: id, businessName: name, slug: 'venue', city: city),
      );
}

const kEventCenterCatalog = <EventCenterOption>[
  EventCenterOption(
    id: 'ec-eko',
    name: 'Eko Hotels & Suites',
    state: 'Lagos',
    lga: 'Eti-Osa',
    city: 'Lagos',
    address: '1415 Adetokunbo Ademola Street, Victoria Island',
    priceFromMinor: 175000000,
    priceToMinor: 280000000,
    rating: 4.8,
    reviewCount: 186,
  ),
  EventCenterOption(
    id: 'ec-transcorp',
    name: 'Transcorp Hilton Abuja',
    state: 'Abuja FCT',
    lga: 'Abuja Municipal',
    city: 'Abuja',
    address: '1 Aguiyi Ironsi Street, Maitama',
    priceFromMinor: 150000000,
    priceToMinor: 240000000,
    rating: 4.7,
    reviewCount: 142,
  ),
  EventCenterOption(
    id: 'ec-landmark',
    name: 'Landmark Event Centre',
    state: 'Lagos',
    lga: 'Eti-Osa',
    city: 'Lagos',
    address: 'Water Corporation Drive, Victoria Island',
    priceFromMinor: 95000000,
    priceToMinor: 160000000,
    rating: 4.6,
    reviewCount: 98,
  ),
  EventCenterOption(
    id: 'ec-amber',
    name: 'Amber Residence Hall',
    state: 'Lagos',
    lga: 'Ikeja',
    city: 'Lagos',
    address: '17 Kodesoh Street, Ikeja GRA',
    priceFromMinor: 45000000,
    priceToMinor: 85000000,
    rating: 4.5,
    reviewCount: 67,
  ),
  EventCenterOption(
    id: 'ec-velvet',
    name: 'Velvet Garden Arena',
    state: 'Lagos',
    lga: 'Surulere',
    city: 'Lagos',
    address: '12 Adeniran Ogunsanya Street',
    priceFromMinor: 35000000,
    priceToMinor: 65000000,
    rating: 4.4,
    reviewCount: 54,
  ),
  EventCenterOption(
    id: 'ec-ogun-pavilion',
    name: 'Ogun Royal Pavilion',
    state: 'Ogun',
    lga: 'Abeokuta South',
    city: 'Abeokuta',
    address: 'Panseke-Adigbe Road',
    priceFromMinor: 28000000,
    priceToMinor: 52000000,
    rating: 4.3,
    reviewCount: 41,
  ),
  EventCenterOption(
    id: 'ec-ph-garden',
    name: 'Garden City Banquet',
    state: 'Rivers',
    lga: 'Port Harcourt',
    city: 'Port Harcourt',
    address: 'GRA Phase 2, Port Harcourt',
    priceFromMinor: 40000000,
    priceToMinor: 75000000,
    rating: 4.5,
    reviewCount: 38,
  ),
  EventCenterOption(
    id: 'ec-kano-palace',
    name: 'Kano Celebration Palace',
    state: 'Kano',
    lga: 'Nassarawa',
    city: 'Kano',
    address: 'Bayero University Road',
    priceFromMinor: 32000000,
    priceToMinor: 60000000,
    rating: 4.2,
    reviewCount: 29,
  ),
];

List<EventCenterOption> filterEventCenters({
  String? state,
  String? lga,
  String query = '',
  int maxPriceMinor = 0,
}) {
  var list = kEventCenterCatalog;
  if (state != null && state.isNotEmpty) {
    list = list.where((c) => c.state == state).toList();
  }
  if (lga != null && lga.isNotEmpty) {
    list = list.where((c) => c.lga == lga).toList();
  }
  if (maxPriceMinor > 0) {
    list = list.where((c) => c.priceFromMinor <= maxPriceMinor).toList();
  }
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty) {
    list = list
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.city.toLowerCase().contains(q) ||
              c.address.toLowerCase().contains(q),
        )
        .toList();
  }
  list.sort((a, b) => a.priceFromMinor.compareTo(b.priceFromMinor));
  return list;
}
