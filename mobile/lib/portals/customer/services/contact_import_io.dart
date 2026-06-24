import 'package:flutter_contacts/flutter_contacts.dart';

import 'contact_import_service.dart';

Future<List<DeviceContact>> loadPlatformContacts() async {
  final granted = await FlutterContacts.requestPermission(readonly: true);
  if (!granted) return const [];

  final raw = await FlutterContacts.getContacts(withProperties: true);
  final out = <DeviceContact>[];
  for (final c in raw) {
    final name = c.displayName.trim();
    if (name.isEmpty) continue;
    final email = c.emails.isNotEmpty ? c.emails.first.address.trim() : '';
    final phone = c.phones.isNotEmpty ? c.phones.first.number.trim() : '';
    if (email.isEmpty && phone.isEmpty) continue;
    out.add(DeviceContact(name: name, email: email, phone: phone));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}
