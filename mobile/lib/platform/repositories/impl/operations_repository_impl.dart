import '../../../core/api/operations_api.dart';
import '../../../features/operations/models/operations_models.dart';
import '../i_operations_repository.dart';

class OperationsRepositoryImpl implements IOperationsRepository {
  const OperationsRepositoryImpl(this._api);
  final OperationsApi _api;

  @override
  Future<List<OpsGuest>> listGuests(String eventId) => _api.listGuests(eventId);
  @override
  Future<List<OpsFeedEvent>> listFeed(String eventId) => _api.listFeed(eventId);
  @override
  Future<List<OpsIncident>> listIncidents(String eventId) => _api.listIncidents(eventId);
  @override
  Future<OpsGuest> checkInGuest(String eventId, String guestId) async {
    // API returns CheckInResult, map guest status locally
    final result = await _api.checkIn(eventId: eventId, entitlementId: guestId);
    return OpsGuest(
      id: guestId,
      name: result.holderName ?? 'Guest',
      email: '',
      ticketId: result.ticketCode ?? '',
      tierName: result.tierName ?? 'General',
      tier: GuestTier.general,
      checkedIn: result.ok,
      checkedInAt: result.ok ? DateTime.now() : null,
    );
  }
  @override
  Future<OpsIncident> logIncident({
    required String eventId,
    required String title,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String reporter,
    String description = '',
  }) async {
    final id = await _api.createIncident(
      eventId: eventId,
      title: title,
      category: category,
      priority: priority,
      reporter: reporter,
      description: description,
    );
    return OpsIncident(
      id: id,
      title: title,
      category: category,
      priority: priority,
      status: IncidentStatus.open,
      reporter: reporter,
      reportedAt: DateTime.now(),
      timeline: [OpsIncidentEvent(label: 'Logged', at: DateTime.now())],
      description: description,
    );
  }
  @override
  Future<QrScanResponse> scanTicket(String eventId, String ticketCode) async {
    final result = await _api.checkIn(eventId: eventId, ticketCode: ticketCode);
    final guest = OpsGuest(
      id: 'ticket_$ticketCode',
      name: result.holderName ?? 'Ticket Holder',
      email: '',
      ticketId: ticketCode,
      tierName: result.tierName ?? 'General',
      tier: GuestTier.general,
      checkedIn: result.ok,
      checkedInAt: result.ok ? DateTime.now() : null,
    );
    if (!result.ok) {
      if (result.duplicate) {
        return QrScanResponse(result: QrScanResult.alreadyUsed, message: 'Ticket already scanned', guest: guest);
      }
      return QrScanResponse(result: QrScanResult.invalid, message: 'Invalid or unrecognized ticket', guest: guest);
    }
    return QrScanResponse(result: QrScanResult.valid, message: 'Check-in successful', guest: guest);
  }
}
