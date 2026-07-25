import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/auth_session.dart';
import '../../../core/api/ticket_commerce_api.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/providers/ticket_commerce_providers.dart';
import '../../../platform/services/bsp_providers.dart';
import '../../../platform/services/service_context.dart';
import '../providers/attendee_pass_providers.dart';
import 'purchase_notifications_provider.dart';

enum TicketCheckoutPhase {
  captured,
  awaitingHostedPayment,
  awaitingCapture,
  failed,
}

class TicketCheckoutResult {
  const TicketCheckoutResult({
    required this.phase,
    required this.orderId,
    this.paymentId,
    this.clientActionUrl,
    this.idempotencyKey,
    this.paymentIdempotencyKey,
    this.message,
  });

  final TicketCheckoutPhase phase;
  final String orderId;
  final String? paymentId;
  final String? clientActionUrl;
  final String? idempotencyKey;
  final String? paymentIdempotencyKey;
  final String? message;
}

/// Shared purchase orchestration — used by attendee and public checkout.
class TicketCheckoutCoordinator {
  TicketCheckoutCoordinator(this.ref);

  final WidgetRef ref;

  Future<TicketCheckoutResult> pay({
    required AuthSession session,
    required List<CartLine> cart,
    String? existingOrderId,
    String? orderIdempotencyKey,
    String? paymentIdempotencyKey,
  }) async {
    if (cart.isEmpty && existingOrderId == null) {
      throw TicketCommerceApiException(code: 'CART_EMPTY', message: 'Your cart is empty');
    }

    final api = ref.read(ticketCommerceApiProvider);
    final orderIdem = orderIdempotencyKey ?? 'checkout_${DateTime.now().millisecondsSinceEpoch}';
    final payIdem = paymentIdempotencyKey ?? '${orderIdem}_pay';

    late final TicketOrderResponse order;
    if (existingOrderId != null && existingOrderId.isNotEmpty) {
      order = await api.getTicketOrder(session: session, orderId: existingOrderId);
    } else {
      order = await api.createTicketOrder(
        session: session,
        eventId: cart.first.eventId,
        currency: cart.first.currency,
        items: [
          for (final line in cart) {'tierId': line.tierId, 'quantity': line.quantity},
        ],
        idempotencyKey: orderIdem,
      );
    }

    final payment = await api.createTicketPayment(
      session: session,
      orderId: order.orderId,
      idempotencyKey: payIdem,
    );

    if (payment.isCaptured) {
      await _hydrateEntitlements(session, payment);
      ref.read(cartProvider.notifier).clear();
      await _notifySuccess(session, order.orderId, payment.entitlements.length);
      return TicketCheckoutResult(
        phase: TicketCheckoutPhase.captured,
        orderId: order.orderId,
        paymentId: payment.paymentId,
        idempotencyKey: orderIdem,
        paymentIdempotencyKey: payIdem,
      );
    }

    if (payment.needsHostedPayment) {
      final url = Uri.tryParse(payment.clientActionUrl!);
      if (url != null) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      ref.read(purchaseNotificationsProvider.notifier).push(
            PurchaseNotification(
              type: PurchaseNotificationType.paymentPending,
              title: 'Complete payment',
              body: 'Finish checkout in the secure Quaser window, then return here.',
              orderId: order.orderId,
            ),
          );
      return TicketCheckoutResult(
        phase: TicketCheckoutPhase.awaitingHostedPayment,
        orderId: order.orderId,
        paymentId: payment.paymentId,
        clientActionUrl: payment.clientActionUrl,
        idempotencyKey: orderIdem,
        paymentIdempotencyKey: payIdem,
      );
    }

    return TicketCheckoutResult(
      phase: TicketCheckoutPhase.awaitingCapture,
      orderId: order.orderId,
      paymentId: payment.paymentId,
      idempotencyKey: orderIdem,
      paymentIdempotencyKey: payIdem,
      message: 'Payment initiated — waiting for confirmation.',
    );
  }

  Future<List<TicketEntitlementResponse>> refreshEntitlementsAfterSuccess(AuthSession session) async {
    final api = ref.read(ticketCommerceApiProvider);
    final entitlements = await api.fetchMyEntitlements(session);
    ref.read(checkoutEntitlementsProvider.notifier).set(entitlements);
    _syncLocalTickets(entitlements);
    ref.invalidate(attendeeTicketsSyncProvider);
    return entitlements;
  }

