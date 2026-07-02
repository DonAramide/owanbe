import '../../auth/auth_session.dart';
import '../../core/api/ticket_commerce_api.dart';

abstract interface class ICommerceRepository {
  Future<List<TicketEntitlementResponse>> listEntitlements(AuthSession session);
  Future<Map<String, dynamic>> checkout(AuthSession session, Map<String, dynamic> order);
}
