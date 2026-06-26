import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';
import '../layout/eos_responsive.dart';
import '../tokens/eos_colors.dart';
import '../tokens/eos_spacing.dart';
import '../widgets/owanbe_logo.dart';

/// Marketing / marketplace shell — distinct from operational [EosAppShell].
class EosPublicShell extends StatelessWidget {
  const EosPublicShell({
    super.key,
    required this.body,
    this.activeNav,
    this.onDiscover,
    this.onMyTickets,
    this.onSignIn,
    this.cartCount = 0,
    this.onCart,
    this.compact = false,
  });

  final Widget body;
  final String? activeNav;
  final VoidCallback? onDiscover;
  final VoidCallback? onMyTickets;
  final VoidCallback? onSignIn;
  final int cartCount;
  final VoidCallback? onCart;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isMobile = EosResponsive.isMobile(context);
    return Scaffold(
      body: Column(
        children: [
          _PublicHeader(
            isMobile: isMobile,
            activeNav: activeNav,
            onDiscover: onDiscover,
            onMyTickets: onMyTickets,
            onSignIn: onSignIn,
            cartCount: cartCount,
            onCart: onCart,
            compact: compact,
          ),
          Expanded(child: body),
          if (!compact && !isMobile) const _PublicFooter(),
        ],
      ),
    );
  }
}

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({
    required this.isMobile,
    this.activeNav,
    this.onDiscover,
    this.onMyTickets,
    this.onSignIn,
    this.cartCount = 0,
    this.onCart,
    this.compact = false,
  });

  final bool isMobile;
  final String? activeNav;
  final VoidCallback? onDiscover;
  final VoidCallback? onMyTickets;
  final VoidCallback? onSignIn;
  final int cartCount;
  final VoidCallback? onCart;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.eosColors.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? EosSpacing.md : EosSpacing.xl,
            vertical: EosSpacing.sm,
          ),
          child: Row(
            children: [
              const OwanbeLogo(size: 28),
              SizedBox(width: context.eos.spacing.xs),
              Text('Owanbe', style: context.eosText.titleLarge?.copyWith(color: EosColors.plum)),
              if (!isMobile) ...[
                SizedBox(width: context.eos.spacing.xxl),
                _NavLink(label: 'Discover', active: activeNav == 'discover', onTap: onDiscover),
                SizedBox(width: context.eos.spacing.lg),
                _NavLink(label: 'My tickets', active: activeNav == 'tickets', onTap: onMyTickets),
              ],
              const Spacer(),
              if (onCart != null)
                IconButton(
                  onPressed: onCart,
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              if (!compact && onSignIn != null) ...[
                SizedBox(width: context.eos.spacing.xs),
                OutlinedButton(onPressed: onSignIn, child: const Text('Sign in')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap, this.active = false});
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: context.eosText.labelLarge?.copyWith(
          color: active ? context.eosColors.primary : context.eosColors.onSurfaceVariant,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _PublicFooter extends StatelessWidget {
  const _PublicFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: EosSpacing.lg, horizontal: EosSpacing.xl),
      decoration: BoxDecoration(
        color: EosColors.plumDark,
      ),
      child: Text(
        '© ${DateTime.now().year} Owanbe · Event Operating System',
        style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
    );
  }
}
