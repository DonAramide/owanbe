import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fashion_attire_constants.dart';

const _preferredVendorKey = 'event_attire_vendor_';
const _preferredVendorNameKey = 'event_attire_vendor_name_';

final preferredAttireVendorProvider =
    FutureProvider.autoDispose.family<({String? id, String? name}), String>((ref, eventId) async {
  final prefs = await SharedPreferences.getInstance();
  return (
    id: prefs.getString('$_preferredVendorKey$eventId'),
    name: prefs.getString('$_preferredVendorNameKey$eventId'),
  );
});

Future<void> setPreferredAttireVendor({
  required String eventId,
  required String vendorId,
  required String vendorName,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_preferredVendorKey$eventId', vendorId);
  await prefs.setString('$_preferredVendorNameKey$eventId', vendorName);
}

Future<void> clearPreferredAttireVendor(String eventId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('$_preferredVendorKey$eventId');
  await prefs.remove('$_preferredVendorNameKey$eventId');
}

/// Fashion vendors filtered for attire management.
final fashionAttireVendorsProvider = Provider.autoDispose<List<String>>((ref) {
  return [fashionAttireVertical, ...fashionAttireSubcategories];
});
