import '../../features/organizer/models/organizer_models.dart';
import '../../features/public/models/public_models.dart';

abstract interface class IEventsRepository {
  Future<List<OrganizerEvent>> listOrganizerEvents();
  Future<OrganizerEvent?> getOrganizerEvent(String eventId);
  Future<OrganizerEvent> createEvent(Map<String, dynamic> data);
  Future<OrganizerEvent> patchEvent(String eventId, Map<String, dynamic> data);
  Future<OrganizerEvent> publishEvent(String eventId);
  Future<OrganizerEvent> goLiveEvent(String eventId);
  Future<Map<String, dynamic>> fetchDashboard();
  Future<List<OrganizerTicketTier>> listTiers(String eventId);
  Future<OrganizerTicketTier> createTier(String eventId, Map<String, dynamic> data);
  Future<void> patchTier(String dbTierId, Map<String, dynamic> data);
  Future<void> deleteTier(String dbTierId);
  Future<List<PublicEvent>> listPublicEvents({String? query, String? category});
  Future<PublicEvent?> getPublicEvent(String eventId);
}
