import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../../features/workspace/widgets/workspace_experience_shell.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../theme/theme_mode_provider.dart';
import '../navigation/attendee_routes.dart';
import '../screens/attendee_profile_card_sheet.dart';

/// Responsive attendee workspace header — no overflow on narrow devices.
class AttendeeTopBar extends ConsumerWidget {
  const AttendeeTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final identity = ref.watch(userIdentityProvider).valueOrNull;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final name = identity?.displayName ?? session?.displayName ?? 'Guest';
    final avatarUrl = identity?.avatarUrl;
    final compact = EosResponsive.isCompact(context);

    return Material(
      color: context.eosColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.eos.spacing.lg,
            vertical: context.eos.spacing.sm,
          ),
          child: compact
              ? _CompactLayout(
                  isDark: isDark,
                  name: name,
                  avatarUrl: avatarUrl,
                  ref: ref,
                )
              : _WideLayout(
                  isDark: isDark,
                  name: name,
                  avatarUrl: avatarUrl,
                  ref: ref,
                ),
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.isDark,
    required this.name,
    required this.avatarUrl,
    required this.ref,
  });

  final bool isDark;
  final String name;
  final String? avatarUrl;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Attendee Workspace',
            style: context.eosText.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _ThemeToggle(isDark: isDark, ref: ref),
        EosAttendeeChip(
          name: name,
          compact: true,
          avatarUrl: avatarUrl,
          onTap: () => showAttendeeProfileCard(context, ref),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Edit Attendee Profile',
          onPressed: () => context.push(AttendeeRoutes.profile),
          icon: const Icon(Icons.manage_accounts_outlined),
        ),
        const WorkspaceContextActions(),
        _SignOutButton(ref: ref),
      ],
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.isDark,
    required this.name,
    required this.avatarUrl,
    required this.ref,
  });

  final bool isDark;
  final String name;
  final String? avatarUrl;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Attendee',
                style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _ThemeToggle(isDark: isDark, ref: ref),
            _SignOutButton(ref: ref),
          ],
        ),
        SizedBox(height: context.eos.spacing.xs),
        Row(
          children: [
            EosAttendeeChip(
              name: name,
              compact: true,
              avatarUrl: avatarUrl,
              onTap: () => showAttendeeProfileCard(context, ref),
            ),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit Attendee Profile',
              onPressed: () => context.push(AttendeeRoutes.profile),
              icon: const Icon(Icons.manage_accounts_outlined, size: 20),
            ),
            _CompactWorkspaceActions(ref: ref),
          ],
        ),
      ],
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDark, required this.ref});

  final bool isDark;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => ref.read(themeModeProvider.notifier).toggleLightDark(),
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Sign out',
      onPressed: () {
        ref.read(authSessionProvider.notifier).signOut();
        context.go(ExperienceNavigation.afterSignOut());
      },
      icon: const Icon(Icons.logout),
    );
  }
}

class _CompactWorkspaceActions extends StatelessWidget {
  const _CompactWorkspaceActions({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return const WorkspaceContextActions();
  }
}
