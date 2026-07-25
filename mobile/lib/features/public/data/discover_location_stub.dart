import '../models/discover_filters.dart';

/// Non-web stub — Lagos CBD default for Nearby until native geolocation is wired.
Future<DiscoverUserLocation?> resolveDiscoverLocationImpl() async {
  return const DiscoverUserLocation(latitude: 6.5244, longitude: 3.3792);
}
