import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../profile/profile.dart';
import '../models/vendor_models.dart';
import '../models/vendor_workspace_profile.dart';
import '../providers/vendor_profile_providers.dart';

const _kServiceOptions = <String>[
  'Full-service packages',
  'Day-of coordination',
  'Setup & teardown',
  'On-site staffing',
  'Equipment rental',
  'Custom design',
  'Consultation',
  'Delivery',
];

const _kServiceAreaOptions = <String>[
  'Lagos',
  'Abuja',
  'Port Harcourt',
  'Ibadan',
  'Accra',
  'Nairobi',
  'London',
  'Nationwide',
  'International',
];

const _kAdvanceNoticeOptions = <String>[
  'Same day',
  '48 hours',
  '1 week',
  '2 weeks',
  '1 month',
  '3 months',
];

/// Opens Edit Vendor Profile as a sheet (no router / workspace-switch changes).
Future<void> showVendorProfileEditor(BuildContext context, WidgetRef ref) {
  return showProfileEditSheet(
    context: context,
    builder: (ctx, scrollController) => VendorProfileEditSheet(
      scrollController: scrollController,
    ),
  );
}

class VendorProfileEditSheet extends ConsumerStatefulWidget {
  const VendorProfileEditSheet({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  ConsumerState<VendorProfileEditSheet> createState() => _VendorProfileEditSheetState();
}

class _VendorProfileEditSheetState extends ConsumerState<VendorProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _edit = ProfileEditController();

  late final TextEditingController _businessName;
  late final TextEditingController _subcategory;
  late final TextEditingController _years;
  late final TextEditingController _description;
  late final TextEditingController _portfolioWebsite;
  late final TextEditingController _startingPrice;
  late final TextEditingController _priceRange;
  late final TextEditingController _teamSize;
  late final TextEditingController _maxCapacity;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _regNumber;
  late final TextEditingController _taxId;
  late final TextEditingController _videoUrl;

  ProfileAvatarValue _logo = const ProfileAvatarValue();
  ProfileAvatarValue _cover = const ProfileAvatarValue();
  String? _category;
  String? _advanceNotice;
  bool _availableForBookings = true;
  Set<String> _services = {};
  Set<String> _areas = {};
  List<String> _portfolioImages = [];
  List<String> _portfolioVideos = [];
  List<VendorVerificationDocument> _documents = [];
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _businessName = TextEditingController();
    _subcategory = TextEditingController();
    _years = TextEditingController();
    _description = TextEditingController();
    _portfolioWebsite = TextEditingController();
    _startingPrice = TextEditingController();
    _priceRange = TextEditingController();
    _teamSize = TextEditingController();
    _maxCapacity = TextEditingController();
    _address = TextEditingController();
    _city = TextEditingController();
    _state = TextEditingController();
    _country = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _regNumber = TextEditingController();
    _taxId = TextEditingController();
    _videoUrl = TextEditingController();

    for (final c in [
      _businessName,
      _subcategory,
      _years,
      _description,
      _portfolioWebsite,
      _startingPrice,
      _priceRange,
      _teamSize,
      _maxCapacity,
      _address,
      _city,
      _state,
      _country,
      _phone,
      _email,
      _regNumber,
      _taxId,
    ]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() => _edit.markDirty();

  void _hydrate(VendorWorkspaceProfile p) {
    _hydrated = true;
    _businessName.text = p.businessName;
    _subcategory.text = p.subcategory ?? '';
    _years.text = p.yearsOfExperience?.toString() ?? '';
    _description.text = p.businessDescription ?? '';
    _portfolioWebsite.text = p.portfolioWebsite ?? '';
    _startingPrice.text = p.startingPrice ?? '';
    _priceRange.text = p.priceRange ?? '';
    _teamSize.text = p.teamSize?.toString() ?? '';
    _maxCapacity.text = p.maxEventCapacity?.toString() ?? '';
    _address.text = p.businessAddress ?? '';
    _city.text = p.city ?? '';
    _state.text = p.state ?? '';
    _country.text = p.country ?? '';
    _phone.text = p.contactPhone ?? '';
    _email.text = p.contactEmail ?? '';
    _regNumber.text = p.businessRegistrationNumber ?? '';
    _taxId.text = p.taxId ?? '';
    _category = p.category.isEmpty ? null : p.category;
    _advanceNotice = p.advanceBookingNotice;
    _availableForBookings = p.availableForBookings;
    _services = {...p.servicesOffered};
    _areas = {...p.serviceAreas};
    _portfolioImages = List.of(p.portfolioImages);
    _portfolioVideos = List.of(p.portfolioVideos);
    _documents = List.of(p.verificationDocuments);
    _logo = ProfileAvatarValue.fromRemote(p.logoUrl);
    _cover = ProfileAvatarValue.fromRemote(p.coverImageUrl);
  }

  @override
  void dispose() {
    _edit.dispose();
    _businessName.dispose();
    _subcategory.dispose();
    _years.dispose();
    _description.dispose();
    _portfolioWebsite.dispose();
    _startingPrice.dispose();
    _priceRange.dispose();
    _teamSize.dispose();
    _maxCapacity.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _phone.dispose();
    _email.dispose();
    _regNumber.dispose();
    _taxId.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  int? _parseOptionalInt(String raw, {required String label, int min = 0, int max = 1000000}) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null || v < min || v > max) {
      throw FormatException('$label must be between $min and $max');
    }
    return v;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    late final int? years;
    late final int? teamSize;
    late final int? maxCapacity;
    try {
      years = _parseOptionalInt(_years.text, label: 'Years of experience', max: 80);
      teamSize = _parseOptionalInt(_teamSize.text, label: 'Team size', max: 100000);
      maxCapacity = _parseOptionalInt(_maxCapacity.text, label: 'Maximum event capacity');
    } on FormatException catch (e) {
      _edit.setError(e.message);
      return;
    }

    final ok = await _edit.runSave(() async {
      final uploader = ref.read(vendorProfileMediaUploaderProvider);

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
        filename: 'vendor-logo.jpg',
        purpose: 'logo',
      );
      final coverResult = await resolveMedia(
        _cover,
        filename: 'vendor-cover.jpg',
        purpose: 'cover',
      );

      await ref.read(vendorProfileRepositoryProvider).save(
            VendorWorkspaceProfileUpdate(
              businessName: _businessName.text.trim(),
              category: _category ?? '',
              subcategory: _subcategory.text.trim(),
              yearsOfExperience: years,
              businessDescription: _description.text.trim(),
              servicesOffered: _services.toList()..sort(),
              serviceAreas: _areas.toList()..sort(),
              portfolioImages: _portfolioImages,
              portfolioVideos: _portfolioVideos,
              portfolioWebsite: _portfolioWebsite.text.trim(),
              startingPrice: _startingPrice.text.trim(),
              priceRange: _priceRange.text.trim(),
              teamSize: teamSize,
              maxEventCapacity: maxCapacity,
              availableForBookings: _availableForBookings,
              advanceBookingNotice: _advanceNotice,
              businessAddress: _address.text.trim(),
              city: _city.text.trim(),
              state: _state.text.trim(),
              country: _country.text.trim(),
              contactPhone: _phone.text.trim(),
              contactEmail: _email.text.trim(),
              verificationDocuments: _documents,
              businessRegistrationNumber: _regNumber.text.trim(),
              taxId: _taxId.text.trim(),
              logoUrl: logoResult.updateAvatar ? logoResult.avatarUrl : null,
              clearLogo: logoResult.clearAvatar,
              coverImageUrl: coverResult.updateAvatar ? coverResult.avatarUrl : null,
              clearCoverImage: coverResult.clearAvatar,
            ),
          );
      ref.invalidate(vendorWorkspaceProfileProvider);
    }, successMessage: 'Vendor profile updated');

    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_edit.successMessage ?? 'Vendor profile updated')),
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

  Future<void> _addPortfolioImage() async {
    final bytes = await ProfileAvatarEditor.pickGalleryBytes();
    if (bytes == null) return;
    try {
      final url = await ref.read(vendorProfileMediaUploaderProvider).uploadAvatar(
            bytes: bytes,
            filename: 'portfolio.jpg',
            purpose: 'portfolio',
          );
      setState(() => _portfolioImages = [..._portfolioImages, url]);
      _markDirty();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload image: $e')),
      );
    }
  }

  void _addPortfolioVideo() {
    final url = _videoUrl.text.trim();
    final err = ProfileValidators.optionalHttpUrl(url);
    if (url.isEmpty || err != null) {
      _edit.setError(err ?? 'Enter a video URL');
      return;
    }
    setState(() {
      _portfolioVideos = [..._portfolioVideos, url];
      _videoUrl.clear();
    });
    _markDirty();
  }

  Future<void> _addDocument() async {
    final bytes = await ProfileAvatarEditor.pickGalleryBytes();
    if (bytes == null) return;
    try {
      final url = await ref.read(vendorProfileMediaUploaderProvider).uploadAvatar(
            bytes: bytes,
            filename: 'verification-doc.jpg',
            purpose: 'verification_document',
          );
      setState(() {
        _documents = [
          ..._documents,
          VendorVerificationDocument(
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
    final profileAsync = ref.watch(vendorWorkspaceProfileProvider);
    final categories = VendorCatalogType.values.map((e) => e.label).toList();

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
              Text('Could not load vendor profile: $e'),
              SizedBox(height: context.eos.spacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(vendorWorkspaceProfileProvider),
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
        final categoryItems = [
          ...categories,
          if (_category != null &&
              _category!.isNotEmpty &&
              !categories.contains(_category))
            _category!,
        ];
        return ListenableBuilder(
          listenable: _edit,
          builder: (context, _) {
            return ProfileEditLayout(
              title: 'Edit Vendor Profile',
              subtitle: 'Business details for the Vendor workspace only.',
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
                  title: 'Vendor logo',
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
                  subtitle: 'Banner image for your vendor presence.',
                  enabled: !saving,
                  onChanged: (v) {
                    setState(() => _cover = v);
                    _markDirty();
                  },
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Business', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _businessName,
                  label: 'Business name',
                  enabled: !saving,
                  maxLength: 200,
                ),
                SizedBox(height: context.eos.spacing.sm),
                DropdownButtonFormField<String>(
                  value: _category != null && categoryItems.contains(_category)
                      ? _category
                      : null,
                  decoration: const InputDecoration(labelText: 'Vendor category'),
                  items: [
                    for (final c in categoryItems) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: saving
                      ? null
                      : (v) {
                          setState(() => _category = v);
                          _markDirty();
                        },
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _subcategory,
                  label: 'Vendor subcategory',
                  hint: 'e.g. Wedding catering, Live band…',
                  enabled: !saving,
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
                  controller: _description,
                  label: 'Business description',
                  hint: 'Describe your offerings and style…',
                  enabled: !saving,
                  maxLength: 2000,
                  validator: (v) => ProfileValidators.optionalMaxLength(v, 2000),
                ),
                SizedBox(height: context.eos.spacing.lg),
                ProfileChipSelector(
                  title: 'Services offered',
                  options: _kServiceOptions,
                  selected: _services,
                  enabled: !saving,
                  onChanged: (next) {
                    setState(() => _services = next);
                    _markDirty();
                  },
                ),
                SizedBox(height: context.eos.spacing.lg),
                ProfileChipSelector(
                  title: 'Service areas',
                  options: _kServiceAreaOptions,
                  selected: _areas,
                  enabled: !saving,
                  onChanged: (next) {
                    setState(() => _areas = next);
                    _markDirty();
                  },
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Portfolio', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                if (_portfolioImages.isEmpty)
                  Text('No portfolio images yet.', style: context.eosText.bodySmall),
                for (final url in _portfolioImages)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: saving
                          ? null
                          : () {
                              setState(() =>
                                  _portfolioImages = _portfolioImages.where((u) => u != url).toList());
                              _markDirty();
                            },
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : _addPortfolioImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('Add portfolio image'),
                  ),
                ),
                SizedBox(height: context.eos.spacing.sm),
                if (_portfolioVideos.isEmpty)
                  Text('No portfolio videos yet.', style: context.eosText.bodySmall),
                for (final url in _portfolioVideos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: saving
                          ? null
                          : () {
                              setState(() =>
                                  _portfolioVideos = _portfolioVideos.where((u) => u != url).toList());
                              _markDirty();
                            },
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ProfileTextField(
                        controller: _videoUrl,
                        label: 'Portfolio video URL',
                        enabled: !saving,
                        keyboardType: TextInputType.url,
                        validator: ProfileValidators.optionalHttpUrl,
                      ),
                    ),
                    SizedBox(width: context.eos.spacing.sm),
                    OutlinedButton(
                      onPressed: saving ? null : _addPortfolioVideo,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _portfolioWebsite,
                  label: 'Portfolio website',
                  enabled: !saving,
                  keyboardType: TextInputType.url,
                  validator: ProfileValidators.optionalHttpUrl,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Pricing', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _startingPrice,
                  label: 'Starting price',
                  hint: 'e.g. 150000 or From ₦150,000',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _priceRange,
                  label: 'Price range',
                  hint: 'e.g. ₦150,000 – ₦500,000',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Capacity', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _teamSize,
                  label: 'Team size',
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _maxCapacity,
                  label: 'Maximum event capacity',
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Availability', style: context.eosText.titleSmall),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for bookings'),
                  value: _availableForBookings,
                  onChanged: saving
                      ? null
                      : (v) {
                          setState(() => _availableForBookings = v);
                          _markDirty();
                        },
                ),
                DropdownButtonFormField<String>(
                  value: _advanceNotice != null && _kAdvanceNoticeOptions.contains(_advanceNotice)
                      ? _advanceNotice
                      : null,
                  decoration: const InputDecoration(labelText: 'Advance booking notice'),
                  items: [
                    for (final o in _kAdvanceNoticeOptions)
                      DropdownMenuItem(value: o, child: Text(o)),
                  ],
                  onChanged: saving
                      ? null
                      : (v) {
                          setState(() => _advanceNotice = v);
                          _markDirty();
                        },
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Contact', style: context.eosText.titleSmall),
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
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _phone,
                  label: 'Contact phone',
                  enabled: !saving,
                  keyboardType: TextInputType.phone,
                  maxLength: 32,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _email,
                  label: 'Contact email',
                  enabled: !saving,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 254,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Verification', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _regNumber,
                  label: 'Business registration number',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.sm),
                ProfileTextField(
                  controller: _taxId,
                  label: 'Tax identification number (optional)',
                  enabled: !saving,
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text('Verification documents', style: context.eosText.bodyMedium),
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
                              setState(() =>
                                  _documents = _documents.where((d) => d.url != doc.url).toList());
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
