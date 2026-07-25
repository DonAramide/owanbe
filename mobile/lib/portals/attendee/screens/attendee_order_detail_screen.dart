import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/ticket_commerce_api.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/ticket_commerce_providers.dart';
import '../commerce/ticket_checkout_coordinator.dart';
import '../navigation/attendee_routes.dart';
import '../widgets/attendee_flow_scaffold.dart';

class AttendeeOrderDetailScreen extends ConsumerStatefulWidget {
  const AttendeeOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<AttendeeOrderDetailScreen> createState() => _AttendeeOrderDetailScreenState();
}

class _AttendeeOrderDetailScreenState extends ConsumerState<AttendeeOrderDetailScreen> {
  TicketOrderResponse? _order;
  List<TicketRefundCaseResponse> _refunds = const [];
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to view this order.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(ticketCommerceApiProvider);
      final order = await api.getTicketOrder(session: session, orderId: widget.orderId);
      List<TicketRefundCaseResponse> refunds = const [];
      try {
        refunds = await api.listOrderRefunds(session: session, orderId: widget.orderId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _order = order;
        _refunds = refunds;
        _loading = false;
      });
    } on TicketCommerceApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _requestRefund() async {
    final session = ref.read(authSessionProvider);
    final order = _order;
    if (session == null || order == null || _busy) return;
    final amount = order.subtotalMinor ?? order.totalMinor;
    setState(() => _busy = true);
    try {
      await ref.read(ticketCommerceApiProvider).requestRefund(
            session: session,
            orderId: order.orderId,
            amountMinor: amount,
            reason: 'Buyer requested refund from purchase history',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund request submitted')),
      );
      await _load();
    } on TicketCommerceApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redownloadTickets() async {
    final session = ref.read(authSessionProvider);
    if (session == null || _busy) return;
    setState(() => _busy = true);
    try {
      await TicketCheckoutCoordinator(ref).refreshEntitlementsAfterSuccess(session);
      ref.invalidate(attendeeTicketsSyncProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tickets refreshed — open My Tickets for QR passes')),
      );
    } on TicketCommerceApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AttendeeFlowScaffold(
      backLabel: 'Orders',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.orders),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  padding: EdgeInsets.all(context.eos.spacing.lg),
                  children: [
                    EosAttentionBanner(headline: 'Order unavailable', message: _error!, severity: 'CRITICAL'),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                )
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final order = _order!;
    final paid = TicketCheckoutCoordinator.isOrderPaid(order.status);
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        Text(order.eventTitle ?? 'Order details', style: context.eosText.headlineMedium),
        SizedBox(height: context.eos.spacing.xs),
        Text('Status: ${order.status ?? 'unknown'}', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.lg),
        EosSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total ${ngnFromMinor(order.totalMinor)}', style: context.eosText.titleMedium),
              if (order.subtotalMinor != null)
                Text('Subtotal ${ngnFromMinor(order.subtotalMinor!)}', style: context.eosText.bodySmall),
              if (order.platformFeeMinor != null)
                Text('Platform fee ${ngnFromMinor(order.platformFeeMinor!)}', style: context.eosText.bodySmall),
              if (order.createdAt != null)
                Text(order.createdAt!.toLocal().toString().split('.').first, style: context.eosText.labelSmall),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Text('Line items', style: context.eosText.titleMedium),
        SizedBox(height: context.eos.spacing.sm),
        for (final line in order.lines) ...[
          EosSurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: Text('${line.tierName} × ${line.quantity}', style: context.eosText.bodyMedium),
                ),
                Text(ngnFromMinor(line.lineSubtotalMinor), style: context.eosText.labelLarge),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
        ],
        SizedBox(height: context.eos.spacing.md),
        Text('Refund status', style: context.eosText.titleMedium),
        SizedBox(height: context.eos.spacing.sm),
        if (_refunds.isEmpty)
          EosSurfaceCard(
            child: Text(
              paid ? 'No refund requests for this order.' : 'Refunds become available after payment is confirmed.',
              style: context.eosText.bodyMedium,
            ),
          )
        else
          for (final r in _refunds) ...[
            EosSurfaceCard(
              child: Text(
                '${r.status} · ${ngnFromMinor(r.amountMinor)}${r.reason != null ? ' · ${r.reason}' : ''}',
                style: context.eosText.bodyMedium,
              ),
            ),
            SizedBox(height: context.eos.spacing.sm),
          ],
        SizedBox(height: context.eos.spacing.lg),
        FilledButton.icon(
          onPressed: _busy ? null : _redownloadTickets,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Re-download tickets'),
        ),
        SizedBox(height: context.eos.spacing.sm),
        if (paid)
          OutlinedButton.icon(
            onPressed: _busy ? null : _requestRefund,
            icon: const Icon(Icons.money_off_outlined, size: 18),
            label: const Text('Request refund'),
          ),
        TextButton(
          onPressed: () => context.go(AttendeeRoutes.dashboard),
          child: const Text('Open My Tickets'),
        ),
      ],
    );
  }
}
