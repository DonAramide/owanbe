import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../profile/profile.dart';
import '../models/attendee_profile.dart';
import '../providers/attendee_profile_providers.dart';

const _kEventCategories = <String>[
  'Weddings',
  'Birthdays',
  'Corporate',
  'Naming ceremonies',
  'Concerts',
  'Festivals',
  'Networking',
  'Religious',
  'Sports',
  'Fashion',
];

const _kAttendeeInterests = <String>[
  'Music',
  'Dance',
  'Food',
  'Fashion',
  'Photography',
  'Networking',
  'Culture',
  'Nightlife',
  'Family',
  'Travel',
];

/// Attendee workspace profile editor — uses shared UI infra; dedicated repository.
class AttendeeProfileEditScreen extends ConsumerStatefulWidget {
  const AttendeeProfileEditScreen({super.key});

  @override
  ConsumerState<AttendeeProfileEditScreen> createState() => _AttendeeProfileEditScreenState();
}

class _AttendeeProfileEditScreenState extends ConsumerState<AttendeeProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _edit = ProfileEditController();

  late final TextEditingController _preferredName;
  late final TextEditingController _accessibility;
  late final TextEditingController _dietary;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyRelationship;
  late final TextEditingController _emergencyPhone;

  Set<String> _categories = {};
  Set<String> _interests = {};
  bool _notifyEmail = true;
  bool _notifySms = false;
  bool _notifyPush = true;
  bool _showToOrganizers = true;
  bool _showToAttendees = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _preferredName = TextEditingController();
    _accessibility = TextEditingController();
    _dietary = TextEditingController();
    _emergencyName = TextEditingController();
    _emergencyRelationship = TextEditingController();
    _emergencyPhone = TextEditingController();
    for (final c in [
      _preferredName,
      _accessibility,
      _dietary,
      _emergencyName,
      _emergencyRelationship,
      _emergencyPhone,
    ]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() => _edit.markDirty();

  void _hydrate(AttendeeProfile profile) {
    _hydrated = true;
    _preferredName.text = profile.preferredDisplayName ?? '';
    _accessibility.text = profile.accessibilityRequirements ?? '';
    _dietary.text = profile.dietaryPreferences ?? '';
    _emergencyName.text = profile.emergencyContactName ?? '';
    _emergencyRelationship.text = profile.emergencyContactRelationship ?? '';
    _emergencyPhone.text = profile.emergencyContactPhone ?? '';
    _categories = {...profile.preferredEventCategories};
    _interests = {...profile.interests};
    _notifyEmail = profile.notifyEmail;
    _notifySms = profile.notifySms;
    _notifyPush = profile.notifyPush;
    _showToOrganizers = profile.privacyShowToOrganizers;
    _showToAttendees = profile.privacyShowToAttendees;
  }

  @override
  void dispose() {
    _edit.dispose();
    _preferredName.dispose();
    _accessibility.dispose();
    _dietary.dispose();
    _emergencyName.dispose();
    _emergencyRelationship.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final interestsError = ProfileValidators.interests(_interests);
    if (interestsError != null) {
      _edit.setError(interestsError);
      return;
    }

    final ok = await _edit.runSave(() async {
      await ref.read(attendeeProfileRepositoryProvider).save(
            AttendeeProfileUpdate(
              preferredDisplayName: _preferredName.text.trim(),
              preferredEventCategories: _categories.toList()..sort(),
              interests: _interests.toList()..sort(),
              accessibilityRequirements: _accessibility.text.trim(),
              dietaryPreferences: _dietary.text.trim(),
              emergencyContactName: _emergencyName.text.trim(),
              emergencyContactRelationship: _emergencyRelationship.text.trim(),
              emergencyContactPhone: _emergencyPhone.text.trim(),
              notifyEmail: _notifyEmail,
              notifySms: _notifySms,
              notifyPush: _notifyPush,
              privacyShowToOrganizers: _showToOrganizers,
              privacyShowToAttendees: _showToAttendees,
            ),
          );
      ref.invalidate(attendeeProfileProvider);
    }, successMessage: 'Attendee profile updated');

    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_edit.successMessage ?? 'Attendee profile updated')),
    );
    context.pop();
  }

  Future<void> _cancel() async {
    final discard = await _edit.confirmDiscardIfDirty(
      () => showDiscardChangesDialog(context),
    );
    if (!discard || !mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(attendeeProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              child: EosSurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load attendee profile: $e'),
                    SizedBox(height: context.eos.spacing.md),
                    FilledButton(
                      onPressed: () => ref.invalidate(attendeeProfileProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (profile) {
            if (!_hydrated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _hydrated) return;
                setState(() => _hydrate(profile));
              });
            }
            final saving = _edit.isSaving;
            return ListenableBuilder(
              listenable: _edit,
              builder: (context, _) {
                return ProfileEditLayout(
                  title: 'Edit Attendee Profile',
                  subtitle: 'Preferences for the Attendee workspace only.',
                  controller: _edit,
                  formKey: _formKey,
                  onSave: _save,
                  onCancel: _cancel,
                  children: [
                    Text('Personal', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    ProfileTextField(
                      controller: _preferredName,
                      label: 'Preferred display name',
                      enabled: !saving,
                      maxLength: ProfileValidators.maxDisplayName,
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    Text('Privacy', style: context.eosText.titleSmall),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show profile to organizers'),
                      subtitle: const Text('Event hosts can see your attendee card'),
                      value: _showToOrganizers,
                      onChanged: saving
                          ? null
                          : (v) {
                              setState(() => _showToOrganizers = v);
                              _markDirty();
                            },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show profile to other attendees'),
                      subtitle: const Text('Peers can open your profile from attendee lists'),
                      value: _showToAttendees,
                      onChanged: saving
                          ? null
                          : (v) {
                              setState(() => _showToAttendees = v);
                              _markDirty();
                            },
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    ProfileChipSelector(
                      title: 'Preferred event categories',
                      options: _kEventCategories,
                      selected: _categories,
                      enabled: !saving,
                      onChanged: (next) {
                        setState(() => _categories = next);
                        _markDirty();
                      },
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    ProfileChipSelector(
                      title: 'Interests',
                      options: _kAttendeeInterests,
                      selected: _interests,
                      enabled: !saving,
                      onChanged: (next) {
                        setState(() => _interests = next);
                        _markDirty();
                      },
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    Text('Accessibility', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    ProfileTextArea(
                      controller: _accessibility,
                      label: 'Accessibility requirements',
                      hint: 'Seating, mobility, sensory needs…',
                      enabled: !saving,
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    Text('Dietary', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    ProfileTextArea(
                      controller: _dietary,
                      label: 'Dietary preferences',
                      hint: 'Vegetarian, halal, allergies…',
                      enabled: !saving,
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    Text('Emergency contact', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    ProfileTextField(
                      controller: _emergencyName,
                      label: 'Name',
                      enabled: !saving,
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    ProfileTextField(
                      controller: _emergencyRelationship,
                      label: 'Relationship',
                      enabled: !saving,
                      maxLength: 80,
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    ProfileTextField(
                      controller: _emergencyPhone,
                      label: 'Phone number',
                      enabled: !saving,
                      keyboardType: TextInputType.phone,
                      maxLength: 32,
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    Text('Communication', style: context.eosText.titleSmall),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Email notifications'),
                      value: _notifyEmail,
                      onChanged: saving
                          ? null
                          : (v) {
                              setState(() => _notifyEmail = v);
                              _markDirty();
                            },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('SMS notifications'),
                      value: _notifySms,
                      onChanged: saving
                          ? null
                          : (v) {
                              setState(() => _notifySms = v);
                              _markDirty();
                            },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Push notifications'),
                      value: _notifyPush,
                      onChanged: saving
                          ? null
                          : (v) {
                              setState(() => _notifyPush = v);
                              _markDirty();
                            },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
