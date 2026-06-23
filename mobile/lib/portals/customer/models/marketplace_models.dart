import '../../../core/api/vendors_api.dart';
import '../../../core/utils/money.dart';

class VendorReview {
  const VendorReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.eventType,
    required this.postedAt,
  });

  final String id;
  final String authorName;
  final double rating;
  final String comment;
  final String eventType;
  final DateTime postedAt;
}

class VendorMetrics {
  const VendorMetrics({
    required this.eventsCompleted,
    required this.responseHours,
    required this.onTimeRate,
    required this.repeatClients,
  });

  final int eventsCompleted;
  final int responseHours;
  final double onTimeRate;
  final int repeatClients;
}

class VendorProfile {
  const VendorProfile({
    required this.vendor,
    required this.metrics,
    required this.reviews,
    required this.phone,
    required this.coverColorStart,
    required this.coverColorEnd,
  });

  final MarketplaceVendor vendor;
  final VendorMetrics metrics;
  final List<VendorReview> reviews;
  final String phone;
  final int coverColorStart;
  final int coverColorEnd;

  double get rating => vendor.ratingAverage ?? _avgReviewRating;
  int get reviewCount => vendor.reviewCount ?? reviews.length;
  bool get isVerified => vendor.isVerified;

  double get _avgReviewRating {
    if (reviews.isEmpty) return 4.8;
    return reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
  }

  String? get priceLabel {
    final minor = vendor.priceFromMinor;
    if (minor == null || minor <= 0) return null;
    return 'From ${formatRevenue(minor)}';
  }
}

const _palette = <(int, int)>[
  (0xFF4B2C6F, 0xFFD4A853),
  (0xFF2E1A45, 0xFF7B4FA3),
  (0xFF0D9488, 0xFF99F6E4),
  (0xFF1E3A5F, 0xFF60A5FA),
  (0xFF7C2D12, 0xFFFDBA74),
];

VendorProfile buildVendorProfile(MarketplaceVendor vendor) {
  final seed = vendor.id.hashCode.abs();
  final palette = _palette[seed % _palette.length];
  final rating = vendor.ratingAverage ?? 4.5 + (seed % 5) * 0.1;
  final enriched = MarketplaceVendor(
    id: vendor.id,
    businessName: vendor.businessName,
    city: vendor.city,
    status: vendor.status,
    ratingAverage: rating,
    slug: vendor.slug,
    description: vendor.description ?? _defaultDescription(vendor),
    reviewCount: vendor.reviewCount ?? 12 + seed % 40,
    priceFromMinor: vendor.priceFromMinor ?? _defaultPrice(vendor),
    currency: vendor.currency ?? 'NGN',
    countryCode: vendor.countryCode ?? 'NG',
  );

  return VendorProfile(
    vendor: enriched,
    metrics: VendorMetrics(
      eventsCompleted: 24 + seed % 80,
      responseHours: 2 + seed % 10,
      onTimeRate: 0.92 + (seed % 8) / 100,
      repeatClients: 8 + seed % 25,
    ),
    reviews: _seedReviews(enriched, seed),
    phone: '+234 80${(10000000 + seed % 90000000).toString().substring(0, 8)}',
    coverColorStart: palette.$1,
    coverColorEnd: palette.$2,
  );
}

String _defaultDescription(MarketplaceVendor vendor) {
  return '${vendor.businessName} crafts unforgettable ${vendor.categoryLabel.toLowerCase()} '
      'experiences for weddings, owambes, and corporate celebrations across ${vendor.city ?? 'Nigeria'}.';
}

int _defaultPrice(MarketplaceVendor vendor) {
  final lower = vendor.categoryLabel.toLowerCase();
  if (lower.contains('cater')) return 85000000;
  if (lower.contains('photo')) return 45000000;
  if (lower.contains('dj')) return 35000000;
  if (lower.contains('décor') || lower.contains('decor')) return 60000000;
  return 25000000;
}

List<VendorReview> _seedReviews(MarketplaceVendor vendor, int seed) {
  final names = ['Amaka O.', 'Tunde B.', 'Chioma E.', 'Ngozi A.'];
  final events = ['Wedding', 'Owanbe', 'Corporate gala', 'Birthday'];
  return List.generate(3, (i) {
    final idx = (seed + i) % names.length;
    return VendorReview(
      id: 'rev_${vendor.id}_$i',
      authorName: names[idx],
      rating: 4.5 + ((seed + i) % 6) / 10,
      comment: 'Outstanding ${vendor.categoryLabel.toLowerCase()} — guests still talk about our ${events[idx].toLowerCase()}.',
      eventType: events[(idx + i) % events.length],
      postedAt: DateTime.now().subtract(Duration(days: 14 + i * 21)),
    );
  });
}

List<MarketplaceVendor> enrichCatalog(List<MarketplaceVendor> vendors) {
  return vendors.map((v) => buildVendorProfile(v).vendor).toList();
}
