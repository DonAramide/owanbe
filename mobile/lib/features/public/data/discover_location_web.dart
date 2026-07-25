import 'dart:async';
import 'dart:html' as html;

import '../models/discover_filters.dart';

Future<DiscoverUserLocation?> resolveDiscoverLocationImpl() async {
  final geo = html.window.navigator.geolocation;
  try {
    final pos = await geo.getCurrentPosition(enableHighAccuracy: true).timeout(const Duration(seconds: 8));
    final coords = pos.coords;
    final lat = coords?.latitude;
    final lng = coords?.longitude;
    if (lat == null || lng == null) {
      return const DiscoverUserLocation(latitude: 6.5244, longitude: 3.3792);
    }
    return DiscoverUserLocation(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
  } catch (_) {
    return const DiscoverUserLocation(latitude: 6.5244, longitude: 3.3792);
  }
}
