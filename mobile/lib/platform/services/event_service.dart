import '../../features/operations/models/operations_models.dart';
import '../bootstrap/platform_event_bus.dart';
import '../events/platform_domain_events.dart';
import '../repositories/i_operations_repository.dart';
import 'audit_service.dart';
import 'service_context.dart';
import 'service_result.dart';

abstract interface class IEventService {
  Future<ServiceResult<List<OpsGuest>>> listGuests(ServiceContext ctx, String eventId);
  Future<ServiceResult<List<OpsFeedEvent>>> listFeed(ServiceContext ctx, String eventId);
  Future<ServiceResult<List<OpsIncident>>> listIncidents(ServiceContext ctx, String eventId);
  Future<ServiceResult<OpsGuest>> checkInGuest(ServiceContext ctx, String eventId, String guestId);
  Future<ServiceResult<QrScanResponse>> scanTicket(ServiceContext ctx, String eventId, String ticketCode);
  Future<ServiceResult<OpsIncident>> logIncident(ServiceContext ctx, {
    required String eventId,
    required String title,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String reporter,
    String description,
  });
  // Legacy compat
  Future<ServiceResult<bool>> createEvent(ServiceContext ctx, Map<String, dynamic> eventData);
  Future<ServiceResult<bool>> trackAttendance(ServiceContext ctx, String eventId, String attendeeId);
  Future<ServiceResult<bool>> validateCheckIn(ServiceContext ctx, String ticketCode);
}

class EventService implements IEventService {
  const EventService(this._repository);
  final IOperationsRepository _repository;

  @override
  Future<ServiceResult<List<OpsGuest>>> listGuests(ServiceContext ctx, String eventId) async {
    try {
      return ServiceResult.success(await _repository.listGuests(eventId));
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<List<OpsFeedEvent>>> listFeed(ServiceContext ctx, String eventId) async {
    try {
      return ServiceResult.success(await _repository.listFeed(eventId));
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<List<OpsIncident>>> listIncidents(ServiceContext ctx, String eventId) async {
    try {
      return ServiceResult.success(await _repository.listIncidents(eventId));
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<OpsGuest>> checkInGuest(ServiceContext ctx, String eventId, String guestId) async {
    try {
      final guest = await _repository.checkInGuest(eventId, guestId);
      await AuditService.instance.log(context: ctx, operation: 'AttendeeCheckIn', result: 'success');
      PlatformEventBus.instance.fire(AttendeeCheckedIn(eventId: eventId, attendeeId: guestId, ticketCode: guest.ticketId));
      return ServiceResult.success(guest);
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<QrScanResponse>> scanTicket(ServiceContext ctx, String eventId, String ticketCode) async {
    try {
      final response = await _repository.scanTicket(eventId, ticketCode);
      if (response.result == QrScanResult.valid || response.result == QrScanResult.vip || response.result == QrScanResult.vvip) {
        await AuditService.instance.log(context: ctx, operation: 'QrScan', result: 'checkin');
        PlatformEventBus.instance.fire(AttendeeCheckedIn(eventId: eventId, attendeeId: response.guest?.id ?? '', ticketCode: ticketCode));
      }
      return ServiceResult.success(response);
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<OpsIncident>> logIncident(ServiceContext ctx, {
    required String eventId,
    required String title,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String reporter,
    String description = '',
  }) async {
    try {
      final incident = await _repository.logIncident(
        eventId: eventId,
        title: title,
        category: category,
        priority: priority,
        reporter: reporter,
        description: description,
      );
      await AuditService.instance.log(context: ctx, operation: 'IncidentLogged', result: 'success');
      return ServiceResult.success(incident);
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<bool>> createEvent(ServiceContext ctx, Map<String, dynamic> eventData) async {
    await AuditService.instance.log(context: ctx, operation: 'EventCreation', result: 'success');
    return ServiceResult.success(true);
  }

  @override
  Future<ServiceResult<bool>> trackAttendance(ServiceContext ctx, String eventId, String attendeeId) async {
    await AuditService.instance.log(context: ctx, operation: 'AttendanceTracking', result: 'success');
    return ServiceResult.success(true);
  }

  @override
  Future<ServiceResult<bool>> validateCheckIn(ServiceContext ctx, String ticketCode) async {
    await AuditService.instance.log(context: ctx, operation: 'TicketCheckInValidation', result: 'success');
    return ServiceResult.success(true);
  }
}
