import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/auth_session.dart';
import '../../../core/api/ticket_commerce_api.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/public_models.dart';
import '../providers/public_providers.dart';
import '../providers/ticket_commerce_providers.dart';
import '../widgets/public_shell_mixin.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _processing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final session = ref.watch(authSessionProvider);
    final total = cart.fold(0, (sum, l) => sum + l.lineTotalMinor);

    if (cart.isEmpty) {
      return buildPublicShell(
        context: context,
        ref: ref,
        compact: true,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.eos.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 48, color: context.eosColors.outline),
                SizedBox(height: context.eos.spacing.md),
                Text('Your cart is empty', style: context.eosText.titleMedium),
                SizedBox(height: context.eos.spacing.sm),
                FilledButton(onPressed: () => context.go('/events'), child: const Text('Discover events')),
              ],
            ),
          ),
        ),
      );
    }

    return buildPublicShell(
      context: context,
      ref: ref,
      compact: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: EosResponsive(
          mobile: _CheckoutBody(
            cart: cart,
            total: total,
            session: session,
            processing: _processing,
            error: _error,
            onPay: () => _pay(session),
          ),
          tablet: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _CheckoutBody(
                cart: cart,
                total: total,
                session: session,
                processing: _processing,
                error: _error,
                onPay: () => _pay(session),
              ),
            ),
          ),
          desktop: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _CheckoutBody(
                cart: cart,
                total: total,
                session: session,
                processing: _processing,
                error: _error,
                onPay: () => _pay(session),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pay(AuthSession? session) async {
    if (session == null) {
      context.push('/auth?return=/checkout');
      return;
    }
    if (_processing) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final cart = ref.read(cartProvider);
      final api = ref.read(ticketCommerceApiProvider);
      final eventId = cart.first.eventId;
      final currency = cart.first.currency;
      final idem = 'checkout_${DateTime.now().millisecondsSinceEpoch}';

      final order = await api.createTicketOrder(
        session: session,
        eventId: eventId,
        currency: currency,
        items: [
          for (final line in cart)
            {'tierId': line.tierId, 'quantity': line.quantity},
        ],
        idempotencyKey: idem,
      );

      final payment = await api.createTicketPayment(
        session: session,
        orderId: order.orderId,
        idempotencyKey: '${idem}_pay',
      );

      ref.read(cartProvider.notifier).clear();
      ref.read(checkoutEntitlementsProvider.notifier).set(payment.entitlements);

      if (mounted) {
        context.go('/payment/success?orderId=${order.orderId}');
      }
    } on TicketCommerceApiException catch (e) {
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
    required this.error,
    required this.onPay,
  });

  final List<CartLine> cart;
  final int total;
  final AuthSession? session;
  final bool processing;
  final String? error;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Checkout', style: context.eosText.headlineMedium),
        SizedBox(height: context.eos.spacing.lg),
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
        ],
        EosSection(
          title: 'Contact',
          child: session != null
              ? EosSurfaceCard(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(session!.displayName[0])),
                    title: Text(session!.displayName),
                    subtitle: const Text('Signed in'),
                  ),
                )
              : EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign in to complete your purchase', style: context.eosText.bodyMedium),
                      SizedBox(height: context.eos.spacing.sm),
                      OutlinedButton(
                        onPressed: () => context.push('/auth?return=/checkout'),
                        child: const Text('Sign in or create account'),
                      ),
                    ],
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
                onPressed: processing ? null : onPay,
                child: processing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(session != null ? 'Pay securely' : 'Sign in to pay'),
              ),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.sm),
        Text(
          'Real ticket commerce — payment captured via Owanbe API.',
          style: context.eosText.bodySmall,
        ),
      ],
    );
  }
}
