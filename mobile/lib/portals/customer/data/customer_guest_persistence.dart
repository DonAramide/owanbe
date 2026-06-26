import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../features/operations/data/operations_store.dart';
import '../../../features/operations/models/operations_models.dart';
import '../../../features/operations/providers/operations_providers.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../providers/customer_guest_providers.dart';
import '../services/contact_import_service.dart';

OpsGuest _guestFromRecord(
  dynamic record, {
  String tierName = 'General Admission',
  GuestTier tier = GuestTier.general,
}) {
  return OpsGuest(
    id: record.id as String,
    name: record.name as String,
    email: (record.email as String?) ?? '',
    ticketId: (record.guestRef as String?) ?? '',
    tierName: tierName,
    tier: tier,
    checkedIn: false,
  );
}

Future<OpsGuest> addCustomerGuest(
  WidgetRef ref,
  String eventId, {
  required String name,
  required String email,
  String tierName = 'General Admission',
  GuestTier tier = GuestTier.general,
}) async {
  try {
    final record = await ref.read(eventGuestsApiProvider).addGuest(
          eventId,
          name: name,
          email: email.isNotEmpty ? email : null,
        );
    final guest = _guestFromRecord(record, tierName: tierName, tier: tier);
    refreshCustomerGuests(ref);
    return guest;
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
  }
  OperationsStore.instance.ensureLive(eventId);
  final guest = OperationsStore.instance.addGuest(
    eventId,
    name: name,
    email: email,
    tierName: tierName,
    tier: tier,
  );
  bumpOperationsRevision(ref);
  bumpOrganizerRevision(ref);
  refreshCustomerGuests(ref);
  return guest;
}

Future<List<OpsGuest>> importCustomerContacts(
  WidgetRef ref,
  String eventId,
  List<DeviceContact> contacts,
) async {
  if (!allowMockPersistenceFallback()) {
    throw StateError('Contact import is disabled for production launch.');
  }
  OperationsStore.instance.ensureLive(eventId);
  final normalized = contacts
      .map(
        (c) => (
          name: c.name,
          email: c.email.isNotEmpty ? c.email : '${c.phone.replaceAll(RegExp(r'\D'), '')}@invite.local',
        ),
      )
      .toList();
  final guests = OperationsStore.instance.importGuests(eventId, normalized);
  bumpOperationsRevision(ref);
  bumpOrganizerRevision(ref);
  refreshCustomerGuests(ref);
  return guests;
}
