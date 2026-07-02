import 'service_context.dart';
import 'service_result.dart';
import 'audit_service.dart';

abstract class ITicketService {
  Future<ServiceResult<Map<String, dynamic>>> issueTicket(ServiceContext ctx, String eventId, String tierId);
  Future<ServiceResult<bool>> validateTicket(ServiceContext ctx, String qrCode);
  Future<ServiceResult<bool>> initiateRefund(ServiceContext ctx, String ticketId);
}

class TicketService implements ITicketService {
  const TicketService();

  @override
  Future<ServiceResult<Map<String, dynamic>>> issueTicket(ServiceContext ctx, String eventId, String tierId) async {
    final ticketCode = 'TKT-MOCK-12345';
    await AuditService.instance.log(context: ctx, operation: 'TicketIssuance', result: 'success');
    return ServiceResult.success({
      'ticket_code': ticketCode,
      'qr_payload': 'OWANBE:$eventId:$tierId:$ticketCode',
    });
  }

  @override
  Future<ServiceResult<bool>> validateTicket(ServiceContext ctx, String qrCode) async {
    return ServiceResult.success(true);
  }

  @override
  Future<ServiceResult<bool>> initiateRefund(ServiceContext ctx, String ticketId) async {
    await AuditService.instance.log(context: ctx, operation: 'RefundInitiation', result: 'success');
    return ServiceResult.success(true);
  }
}
