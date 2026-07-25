import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../features/home/widgets/hub_global_profile_edit_sheet.dart';
import '../../../identity/identity_provider.dart';
import '../../../profile/widgets/profile_network_avatar.dart';
import '../models/attendee_profile.dart';
import '../models/attendee_profile_card.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_profile_providers.dart';

final attendeeProfileCardProvider =
    FutureProvider.autoDispose.family<AttendeeProfileCard, String?>((ref, userId) async {
  final api = ref.watch(identityApiProvider);
  final json = await api.fetchAttendeeProfileCard(userId: userId);
  return AttendeeProfileCard.fromJson(json);
});

Future<void> showAttendeeProfileCard(
  BuildContext context,
  WidgetRef ref, {
  String? userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return AttendeeProfileCardSheet(
            userId: userId,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class AttendeeProfileCardSheet extends ConsumerWidget {
  const AttendeeProfileCardSheet({
    super.key,
    this.userId,
    this.scrollController,
  });

  final String? userId;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardAsync = ref.watch(attendeeProfileCardProvider(userId));

    return cardAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: EosSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load profile: $e'),
              SizedBox(height: context.eos.spacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(attendeeProfileCardProvider(userId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (card) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            context.eos.spacing.lg,
            context.eos.spacing.sm,
            context.eos.spacing.lg,
            context.eos.spacing.xl,
          ),
          children: [
            Row(
              children: [
                ProfileNetworkAvatar(
                  name: card.displayName,
                  avatarUrl: card.avatarUrl,
                  radius: 36,
                ),
                SizedBox(width: context.eos.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.displayName, style: context.eosText.titleLarge),
                      if (card.preferredDisplayName != null &&
                          card.preferredDisplayName!.trim().isNotEmpty &&
                          card.preferredDisplayName != card.displayName)
                        Text(
                          card.preferredDisplayName!,
                          style: context.eosText.bodySmall,
                        ),
                      if (!card.visible)
                        Text(
                          card.visibilityReason ?? 'Profile is private.',
                          style: context.eosText.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (card.isSelf) ...[
              SizedBox(height: context.eos.spacing.lg),
              Text('Who can see this profile', style: context.eosText.titleSmall),
              SizedBox(height: context.eos.spacing.xs),
              Text(
                'Control visibility for other people in the Attendee workspace.',
                style: context.eosText.bodySmall,
              ),
              SizedBox(height: context.eos.spacing.sm),
              _AttendeePrivacyToggles(
                showToOrganizers: card.privacyShowToOrganizers,
                showToAttendees: card.privacyShowToAttendees,
                onSaved: () {
                  ref.invalidate(attendeeProfileCardProvider(userId));
                  ref.invalidate(attendeeProfileProvider);
                },
              ),
            ],
            if (card.visible) ...[
              SizedBox(height: context.eos.spacing.lg),
              if ((card.occupation?.isNotEmpty ?? false) || (card.company?.isNotEmpty ?? false)) ...[
                Text('Professional', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xs),
                Text(
                  [
                    if (card.occupation?.trim().isNotEmpty ?? false) card.occupation!.trim(),
                    if (card.company?.trim().isNotEmpty ?? false) card.company!.trim(),
                  ].join(' · '),
                  style: context.eosText.bodyMedium,
                ),
                SizedBox(height: context.eos.spacing.md),
              ],
              if (card.bio != null && card.bio!.trim().isNotEmpty) ...[
                Text('About', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xs),
                Text(card.bio!, style: context.eosText.bodyMedium),
                SizedBox(height: context.eos.spacing.md),
              ],
              if (card.interests.isNotEmpty) ...[
                Text('Interests', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                Wrap(
                  spacing: context.eos.spacing.xs,
                  runSpacing: context.eos.spacing.xs,
                  children: [
                    for (final i in card.interests) Chip(label: Text(i)),
                  ],
                ),
                SizedBox(height: context.eos.spacing.md),
              ],
              if (card.preferredEventCategories.isNotEmpty) ...[
                Text('Preferred events', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                Wrap(
                  spacing: context.eos.spacing.xs,
                  runSpacing: context.eos.spacing.xs,
                  children: [
                    for (final i in card.preferredEventCategories) Chip(label: Text(i)),
                  ],
                ),
                SizedBox(height: context.eos.spacing.md),
              ],
              if ((card.accessibilityRequirements?.trim().isNotEmpty ?? false) ||
                  (card.dietaryPreferences?.trim().isNotEmpty ?? false)) ...[
                Text('Event needs', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xs),
                if (card.accessibilityRequirements?.trim().isNotEmpty ?? false)
                  Text('Accessibility: ${card.accessibilityRequirements}', style: context.eosText.bodyMedium),
                if (card.dietaryPreferences?.trim().isNotEmpty ?? false)
                  Text('Dietary: ${card.dietaryPreferences}', style: context.eosText.bodyMedium),
                SizedBox(height: context.eos.spacing.md),
              ],
            ],
            if (card.isSelf) ...[
              SizedBox(height: context.eos.spacing.md),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AttendeeRoutes.profile);
                },
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: const Text('Edit Attendee Profile'),
              ),
              SizedBox(height: context.eos.spacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await showHubGlobalProfileEditor(context, ref);
                  ref.invalidate(userIdentityProvider);
                  ref.invalidate(attendeeProfileCardProvider(userId));
                },
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Edit Global Profile'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AttendeePrivacyToggles extends ConsumerStatefulWidget {
  const _AttendeePrivacyToggles({
    required this.showToOrganizers,
    required this.showToAttendees,
    required this.onSaved,
  });

  final bool showToOrganizers;
  final bool showToAttendees;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AttendeePrivacyToggles> createState() => _AttendeePrivacyTogglesState();
}

class _AttendeePrivacyTogglesState extends ConsumerState<_AttendeePrivacyToggles> {
  late bool _showToOrganizers = widget.showToOrganizers;
  late bool _showToAttendees = widget.showToAttendees;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _AttendeePrivacyToggles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving) {
      _showToOrganizers = widget.showToOrganizers;
      _showToAttendees = widget.showToAttendees;
    }
  }

  Future<void> _persist({
    required bool organizers,
    required bool attendees,
  }) async {
    final prevOrganizers = _showToOrganizers;
    final prevAttendees = _showToAttendees;
    setState(() {
      _showToOrganizers = organizers;
      _showToAttendees = attendees;
      _saving = true;
    });

    try {
      await ref.read(attendeeProfileRepositoryProvider).save(
            AttendeeProfileUpdate(
              privacyShowToOrganizers: organizers,
              privacyShowToAttendees: attendees,
            ),
          );
      if (!mounted) return;
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showToOrganizers = prevOrganizers;
        _showToAttendees = prevAttendees;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update privacy: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show to organizers'),
            subtitle: const Text('Event hosts can see your attendee card'),
            value: _showToOrganizers,
            onChanged: _saving
                ? null
                : (v) => _persist(organizers: v, attendees: _showToAttendees),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show to other attendees'),
            subtitle: const Text('Peers can open your profile from attendee lists'),
            value: _showToAttendees,
            onChanged: _saving
                ? null
                : (v) => _persist(organizers: _showToOrganizers, attendees: v),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
