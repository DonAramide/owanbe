import 'package:flutter/foundation.dart';

import 'contact_import_stub.dart'
    if (dart.library.io) 'contact_import_io.dart' as platform;

/// Normalized phone contact for guest import.
class DeviceContact {
  const DeviceContact({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;
}

/// Loads device contacts on mobile; uses demo list on web/desktop when needed.
Future<List<DeviceContact>> loadDeviceContacts() async {
  if (kIsWeb) {
    return demoImportContacts;
  }

  try {
    final device = await platform.loadPlatformContacts();
    if (device.isNotEmpty) return device;
  } catch (_) {
    // Permission denied or plugin unavailable.
  }

  return demoImportContacts;
}

const demoImportContacts = <DeviceContact>[
  DeviceContact(name: 'Amaka Okafor', email: 'amaka@example.com', phone: '+234 801 234 5678'),
  DeviceContact(name: 'Tunde Bakare', email: 'tunde@example.com', phone: '+234 802 345 6789'),
  DeviceContact(name: 'Chioma Eze', email: 'chioma@example.com', phone: '+234 803 456 7890'),
  DeviceContact(name: 'Ibrahim Musa', email: 'ibrahim@example.com', phone: '+234 804 567 8901'),
  DeviceContact(name: 'Ngozi Adeleke', email: 'ngozi@example.com', phone: '+234 805 678 9012'),
  DeviceContact(name: 'Funke Adeyemi', email: 'funke@example.com', phone: '+234 806 789 0123'),
  DeviceContact(name: 'Emeka Nwosu', email: 'emeka@example.com', phone: '+234 807 890 1234'),
];
