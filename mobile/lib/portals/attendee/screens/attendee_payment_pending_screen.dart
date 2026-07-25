import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/ticket_commerce_api.dart';
import '../../../eos/eos.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../features/public/providers/ticket_commerce_providers.dart';
import '../commerce/purchase_notifications_provider.dart';
import '../commerce/ticket_checkout_coordinator.dart';
import '../navigation/attendee_routes.dart';
import '../widgets/attendee_flow_scaffold.dart';

/// Polls order status after hosted Quaser payment or pending capture.
class AttendeePaymentPendingScreen extends ConsumerStatefulWidget {
  const AttendeePaymentPendingScreen({
    super.key,
    required this.orderId,
    this.clientActionUrl,
    this.orderIdempotencyKey,
    this.paymentIdempotencyKey,
  });

  final String orderId;
  final String? clientActionUrl;
  final String? orderIdempotencyKey;
  final String? paymentIdempotencyKey;

  @override
  ConsumerState<AttendeePaymentPendingScreen> createState() => _AttendeePaymentPendingScreenState();
}

class _AttendeePaymentPendingScreenState extends ConsumerState<AttendeePaymentPendingScreen> {
  Timer? _timer;
  String _status = 'pending_payment';
  String? _error;
  bool _busy = false;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pollOnce();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOnce());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pollOnce() async {
    if (_busy) return;
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    if (ref.read(attendeeOfflineProvider)) {
      setState(() => _error = 'You appear offline. Reconnect to confirm payment status.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final coordinator = TicketCheckoutCoordinator(ref);
      final order = await coordinator.pollOrder(session: session, orderId: widget.orderId);
      _ticks += 1;
      setState(() => _status = order.status ?? _status);

      if (TicketCheckoutCoordinator.isOrderPaid(order.status)) {
        _timer?.cancel();
        await coordinator.refreshEntitlementsAfterSuccess(session);
        final ents = ref.read(checkoutEntitlementsProvider);
        ref.read(purchaseNotificationsProvider.notifier).push(
              PurchaseNotification(
                type: PurchaseNotificationType.paymentSuccess,
                title: 'Payment successful',
                body: ents.isNotEmpty
                    ? '${ents.length} ticket(s) ready for check-in.'
                    : 'Your payment was confirmed.',
                orderId: widget.orderId,
              ),
            );
        ref.read(purchaseNotificationsProvider.notifier).push(
              PurchaseNotification(
                type: PurchaseNotificationType.ticketReady,
                title: 'Tickets ready',
                body: 'Your digital pass is available in My Tickets.',
                orderId: widget.orderId,
              ),
            );
        ref.read(purchaseNotificationsProvider.notifier).push(
              PurchaseNotification(
                type: PurchaseNotificationType.purchaseConfirmation,
                title: 'Purchase confirmed',
                body: 'Order ${widget.orderId} is confirmed.',
                orderId: widget.orderId,
              ),
            );
        ref.read(purchaseNotificationsProvider.notifier).push(
              PurchaseNotification(
                type: PurchaseNotificationType.registrationConfirmation,
                title: 'Registration confirmed',
                body: 'You are registered for your event.',
                orderId: widget.orderId,
              ),
            );
        if (!mounted) return;
        context.go('${AttendeeRoutes.paymentSuccess}?orderId=${widget.orderId}');
        return;
      }

      if (TicketCheckoutCoordinator.isOrderFailed(order.status)) {
        _timer?.cancel();
        coordinator.notifyFailure(widget.orderId, 'Payment was cancelled or failed.');
        setState(() => _error = 'Payment was cancelled or failed. You can retry securely.');
      } else if (_ticks >= 40) {
        setState(() => _error = 'Still waiting for confirmation. You can retry or reopen payment.');
      }
    } on TicketCommerceApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopenHostedPay() async {
    final url = widget.clientActionUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _retryPayment() async {
    final session = ref.read(authSessionProvider);
    if (session == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final coordinator = TicketCheckoutCoordinator(ref);
      // Same payment idempotency key → duplicate payment protection on the API.
      final result = await coordinator.pay(
        session: session,
        cart: const [],
        existingOrderId: widget.orderId,
        orderIdempotencyKey: widget.orderIdempotencyKey,
        paymentIdempotencyKey: widget.paymentIdempotencyKey,
      );
      if (result.phase == TicketCheckoutPhase.captured) {
        if (!mounted) return;
        context.go('${AttendeeRoutes.paymentSuccess}?orderId=${result.orderId}');
        return;
      }
      if (result.clientActionUrl != null) {
        final uri = Uri.tryParse(result.clientActionUrl!);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      _ticks = 0;
      await _pollOnce();
    } on TicketCommerceApiException catch (e) {
      TicketCheckoutCoordinator(ref).notifyFailure(widget.orderId, e.message);
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Cancel payment',
      onBack: () {
        TicketCheckoutCoordinator(ref).notifyFailure(widget.orderId, 'Payment cancelled by user.');
        context.go(AttendeeRoutes.checkout);
      },
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(context.eos.spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EosSurfaceCard(
              elevated: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: CircularProgressIndicator()),
                  SizedBox(height: context.eos.spacing.md),
                  Text('Confirming payment', style: context.eosText.headlineSmall, textAlign: TextAlign.center),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    'Order ${widget.orderId}\nStatus: $_status',
                    style: context.eosText.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (offline) ...[
                    SizedBox(height: context.eos.spacing.sm),
                    const EosAttentionBanner(
                      headline: 'Offline',
                      message: 'Reconnect to refresh payment status.',
                      severity: 'WARNING',
                    ),
                  ],
                  if (_error != null) ...[
                    SizedBox(height: context.eos.spacing.sm),
                    EosAttentionBanner(headline: 'Payment update', message: _error!, severity: 'CRITICAL'),
                  ],
                  SizedBox(height: context.eos.spacing.lg),
                  if (widget.clientActionUrl != null)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _reopenHostedPay,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Reopen Quaser checkout'),
                    ),
                  SizedBox(height: context.eos.spacing.sm),
                  FilledButton(
                    onPressed: _busy ? null : _retryPayment,
                    child: const Text('Retry payment'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _pollOnce,
                    child: const Text('Check status now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
