import '../models/discover_filters.dart';

import 'discover_location_stub.dart'
    if (dart.library.html) 'discover_location_web.dart' as impl;

Future<DiscoverUserLocation?> resolveDiscoverLocation() {
  return impl.resolveDiscoverLocationImpl();
}
