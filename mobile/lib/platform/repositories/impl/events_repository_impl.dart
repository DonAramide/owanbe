import '../../../core/api/events_api.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../../../features/public/models/public_models.dart';
import '../i_events_repository.dart';

class EventsRepositoryImpl implements IEventsRepository {
  const EventsRepositoryImpl(this._api);
  final EventsApi _api;

  @override
  Future<List<OrganizerEvent>> listOrganizerEvents() => _api.listOrganizerEvents();
  @override
  Future<OrganizerEvent?> getOrganizerEvent(String eventId) => _api.getOrganizerEvent(eventId);
  @override
  Future<OrganizerEvent> createEvent(Map<String, dynamic> data) => _api.createEvent(data);
  @override
  Future<OrganizerEvent> patchEvent(String eventId, Map<String, dynamic> data) => _api.patchEvent(eventId, data);
  @override
  Future<OrganizerEvent> publishEvent(String eventId) => _api.publishEvent(eventId);
  @override
  Future<OrganizerEvent> goLiveEvent(String eventId) => _api.goLiveEvent(eventId);
  @override
  Future<Map<String, dynamic>> fetchDashboard() => _api.fetchDashboard();
  @override
  Future<List<OrganizerTicketTier>> listTiers(String eventId) => _api.listOrganizerTiers(eventId);
  @override
  Future<OrganizerTicketTier> createTier(String eventId, Map<String, dynamic> data) => _api.createTier(eventId, data);
  @override
  Future<void> patchTier(String dbTierId, Map<String, dynamic> data) => _api.patchTier(dbTierId, data);
  @override
  Future<void> deleteTier(String dbTierId) => _api.deleteTier(dbTierId);
  @override
  Future<List<PublicEvent>> listPublicEvents({String? query, String? category}) =>
      _api.listPublicEvents(query: query, category: category);
  @override
  Future<PublicEvent?> getPublicEvent(String eventId) => _api.getPublicEvent(eventId);
}
