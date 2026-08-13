import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../screens/organizer_profile_edit_sheet.dart';
import 'organizer_team_api.dart';

final _teamSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _teamRoleFilterProvider = StateProvider.autoDispose<String>((ref) => '');
final _teamStatusFilterProvider = StateProvider.autoDispose<String>((ref) => '');

/// Phase 22 — Organization & Team hub (profile + directory + activity).
class OrganizationTeamScreen extends ConsumerWidget {
  const OrganizationTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(organizerTeamDirectoryProvider);
    final activity = ref.watch(organizerTeamActivityProvider);
    final q = ref.watch(_teamSearchProvider);
    final role = ref.watch(_teamRoleFilterProvider);
    final status = ref.watch(_teamStatusFilterProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(organizerTeamDirectoryProvider);
        ref.invalidate(organizerTeamActivityProvider);
      },
      child: ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          Semantics(
            header: true,
            child: Text('Organization & Team', style: context.eosText.headlineSmall),
          ),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Delegate access without sharing the owner account. '
            'Roles overlay portal RBAC — Authentication and Workspace Switching are unchanged.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.lg),
          directory.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => EosAttentionBanner(
              headline: 'Team unavailable',
              message: '$e',
              severity: 'WARNING',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(organizerTeamDirectoryProvider),
            ),
            data: (dir) => Text(
              dir.organizationName.isEmpty ? 'Your organization' : dir.organizationName,
              style: context.eosText.titleMedium,
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Wrap(
            spacing: context.eos.spacing.sm,
            runSpacing: context.eos.spacing.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => showOrganizerProfileEditor(context, ref),
                icon: const Icon(Icons.business_outlined, size: 18),
                label: const Text('Organization profile & branding'),
              ),
              FilledButton.icon(
                onPressed: () => _showInviteSheet(context, ref),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Invite member'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAcceptSheet(context, ref),
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                label: const Text('Accept invite'),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.xl),
          Text('Staff directory', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search',
              hintText: 'Name or email',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => ref.read(_teamSearchProvider.notifier).state = v.trim(),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: context.eos.spacing.sm,
            children: [
              FilterChip(
                label: const Text('All roles'),
                selected: role.isEmpty,
                onSelected: (_) => ref.read(_teamRoleFilterProvider.notifier).state = '',
              ),
              for (final r in ['owner', 'admin', 'manager', 'staff'])
                FilterChip(
                  label: Text(r),
                  selected: role == r,
                  onSelected: (_) =>
                      ref.read(_teamRoleFilterProvider.notifier).state = role == r ? '' : r,
                ),
            ],
          ),
          Wrap(
            spacing: context.eos.spacing.sm,
            children: [
              FilterChip(
                label: const Text('All status'),
                selected: status.isEmpty,
                onSelected: (_) => ref.read(_teamStatusFilterProvider.notifier).state = '',
              ),
              for (final s in ['owner', 'active', 'pending', 'revoked'])
                FilterChip(
                  label: Text(s),
                  selected: status == s,
                  onSelected: (_) =>
                      ref.read(_teamStatusFilterProvider.notifier).state = status == s ? '' : s,
                ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          directory.when(
            loading: () => const _TeamSkeleton(),
            error: (e, _) => EosAttentionBanner(
              headline: 'Directory unavailable',
              message: '$e',
              severity: 'WARNING',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(organizerTeamDirectoryProvider),
            ),
            data: (dir) {
              final items = dir.items.where((m) {
                if (q.isNotEmpty) {
                  final hay = '${m.email} ${m.displayName ?? ''}'.toLowerCase();
                  if (!hay.contains(q.toLowerCase())) return false;
                }
                if (role.isNotEmpty && m.orgRole != role) return false;
                if (status.isNotEmpty) {
                  if (status == 'owner' && !m.isOwner) return false;
                  if (status != 'owner' && m.status != status) return false;
                }
                return true;
              }).toList();
              if (items.isEmpty) {
                return Text('No members match filters.', style: context.eosText.bodySmall);
              }
              return Column(
                children: [
                  for (final m in items) ...[
                    _MemberTile(member: m),
                    SizedBox(height: context.eos.spacing.sm),
                  ],
                ],
              );
            },
          ),
          SizedBox(height: context.eos.spacing.xl),
          Text('Team activity', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          activity.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Text('$e', style: context.eosText.bodySmall),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No team activity yet. Invites and role changes appear here.',
                  style: context.eosText.bodySmall,
                );
              }
              return Column(
                children: [
                  for (final a in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(a.label),
                      subtitle: Text(
                        [
                          if (a.actorEmail != null && a.actorEmail!.isNotEmpty) a.actorEmail!,
                          a.createdAt,
                        ].join(' · '),
                      ),
                      dense: true,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showInviteSheet(BuildContext context, WidgetRef ref) async {
    final emailCtrl = TextEditingController();
    var orgRole = 'staff';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Invite team member', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: orgRole,
                    decoration: const InputDecoration(labelText: 'Organization role'),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    ],
                    onChanged: (v) => setLocal(() => orgRole = v ?? 'staff'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Send invite'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true || !context.mounted) return;
    try {
      final member = await ref.read(organizerTeamApiProvider).invite(
            email: emailCtrl.text.trim(),
            orgRole: orgRole,
            session: ref.read(authSessionProvider),
          );
      ref.invalidate(organizerTeamDirectoryProvider);
      ref.invalidate(organizerTeamActivityProvider);
      if (!context.mounted) return;
      if (member.inviteToken != null && member.inviteToken!.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: member.inviteToken!));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            member.inviteToken == null
                ? 'Invite sent to ${member.email} as ${member.orgRole}'
                : 'Invite sent to ${member.email}. Token copied to clipboard.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showAcceptSheet(BuildContext context, WidgetRef ref) async {
    final tokenCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept team invite'),
        content: TextField(
          controller: tokenCtrl,
          decoration: const InputDecoration(
            labelText: 'Invite token',
            hintText: 'Paste token from invite',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(organizerTeamApiProvider).acceptInvite(
            token: tokenCtrl.text.trim(),
            session: ref.read(authSessionProvider),
          );
      ref.invalidate(organizerTeamDirectoryProvider);
      ref.invalidate(organizerTeamActivityProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite accepted — organizer access granted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});
  final OrganizerMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.eosColors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.md),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                (member.displayName ?? member.email).isNotEmpty
                    ? (member.displayName ?? member.email)[0].toUpperCase()
                    : '?',
              ),
            ),
            SizedBox(width: context.eos.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName?.isNotEmpty == true ? member.displayName! : member.email,
                    style: context.eosText.titleSmall,
                  ),
                  Text(member.email, style: context.eosText.bodySmall),
                  SizedBox(height: context.eos.spacing.xs),
                  Wrap(
                    spacing: 6,
                    children: [
                      Chip(
                        label: Text(member.orgRole),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(member.status),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!member.isOwner && member.status != 'revoked')
              PopupMenuButton<String>(
                onSelected: (v) => _onAction(context, ref, v),
                itemBuilder: (_) => [
                  if (member.status == 'pending' || member.status == 'active') ...[
                    const PopupMenuItem(value: 'admin', child: Text('Set Admin')),
                    const PopupMenuItem(value: 'manager', child: Text('Set Manager')),
                    const PopupMenuItem(value: 'staff', child: Text('Set Staff')),
                    const PopupMenuItem(value: 'revoke', child: Text('Remove')),
                  ],
                  if (member.status == 'pending')
                    const PopupMenuItem(value: 'copy', child: Text('Copy member id')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String action) async {
    final api = ref.read(organizerTeamApiProvider);
    final session = ref.read(authSessionProvider);
    try {
      if (action == 'revoke') {
        await api.revoke(memberId: member.id, session: session);
      } else if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: member.id));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member id copied')));
        }
        return;
      } else {
        await api.updateRole(memberId: member.id, orgRole: action, session: session);
      }
      ref.invalidate(organizerTeamDirectoryProvider);
      ref.invalidate(organizerTeamActivityProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _TeamSkeleton extends StatelessWidget {
  const _TeamSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: context.eosColors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
