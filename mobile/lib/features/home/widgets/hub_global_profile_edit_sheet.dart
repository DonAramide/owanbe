import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../identity/identity_provider.dart';
import '../../../profile/profile.dart';

const _kInterestOptions = <String>[
  'Music',
  'Weddings',
  'Business',
  'Networking',
  'Food',
  'Technology',
  'Fashion',
  'Travel',
  'Sports',
  'Arts',
  'Culture',
  'Nightlife',
];

/// Hub global profile editor — uses shared profile infrastructure.
Future<void> showHubGlobalProfileEditor(BuildContext context, WidgetRef ref) {
  return showProfileEditSheet(
    context: context,
    builder: (ctx, scrollController) => HubGlobalProfileEditSheet(
      scrollController: scrollController,
    ),
  );
}

class HubGlobalProfileEditSheet extends ConsumerStatefulWidget {
  const HubGlobalProfileEditSheet({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  ConsumerState<HubGlobalProfileEditSheet> createState() => _HubGlobalProfileEditSheetState();
}

class _HubGlobalProfileEditSheetState extends ConsumerState<HubGlobalProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _edit = ProfileEditController();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _displayName;
  late final TextEditingController _bio;
  late final TextEditingController _occupation;
  late final TextEditingController _company;
  late final Map<String, TextEditingController> _social;

  late ProfileAvatarValue _avatar;
  late Set<String> _interests;

  @override
  void initState() {
    super.initState();
    final identity = ref.read(userIdentityProvider).valueOrNull;
    _firstName = TextEditingController(text: identity?.firstNameField ?? '');
    _lastName = TextEditingController(text: identity?.lastNameField ?? '');
    _displayName = TextEditingController(text: identity?.displayName ?? '');
    _bio = TextEditingController(text: identity?.bio ?? '');
    _occupation = TextEditingController(text: identity?.occupation ?? '');
    _company = TextEditingController(text: identity?.company ?? '');
    _avatar = ProfileAvatarValue.fromRemote(identity?.avatarUrl);
    _interests = {...(identity?.interests ?? const <String>[])};
    _social = ProfileSocialLinksForm.createControllers(initial: identity?.socialLinks ?? const {});

    for (final c in [
      _firstName,
      _lastName,
      _displayName,
      _bio,
      _occupation,
      _company,
      ..._social.values,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() => _edit.markDirty();

  @override
  void dispose() {
    _edit.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _bio.dispose();
    _occupation.dispose();
    _company.dispose();
    ProfileSocialLinksForm.disposeControllers(_social);
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final interestsError = ProfileValidators.interests(_interests);
    if (interestsError != null) {
      _edit.setError(interestsError);
      return;
    }

    final repo = GlobalProfileRepositoryImpl(
      identityApi: ref.read(identityApiProvider),
      mediaUploader: ProfileMediaUploader(ref.read(mediaApiProvider)),
    );

    final ok = await _edit.runSave(() async {
      await repo.save(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        displayName: _displayName.text.trim(),
        bio: _bio.text.trim(),
        occupation: _occupation.text.trim(),
        company: _company.text.trim(),
        interests: _interests.toList()..sort(),
        socialLinks: ProfileSocialLinksForm.valuesOf(_social),
        avatar: _avatar,
      );
      await ref.read(userIdentityProvider.notifier).refresh();
    });

    if (!ok || !mounted) return;
    // Re-hydrate avatar from refreshed identity so editor + hub stay in sync.
    final refreshed = ref.read(userIdentityProvider).valueOrNull;
    if (refreshed?.avatarUrl != null) {
      _avatar = ProfileAvatarValue.fromRemote(refreshed!.avatarUrl);
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_edit.successMessage ?? 'Profile updated')),
    );
  }

  void _cancel() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final saving = _edit.isSaving;

    return ListenableBuilder(
      listenable: _edit,
      builder: (context, _) {
        return ProfileEditLayout(
          title: 'Edit profile',
          subtitle: 'Shared across Owanbe. Workspace profiles stay separate.',
          controller: _edit,
          formKey: _formKey,
          scrollController: widget.scrollController,
          onSave: _save,
          onCancel: _cancel,
          footer: kIsWeb
              ? Text(
                  'Tip: avatar upload works on web and mobile via gallery picker.',
                  style: context.eosText.bodySmall,
                )
              : null,
          children: [
            ProfileAvatarEditor(
              value: _avatar,
              enabled: !saving,
              onChanged: (next) {
                setState(() => _avatar = next);
                _edit.markDirty();
              },
            ),
            SizedBox(height: context.eos.spacing.md),
            Text('Personal information', style: context.eosText.titleSmall),
            SizedBox(height: context.eos.spacing.sm),
            ProfileTextField(
              controller: _firstName,
              label: 'First name',
              enabled: !saving,
              maxLength: ProfileValidators.maxName,
              validator: ProfileValidators.firstName,
            ),
            SizedBox(height: context.eos.spacing.sm),
            ProfileTextField(
              controller: _lastName,
              label: 'Last name',
              enabled: !saving,
              maxLength: ProfileValidators.maxName,
              validator: ProfileValidators.lastName,
            ),
            SizedBox(height: context.eos.spacing.sm),
            ProfileTextField(
              controller: _displayName,
              label: 'Display name',
              enabled: !saving,
              isRequired: true,
              maxLength: ProfileValidators.maxDisplayName,
              validator: ProfileValidators.displayName,
            ),
            SizedBox(height: context.eos.spacing.sm),
            ProfileTextArea(
              controller: _bio,
              label: 'Bio',
              hint: 'A short introduction',
              enabled: !saving,
              validator: ProfileValidators.bio,
            ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Professional information', style: context.eosText.titleSmall),
            SizedBox(height: context.eos.spacing.sm),
            ProfileTextField(
              controller: _occupation,
              label: 'Occupation',
              enabled: !saving,
              validator: ProfileValidators.occupation,
            ),
            SizedBox(height: context.eos.spacing.sm),
            ProfileTextField(
              controller: _company,
              label: 'Company',
              enabled: !saving,
              validator: ProfileValidators.company,
            ),
            SizedBox(height: context.eos.spacing.lg),
            ProfileChipSelector(
              title: 'Interests',
              options: _kInterestOptions,
              selected: _interests,
              enabled: !saving,
              onChanged: (next) {
                setState(() => _interests = next);
                _edit.markDirty();
              },
            ),
            SizedBox(height: context.eos.spacing.lg),
            ProfileSocialLinksForm(
              controllers: _social,
              enabled: !saving,
              onChanged: _onFieldChanged,
            ),
          ],
        );
      },
    );
  }
}
