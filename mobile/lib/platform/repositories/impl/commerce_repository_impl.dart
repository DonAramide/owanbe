import '../../../auth/auth_session.dart';
import '../../../core/api/ticket_commerce_api.dart';
import '../i_commerce_repository.dart';

class CommerceRepositoryImpl implements ICommerceRepository {
  const CommerceRepositoryImpl(this._api);
  final TicketCommerceApi _api;

  @override
  Future<List<TicketEntitlementResponse>> listEntitlements(AuthSession session) async {
    return _api.fetchMyEntitlements(session);
  }

  @override
  Future<Map<String, dynamic>> checkout(AuthSession session, Map<String, dynamic> order) async {
    final response = await _api.createTicketOrder(
      session: session,
      eventId: order['eventId']?.toString() ?? '',
      currency: order['currency']?.toString() ?? 'NGN',
      items: (order['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
    return {
      'orderId': response.orderId,
      'totalMinor': response.totalMinor,
      'currency': response.currency,
    };
  }
}