  Future<TicketOrderResponse> pollOrder({
    required AuthSession session,
    required String orderId,
  }) {
    return ref.read(ticketCommerceApiProvider).getTicketOrder(session: session, orderId: orderId);
  }

  static bool isOrderPaid(String? status) {
    final s = (status ?? '').toLowerCase();
    return s == 'confirmed' || s == 'fulfilled';
  }

  static bool isOrderFailed(String? status) {
    final s = (status ?? '').toLowerCase();
    return s == 'cancelled' || s == 'failed' || s == 'voided';
  }

  Future<void> _hydrateEntitlements(AuthSession session, TicketPaymentResponse payment) async {
    List<TicketEntitlementResponse> entitlements = payment.entitlements;
    final needsFull = entitlements.isEmpty ||
        entitlements.any((e) => e.eventId.isEmpty || e.qrPayload.isEmpty);
    if (needsFull) {
      try {
        entitlements = await ref.read(ticketCommerceApiProvider).fetchMyEntitlements(session);
      } catch (_) {
        // Keep partial payment entitlements if refresh fails.
      }
    }
    ref.read(checkoutEntitlementsProvider.notifier).set(entitlements);
    _syncLocalTickets(entitlements);
    ref.invalidate(attendeeTicketsSyncProvider);
  }

  void _syncLocalTickets(List<TicketEntitlementResponse> entitlements) {
    if (entitlements.isEmpty) return;
    final tickets = entitlements.map(mapEntitlementToTicket).toList();
    ref.read(attendeeTicketsProvider.notifier).addAll(tickets);
  }

  Future<void> _notifySuccess(AuthSession session, String orderId, int ticketCount) async {
    ref.read(purchaseNotificationsProvider.notifier).push(
          PurchaseNotification(
            type: PurchaseNotificationType.paymentSuccess,
            title: 'Payment successful',
            body: ticketCount > 0
                ? '$ticketCount ticket(s) ready for check-in.'
                : 'Your payment was confirmed. Tickets will appear shortly.',
            orderId: orderId,
          ),
        );
    ref.read(purchaseNotificationsProvider.notifier).push(
          PurchaseNotification(
            type: PurchaseNotificationType.ticketReady,
            title: 'Tickets ready',
            body: 'Your digital pass is available in My Tickets.',
            orderId: orderId,
          ),
        );
    ref.read(purchaseNotificationsProvider.notifier).push(
          PurchaseNotification(
            type: PurchaseNotificationType.purchaseConfirmation,
            title: 'Purchase confirmed',
            body: 'Order $orderId is confirmed.',
            orderId: orderId,
          ),
        );
    ref.read(purchaseNotificationsProvider.notifier).push(
          PurchaseNotification(
            type: PurchaseNotificationType.registrationConfirmation,
            title: 'Registration confirmed',
            body: 'You are registered for your event.',
            orderId: orderId,
          ),
        );

    try {
      final notif = ref.read(notificationServiceProvider);
      await notif.sendNotification(
        ctx: ServiceContext(
          userContext: null,
          tenantId: 'default',
          workspaceId: 'attendee',
          permissions: const [],
          correlationId: orderId,
          locale: 'en',
          featureFlags: const {},
        ),
        recipient: session.userId,
        title: 'Payment successful',
        body: 'Your Owanbe tickets are ready.',
      );
    } catch (_) {}
  }

  void notifyFailure(String orderId, String message) {
    ref.read(purchaseNotificationsProvider.notifier).push(
          PurchaseNotification(
            type: PurchaseNotificationType.paymentFailure,
            title: 'Payment failed',
            body: message,
            orderId: orderId,
          ),
        );
  }

  void notifyResend(String entitlementId) {
    ref.read(purchaseNotificationsProvider.notifier).push(
          PurchaseNotification(
            type: PurchaseNotificationType.resendConfirmation,
            title: 'Ticket resent',
            body: 'We sent your ticket confirmation again.',
            orderId: entitlementId,
          ),
        );
  }
}
