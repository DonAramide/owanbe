import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../profile/profile.dart';
import '../models/organizer_workspace_profile.dart';
import '../providers/organizer_profile_providers.dart';

const _kBusinessTypes = <String>[
  'Individual Organizer',
  'Event Company',
  'Non-Profit Organization',
  'Government Agency',
  'Educational Institution',
  'Corporate Organization',
  'Community Group',
  'Other',
];

const _kVerificationStatuses = <String>[
  'pending',
  'submitted',
  'verified',
  'rejected',
];

/// Social defs without website — website is a dedicated field.
const _kOrganizerSocialDefs = <ProfileSocialLinkDef>[
  ProfileSocialLinkDef(key: 'instagram', label: 'Instagram', hint: 'https://instagram.com/...'),
  ProfileSocialLinkDef(key: 'twitter', label: 'X / Twitter', hint: 'https://x.com/...'),
  ProfileSocialLinkDef(key: 'linkedin', label: 'LinkedIn', hint: 'https://linkedin.com/in/...'),
  ProfileSocialLinkDef(key: 'facebook', label: 'Facebook', hint: 'https://facebook.com/...'),
  ProfileSocialLinkDef(key: 'tiktok', label: 'TikTok', hint: 'https://tiktok.com/@...'),
  ProfileSocialLinkDef(key: 'youtube', label: 'YouTube', hint: 'https://youtube.com/@...'),
];

/// Opens Edit Organizer Profile as a sheet (no router changes).
Future<void> showOrganizerProfileEditor(BuildContext context, WidgetRef ref) {
  return showProfileEditSheet(
    context: context,
    builder: (ctx, scrollController) => OrganizerProfileEditSheet(
      scrollController: scrollController,
    ),
  );
}

