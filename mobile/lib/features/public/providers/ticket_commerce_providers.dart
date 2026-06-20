import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/ticket_commerce_api.dart';

final ticketCommerceApiProvider = Provider<TicketCommerceApi>((ref) => TicketCommerceApi());

class CheckoutEntitlementsNotifier extends Notifier<List<TicketEntitlementResponse>> {
  @override
  List<TicketEntitlementResponse> build() => [];

  void set(List<TicketEntitlementResponse> items) => state = items;

  void clear() => state = [];
}

final checkoutEntitlementsProvider =
    NotifierProvider<CheckoutEntitlementsNotifier, List<TicketEntitlementResponse>>(
  CheckoutEntitlementsNotifier.new,
);
