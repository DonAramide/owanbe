import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../identity/identity_provider.dart';
import '../../../identity/user_identity.dart';
import '../../../identity/workspace_models.dart';
import '../home_workspace_actions.dart';
import '../widgets/customer_home_design.dart';

/// Screen 2 — Join Owanbe As (Explore + ⋮ both land here).
class JoinOwanbeAsScreen extends ConsumerWidget {
  const JoinOwanbeAsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => const JoinOwanbeAsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  static const _roles = <ExperienceWorkspace, ({
    String title,
    String description,
    IconData icon,
    CustomerHomeRoleStyle style,
  })>{
    ExperienceWorkspace.attendee: (
      title: 'Attendee',
      description: 'Discover and attend amazing events.',
      icon: Icons.confirmation_number_outlined,
      style: CustomerHomeRoleStyle.attendee,
    ),
    ExperienceWorkspace.organizer: (
      title: 'Organizer',
      description: 'Create and manage exceptional events.',
      icon: Icons.celebration_outlined,
      style: CustomerHomeRoleStyle.organizer,
    ),
    ExperienceWorkspace.vendor: (
      title: 'Vendor',
      description: 'Offer your services and grow your business.',
      icon: Icons.storefront_outlined,
      style: CustomerHomeRoleStyle.vendor,
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(userIdentityProvider);

    return Scaffold(
      backgroundColor: CustomerHomeDesign.plumDeep,
      body: CustomerHomeBackground(
        blurBackground: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, CustomerHomeDesign.horizontalPad, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    // Visual match to concept; same destination as Explore (already here).
                    CustomerHomeThreeDotButton(onPressed: () {}),
                  ],
                ),
              ),
              Expanded(
                child: identityAsync.when(
                  loading: () => _RoleList(
                    identity: null,
                    onSelect: (ws, state) => openHomeWorkspace(context, ref, ws, state),
                  ),
                  // Design must remain visible even if API is down — cards still navigate.
                  error: (error, stackTrace) => _RoleList(
                    identity: null,
                    onSelect: (ws, state) => openHomeWorkspace(context, ref, ws, state),
                  ),
                  data: (identity) => _RoleList(
                    identity: identity,
                    onSelect: (ws, state) => openHomeWorkspace(context, ref, ws, state),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleList extends StatelessWidget {
  const _RoleList({
    required this.identity,
    required this.onSelect,
  });

  final OwanbeUserIdentity? identity;
  final void Function(ExperienceWorkspace ws, WorkspaceState state) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CustomerHomeDesign.horizontalPad,
        12,
        CustomerHomeDesign.horizontalPad,
        40,
      ),
      children: [
        const Text(
          'Join Owanbe As',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 34,
            letterSpacing: -0.5,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose how you want to get started',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 36),
        ...ExperienceWorkspace.values.map((ws) {
          final meta = JoinOwanbeAsScreen._roles[ws]!;
          final state = identity?.workspaceState(ws) ??
              WorkspaceState(workspace: ws, status: WorkspaceStatus.notActivated);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _JoinAsCard(
              icon: meta.icon,
              title: meta.title,
              description: meta.description,
              style: meta.style,
              onTap: () => onSelect(ws, state),
            ),
          );
        }),
      ],
    );
  }
}

class _JoinAsCard extends StatelessWidget {
  const _JoinAsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.style,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final CustomerHomeRoleStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: CustomerHomeDesign.plumCard.withValues(alpha: 0.58),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: style.iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: style.iconColor, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5), size: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
