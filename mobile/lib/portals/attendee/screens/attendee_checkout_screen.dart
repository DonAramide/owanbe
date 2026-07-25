import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/auth_session.dart';
import '../../../core/api/ticket_commerce_api.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../features/public/providers/public_providers.dart';
import '../commerce/ticket_checkout_coordinator.dart';
import '../navigation/attendee_routes.dart';
import '../widgets/attendee_flow_scaffold.dart';

/// Checkout inside the Attendee Workspace.
class AttendeeCheckoutScreen extends ConsumerStatefulWidget {
  const AttendeeCheckoutScreen({super.key});

  @override
  ConsumerState<AttendeeCheckoutScreen> createState() => _AttendeeCheckoutScreenState();
}

class _AttendeeCheckoutScreenState extends ConsumerState<AttendeeCheckoutScreen> {
  bool _processing = false;
  String? _error;
  String? _orderIdem;
  String? _payIdem;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final session = ref.watch(authSessionProvider);
    final offline = ref.watch(attendeeOfflineProvider);
    final total = cart.fold(0, (sum, l) => sum + l.lineTotalMinor);

    if (cart.isEmpty) {
      return AttendeeFlowScaffold(
        backLabel: 'Back to tickets',
        onBack: () => context.go(AttendeeRoutes.dashboard),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.eos.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 48, color: context.eosColors.outline),
                SizedBox(height: context.eos.spacing.md),
                Text('Your cart is empty', style: context.eosText.titleMedium),
                SizedBox(height: context.eos.spacing.sm),
                FilledButton(
                  onPressed: () => context.go(AttendeeRoutes.dashboard),
                  child: const Text('Back to attendee home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AttendeeFlowScaffold(
      backLabel: 'Back to tickets',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: _CheckoutBody(
          cart: cart,
          total: total,
          session: session,
          processing: _processing,
          offline: offline,
          error: _error,
          onPay: () => _pay(session),
        ),
      ),
    );
  }

  Future<void> _pay(AuthSession? session) async {
    if (session == null || _processing) return;
    if (ref.read(attendeeOfflineProvider)) {
      setState(() => _error = 'You are offline. Reconnect to complete payment.');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      _orderIdem ??= 'checkout_${DateTime.now().millisecondsSinceEpoch}';
      _payIdem ??= '${_orderIdem}_pay';

      final result = await TicketCheckoutCoordinator(ref).pay(
        session: session,
        cart: ref.read(cartProvider),
        orderIdempotencyKey: _orderIdem,
        paymentIdempotencyKey: _payIdem,
      );

      if (!mounted) return;

      switch (result.phase) {
        case TicketCheckoutPhase.captured:
          context.go('${AttendeeRoutes.paymentSuccess}?orderId=${result.orderId}');
        case TicketCheckoutPhase.awaitingHostedPayment:
        case TicketCheckoutPhase.awaitingCapture:
          final q = <String, String>{
            'orderId': result.orderId,
            if (result.clientActionUrl != null) 'payUrl': result.clientActionUrl!,
            if (result.idempotencyKey != null) 'orderIdem': result.idempotencyKey!,
            if (result.paymentIdempotencyKey != null) 'payIdem': result.paymentIdempotencyKey!,
          };
          context.go(Uri(path: AttendeeRoutes.paymentPending, queryParameters: q).toString());
        case TicketCheckoutPhase.failed:
          setState(() => _error = result.message ?? 'Payment failed');
      }
    } on TicketCommerceApiException catch (e) {
      TicketCheckoutCoordinator(ref).notifyFailure('', e.message);
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

class _CheckoutBody extends StatelessWidget {
  const _CheckoutBody({
    required this.cart,
    required this.total,
    required this.session,
    required this.processing,
    required this.offline,
    required this.error,
    required this.onPay,
  });

  final List<CartLine> cart;
  final int total;
  final AuthSession? session;
  final bool processing;
  final bool offline;
  final String? error;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Checkout', style: context.eosText.headlineMedium),
        SizedBox(height: context.eos.spacing.lg),
        if (offline)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.md),
            child: const EosAttentionBanner(
              headline: 'Offline',
              message: 'Payment requires a network connection.',
              severity: 'WARNING',
            ),
          ),
        EosSection(
          title: 'Order summary',
          child: EosSurfaceCard(
            child: Column(
              children: [
                for (var i = 0; i < cart.length; i++) ...[
                  if (i > 0) Divider(height: context.eos.spacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cart[i].tierName, style: context.eosText.titleSmall),
                            Text(cart[i].eventTitle, style: context.eosText.bodySmall),
                            Text('Qty ${cart[i].quantity}', style: context.eosText.labelSmall),
                          ],
                        ),
                      ),
                      Text(
                        ngnFromMinor(cart[i].lineTotalMinor.toString()),
                        style: context.eosText.labelLarge,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (error != null) ...[
          SizedBox(height: context.eos.spacing.sm),
          EosAttentionBanner(headline: 'Checkout failed', message: error!, severity: 'CRITICAL'),
          TextButton(onPressed: processing ? null : onPay, child: const Text('Retry')),
        ],
        EosSection(
          title: 'Contact',
          child: EosSurfaceCard(
            child: ListTile(
              leading: CircleAvatar(child: Text(session!.displayName[0])),
              title: Text(session!.displayName),
              subtitle: const Text('Signed in'),
            ),
          ),
        ),
        EosSurfaceCard(
          elevated: true,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: context.eosText.labelMedium),
                  Text(ngnFromMinor(total.toString()), style: EosTypography.metric(context.eosColors)),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: (processing || offline) ? null : onPay,
                child: processing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Pay securely'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
