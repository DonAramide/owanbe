import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/user_role.dart';
import '../../../eos/eos.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/workspace_models.dart';
import '../providers/public_providers.dart';

/// Shared navigation helpers for the public marketplace shell.
mixin PublicShellActions {
  void openDiscover(BuildContext context) => context.go('/events');

  void openMyTickets(BuildContext context, WidgetRef ref) {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      context.push(ExperienceNavigation.signInForRole(UserRole.client));
    } else {
      context.go(ExperienceNavigation.workspaceHome(ExperienceWorkspace.attendee));
    }
  }

  void openSignIn(BuildContext context) => context.push(ExperienceNavigation.universalAuth());
  void openCart(BuildContext context) => context.push('/checkout');
}

Widget buildPublicShell({
  required BuildContext context,
  required WidgetRef ref,
  required Widget child,
  String? activeNav,
  bool compact = false,
  bool? showSignIn,
}) {
  final cart = ref.watch(cartProvider);
  final count = cart.fold(0, (s, l) => s + l.quantity);
  final session = ref.watch(authSessionProvider);
  final showAuthCta = showSignIn ?? session == null;
  return EosPublicShell(
    activeNav: activeNav,
    cartCount: count,
    compact: compact,
    onDiscover: () => context.go('/events'),
    onMyTickets: () {
      if (session == null) {
        context.push(ExperienceNavigation.signInForRole(UserRole.client));
      } else {
        context.go(ExperienceNavigation.workspaceHome(ExperienceWorkspace.attendee));
      }
    },
    onSignIn: showAuthCta ? () => context.push(ExperienceNavigation.universalAuth()) : null,
    onCart: count > 0 ? () => context.push('/checkout') : null,
    body: child,
  );
}
