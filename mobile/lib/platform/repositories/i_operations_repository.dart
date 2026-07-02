import '../../features/operations/models/operations_models.dart';

abstract interface class IOperationsRepository {
  Future<List<OpsGuest>> listGuests(String eventId);
  Future<List<OpsFeedEvent>> listFeed(String eventId);
  Future<List<OpsIncident>> listIncidents(String eventId);
  Future<OpsGuest> checkInGuest(String eventId, String guestId);
  Future<OpsIncident> logIncident({
    required String eventId,
    required String title,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String reporter,
    String description,
  });
  Future<QrScanResponse> scanTicket(String eventId, String ticketCode);
}
