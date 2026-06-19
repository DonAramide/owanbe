import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../providers/public_providers.dart';

/// Shared navigation helpers for the public marketplace shell.
mixin PublicShellActions {
  void openDiscover(BuildContext context) => context.go('/events');
  void openMyTickets(BuildContext context, WidgetRef ref) {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      context.push('/auth?return=/attendee');
    } else {
      context.go('/attendee');
    }
  }

  void openSignIn(BuildContext context) => context.push('/auth');
  void openCart(BuildContext context) => context.push('/checkout');
}

Widget buildPublicShell({
  required BuildContext context,
  required WidgetRef ref,
  required Widget child,
  String? activeNav,
  bool compact = false,
}) {
  final cart = ref.watch(cartProvider);
  final count = cart.fold(0, (s, l) => s + l.quantity);
  return EosPublicShell(
    activeNav: activeNav,
    cartCount: count,
    compact: compact,
    onDiscover: () => context.go('/events'),
    onMyTickets: () {
      final session = ref.read(authSessionProvider);
      if (session == null) {
        context.push('/auth?return=/attendee');
      } else {
        context.go('/attendee');
      }
    },
    onSignIn: () => context.push('/auth'),
    onCart: count > 0 ? () => context.push('/checkout') : null,
    body: child,
  );
}