class OrganizerProfileEditSheet extends ConsumerStatefulWidget {
  const OrganizerProfileEditSheet({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  ConsumerState<OrganizerProfileEditSheet> createState() => _OrganizerProfileEditSheetState();
}

class _OrganizerProfileEditSheetState extends ConsumerState<OrganizerProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _edit = ProfileEditController();

  late final TextEditingController _organizerName;
  late final TextEditingController _businessName;
  late final TextEditingController _years;
  late final TextEditingController _bio;
  late final TextEditingController _supportEmail;
  late final TextEditingController _supportPhone;
  late final TextEditingController _website;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _regNumber;
  late final TextEditingController _regAuthority;
  late final TextEditingController _regCountry;
  late final TextEditingController _taxId;
  late final TextEditingController _taxAuthority;
  late final Map<String, TextEditingController> _social;

  ProfileAvatarValue _logo = const ProfileAvatarValue();
  ProfileAvatarValue _cover = const ProfileAvatarValue();
  String? _businessType;
  String _verificationStatus = 'pending';
  List<OrganizerVerificationDocument> _documents = [];
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _organizerName = TextEditingController();
    _businessName = TextEditingController();
    _years = TextEditingController();
    _bio = TextEditingController();
    _supportEmail = TextEditingController();
    _supportPhone = TextEditingController();
    _website = TextEditingController();
    _address = TextEditingController();
    _city = TextEditingController();
    _state = TextEditingController();
    _country = TextEditingController();
    _regNumber = TextEditingController();
    _regAuthority = TextEditingController();
    _regCountry = TextEditingController();
    _taxId = TextEditingController();
    _taxAuthority = TextEditingController();
    _social = ProfileSocialLinksForm.createControllers(defs: _kOrganizerSocialDefs);

    for (final c in [
      _organizerName,
      _businessName,
      _years,
      _bio,
      _supportEmail,
      _supportPhone,
      _website,
      _address,
      _city,
      _state,
      _country,
      _regNumber,
      _regAuthority,
      _regCountry,
      _taxId,
      _taxAuthority,
      ..._social.values,
    ]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() => _edit.markDirty();

  void _hydrate(OrganizerWorkspaceProfile p) {
    _hydrated = true;
    _organizerName.text = p.organizerName;
    _businessName.text = p.businessName;
    _years.text = p.yearsOfExperience?.toString() ?? '';
    _bio.text = p.bio ?? '';
    _supportEmail.text = p.supportEmail ?? '';
    _supportPhone.text = p.supportPhone ?? '';
    _website.text = p.website ?? '';
    _address.text = p.businessAddress ?? '';
    _city.text = p.city ?? '';
    _state.text = p.state ?? '';
    _country.text = p.country ?? '';
    _regNumber.text = p.registrationNumber ?? '';
    _regAuthority.text = p.registrationAuthority ?? '';
    _regCountry.text = p.registrationCountry ?? '';
    _taxId.text = p.taxId ?? '';
    _taxAuthority.text = p.taxAuthority ?? '';
    _businessType = p.businessType;
    _verificationStatus = p.verificationStatus;
    _documents = List.of(p.verificationDocuments);
    _logo = ProfileAvatarValue.fromRemote(p.logoUrl);
    _cover = ProfileAvatarValue.fromRemote(p.coverImageUrl);
    for (final e in _social.entries) {
      e.value.text = p.socialLinks[e.key] ?? '';
    }
  }

  @override
  void dispose() {
    _edit.dispose();
    _organizerName.dispose();
    _businessName.dispose();
    _years.dispose();
    _bio.dispose();
    _supportEmail.dispose();
    _supportPhone.dispose();
    _website.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _regNumber.dispose();
    _regAuthority.dispose();
    _regCountry.dispose();
    _taxId.dispose();
    _taxAuthority.dispose();
    ProfileSocialLinksForm.disposeControllers(_social);
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final social = ProfileSocialLinksForm.valuesOf(_social);
    final socialErr = ProfileValidators.socialLinks(social);
    if (socialErr != null) {
      _edit.setError(socialErr);
      return;
    }

    final yearsRaw = _years.text.trim();
    int? years;
    if (yearsRaw.isNotEmpty) {
      years = int.tryParse(yearsRaw);
      if (years == null || years < 0 || years > 80) {
        _edit.setError('Years of experience must be between 0 and 80');
        return;
      }
    }

    final ok = await _edit.runSave(() async {
      final uploader = ref.read(organizerProfileMediaUploaderProvider);

      Future<ProfileAvatarPersistResult> resolveMedia(
        ProfileAvatarValue value, {
        required String filename,
        required String purpose,
      }) async {
        if (!value.shouldUpdateRemote) {
          return const ProfileAvatarPersistResult(updateAvatar: false);
        }
        if (value.localBytes != null) {
          final url = await uploader.uploadAvatar(
            bytes: value.localBytes!,
            filename: filename,
            purpose: purpose,
          );
          return ProfileAvatarPersistResult(updateAvatar: true, avatarUrl: url);
        }
        return const ProfileAvatarPersistResult(updateAvatar: true, clearAvatar: true);
      }

      final logoResult = await resolveMedia(
        _logo,
        filename: 'organizer-logo.jpg',
        purpose: 'logo',
      );
      final coverResult = await resolveMedia(
        _cover,
        filename: 'organizer-cover.jpg',
        purpose: 'cover',
      );

      await ref.read(organizerProfileRepositoryProvider).save(
            OrganizerWorkspaceProfileUpdate(
              organizerName: _organizerName.text.trim(),
              businessName: _businessName.text.trim(),
              businessType: _businessType,
              yearsOfExperience: years,
              bio: _bio.text.trim(),
              supportEmail: _supportEmail.text.trim(),
              supportPhone: _supportPhone.text.trim(),
              website: _website.text.trim(),
              socialLinks: social,
              businessAddress: _address.text.trim(),
              city: _city.text.trim(),
              state: _state.text.trim(),
              country: _country.text.trim(),
              registrationNumber: _regNumber.text.trim(),
              registrationAuthority: _regAuthority.text.trim(),
              registrationCountry: _regCountry.text.trim(),
              taxId: _taxId.text.trim(),
              taxAuthority: _taxAuthority.text.trim(),
              verificationStatus: _verificationStatus,
              verificationDocuments: _documents,
              logoUrl: logoResult.updateAvatar ? logoResult.avatarUrl : null,
              clearLogo: logoResult.clearAvatar,
              coverImageUrl: coverResult.updateAvatar ? coverResult.avatarUrl : null,
              clearCoverImage: coverResult.clearAvatar,
            ),
          );
      ref.invalidate(organizerWorkspaceProfileProvider);
    }, successMessage: 'Organizer profile updated');

    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_edit.successMessage ?? 'Organizer profile updated')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    final discard = await _edit.confirmDiscardIfDirty(
      () => showDiscardChangesDialog(context),
    );
    if (!discard || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addDocument() async {
    final bytes = await ProfileAvatarEditor.pickGalleryBytes();
    if (bytes == null) return;
    try {
      final url = await ref.read(organizerProfileMediaUploaderProvider).uploadAvatar(
            bytes: bytes,
            filename: 'verification-doc.jpg',
            purpose: 'verification_document',
          );
      setState(() {
        _documents = [
          ..._documents,
          OrganizerVerificationDocument(
            url: url,
            name: 'Document ${_documents.length + 1}',
            uploadedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ];
      });
      _markDirty();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(organizerWorkspaceProfileProvider);

    return profileAsync.when(
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
              Text('Could not load organizer profile: $e'),
              SizedBox(height: context.eos.spacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(organizerWorkspaceProfileProvider),
                child: const Text('Retry'),
              ),
            ],
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
              title: 'Edit Organizer Profile',
              subtitle: 'Organization details for the Organizer workspace only.',
              controller: _edit,
              formKey: _formKey,
              scrollController: widget.scrollController,
              onSave: _save,
              onCancel: _cancel,
              children: [
                Text('Branding', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileAvatarEditor(
                  value: _logo,
                  title: 'Organizer logo',
                  subtitle: 'Upload, replace, or remove your logo.',
                  enabled: !saving,
                  onChanged: (v) {
                    setState(() => _logo = v);
                    _markDirty();
                  },
                ),
                SizedBox(height: context.eos.spacing.md),
                ProfileAvatarEditor(
                  value: _cover,
                  title: 'Cover image',
                  subtitle: 'Banner image for your organizer presence.',
                  enabled: !saving,
                  onChanged: (v) {
                    setState(() => _cover = v);
                    _markDirty();
                  },
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Organization', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _organizerName,
                  label: 'Organizer name',
                  enabled: !saving,
                  maxLength: ProfileValidators.maxDisplayName,
                  validator: (v) => ProfileValidators.optionalMaxLength(
                    v,
                    ProfileValidators.maxDisplayName,
                  ),
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _businessName,
                  label: 'Business name',
                  enabled: !saving,
                  maxLength: 200,
                ),
                SizedBox(height: context.eos.spacing.sm),
                DropdownButtonFormField<String>(
                  value: _businessType != null && _kBusinessTypes.contains(_businessType)
                      ? _businessType
                      : null,
                  decoration: const InputDecoration(labelText: 'Business type'),
                  items: [
                    for (final t in _kBusinessTypes)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: saving
                      ? null
                      : (v) {
                          setState(() => _businessType = v);
                          _markDirty();
                        },
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Experience', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _years,
                  label: 'Years of experience',
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('About', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextArea(
                  controller: _bio,
                  label: 'Organizer bio',
                  hint: 'Tell clients about your events and style…',
                  enabled: !saving,
                  maxLength: 2000,
                  validator: (v) => ProfileValidators.optionalMaxLength(v, 2000),
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Contact', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _supportEmail,
                  label: 'Support email',
                  enabled: !saving,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 254,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _supportPhone,
                  label: 'Support phone',
                  enabled: !saving,
                  keyboardType: TextInputType.phone,
                  maxLength: 32,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Online presence', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _website,
                  label: 'Website',
                  enabled: !saving,
                  keyboardType: TextInputType.url,
                  validator: ProfileValidators.optionalHttpUrl,
                ),
                SizedBox(height: context.eos.spacing.md),
                ProfileSocialLinksForm(
                  controllers: _social,
                  defs: _kOrganizerSocialDefs,
                  enabled: !saving,
                  onChanged: _markDirty,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Location', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _address,
                  label: 'Business address',
                  enabled: !saving,
                  maxLength: 500,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _city,
                  label: 'City',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _state,
                  label: 'State / Province / Region',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _country,
                  label: 'Country',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Business registration & verification', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xxs),
                Text(
                  'Use the registration authority for your jurisdiction '
                  '(e.g. CAC in Nigeria, Companies House in the UK, State Secretary of State in the US).',
                  style: context.eosText.bodySmall,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _regNumber,
                  label: 'Registration number',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _regAuthority,
                  label: 'Registration authority',
                  hint: 'e.g. Corporate Affairs Commission, Companies House…',
                  enabled: !saving,
                  maxLength: 200,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _regCountry,
                  label: 'Country of registration',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.md),
                Text('Tax information (optional)', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _taxId,
                  label: 'Tax identification number (TIN)',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _taxAuthority,
                  label: 'Tax authority',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.md),
                Text('Verification', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                DropdownButtonFormField<String>(
                  value: _kVerificationStatuses.contains(_verificationStatus)
                      ? _verificationStatus
                      : 'pending',
                  decoration: const InputDecoration(
                    labelText: 'Verification status',
                    helperText: 'Stored for future workflows — no verification actions in this release.',
                  ),
                  items: [
                    for (final s in _kVerificationStatuses)
                      DropdownMenuItem(
                        value: s,
                        child: Text(s[0].toUpperCase() + s.substring(1)),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _verificationStatus = v);
                          _markDirty();
                        },
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text('Verification documents', style: context.eosText.bodyMedium),
                SizedBox(height: context.eos.spacing.xs),
                if (_documents.isEmpty)
                  Text('No documents uploaded yet.', style: context.eosText.bodySmall),
                for (final doc in _documents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(doc.name ?? 'Document'),
                    subtitle: Text(doc.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: saving
                          ? null
                          : () {
                              setState(() => _documents = _documents.where((d) => d.url != doc.url).toList());
                              _markDirty();
                            },
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : _addDocument,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Add document'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
