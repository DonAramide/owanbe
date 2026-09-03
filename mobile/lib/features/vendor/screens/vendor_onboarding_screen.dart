import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/user_role.dart';
import '../../../core/api/event_config_api.dart';
import '../../../core/api/identity_api.dart';
import '../../../core/api/owanbe_api_auth.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../core/api/vendor_offerings_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../features/auth/widgets/portal_access_guard.dart';
import '../../../features/organizer/wizard_v2/models/nigeria_locations.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/owanbe_identity_config.dart';
import '../../../identity/workspace_models.dart';
import '../../../profile/profile.dart';
import '../../../router/portal_routes.dart';
import '../models/vendor_workspace_profile.dart';
import '../providers/vendor_profile_providers.dart';
import '../providers/vendor_providers.dart';

const _africanCountries = [
  'Algeria', 'Angola', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cameroon',
  'Central African Republic', 'Chad', 'Comoros', 'Democratic Republic of the Congo',
  'Republic of the Congo', 'Djibouti', 'Egypt', 'Equatorial Guinea', 'Eritrea', 'Eswatini',
  'Ethiopia', 'Gabon', 'Gambia', 'Ghana', 'Guinea', 'Guinea-Bissau', 'Ivory Coast', 'Kenya',
  'Lesotho', 'Liberia', 'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius',
  'Morocco', 'Mozambique', 'Namibia', 'Niger', 'Nigeria', 'Rwanda', 'Sao Tome and Principe',
  'Senegal', 'Seychelles', 'Sierra Leone', 'Somalia', 'South Africa', 'South Sudan', 'Sudan',
  'Tanzania', 'Togo', 'Tunisia', 'Uganda', 'Zambia', 'Zimbabwe',
];

const _weekDays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// First-time Vendor OS onboarding wizard.
///
/// Completing this flow PATCHes `/me/vendor-profile`, optionally seeds catalog
/// packages, then calls `completeOnboarding(workspace: vendor)` so the user
/// lands on an empty, personalized Vendor Dashboard.
class VendorOnboardingScreen extends ConsumerStatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  ConsumerState<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends ConsumerState<VendorOnboardingScreen> {
  static const _totalSteps = 11; // 0..10 (welcome → review); step 11 is submit action

  var _step = 0;
  var _busy = false;
  String? _error;

  // Step 2 — business
  final _businessName = TextEditingController();
  final _displayName = TextEditingController();
  final _description = TextEditingController();

  // Step 3 — categories
  final Set<String> _categories = {};

  // Step 3 — capabilities + taxonomy (Phase 2)
  final Set<String> _capabilityKeys = {};
  List<VendorBusinessCapabilityConfig> _capabilityDefs = const [];
  List<VendorCategoryConfig> _serviceCats = const [];
  List<VendorCategoryConfig> _rentalCats = const [];
  final Set<String> _serviceCategoryIds = {};
  final Set<String> _rentalCategoryIds = {};

  // Step 4 — branding
  ProfileAvatarValue _logo = const ProfileAvatarValue();
  ProfileAvatarValue _cover = const ProfileAvatarValue();

  // Step 5 — location
  String? _selectedCountry = 'Nigeria';
  String? _selectedState;
  String? _selectedLga;
  final _region = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();

  // Step 6 — contact
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();

  // Step 7 — hours (stored in socialLinks.business_hours)
  final Set<String> _openDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  TimeOfDay _openAt = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeAt = const TimeOfDay(hour: 18, minute: 0);

  // Step 8–9 — services + pricing
  final List<_ServiceDraft> _services = [
    _ServiceDraft(name: TextEditingController(), price: TextEditingController()),
  ];
  final _startingPrice = TextEditingController();
  final _priceRange = TextEditingController();

  // Step 10 — bank (optional UI; not required to finish)
  final _bankName = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  bool _skipBank = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillFromSession();
      _loadTaxonomy();
    });
  }

  Future<void> _loadTaxonomy() async {
    try {
      final api = EventConfigApi(createOwambeHttpClient());
      final caps = await api.listPublicBusinessCapabilities();
      final services = await api.listPublicOfferingCategories(kind: 'service');
      final rentals = await api.listPublicOfferingCategories(kind: 'rental');
      if (!mounted) return;
      setState(() {
        _capabilityDefs = caps;
        _serviceCats = services;
        _rentalCats = rentals;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Super Admin vendor configuration. Check the API and migration 071.';
      });
    }
  }

  void _syncCategoryLabels() {
    _categories
      ..clear()
      ..addAll(_serviceCats.where((c) => _serviceCategoryIds.contains(c.id)).map((c) => c.label))
      ..addAll(_rentalCats.where((c) => _rentalCategoryIds.contains(c.id)).map((c) => c.label));
  }

  void _prefillFromSession() {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    if (_displayName.text.isEmpty) _displayName.text = session.displayName;
    if (_email.text.isEmpty && (session.email?.isNotEmpty ?? false)) {
      _email.text = session.email!;
    }
    if (_businessName.text.isEmpty && session.displayName.trim().isNotEmpty) {
      _businessName.text = session.displayName.trim();
    }
    final existing = ref.read(vendorWorkspaceProfileProvider).valueOrNull;
    if (existing != null) _hydrate(existing);
  }

  void _hydrate(VendorWorkspaceProfile p) {
    if (p.businessName.trim().isNotEmpty) _businessName.text = p.businessName;
    if (p.businessDescription?.trim().isNotEmpty ?? false) {
      _description.text = p.businessDescription!;
    }
    if (p.category.trim().isNotEmpty) {
      _categories
        ..clear()
        ..addAll(p.category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    if (p.country?.trim().isNotEmpty ?? false) _selectedCountry = p.country;
    if (p.state?.trim().isNotEmpty ?? false) {
      if (_selectedCountry == 'Nigeria') {
        _selectedState = p.state;
      } else {
        _region.text = p.state!;
      }
    }
    if (p.city?.trim().isNotEmpty ?? false) {
      if (_selectedCountry == 'Nigeria') {
        _selectedLga = p.city;
      } else {
        _city.text = p.city!;
      }
    }
    if (p.businessAddress?.trim().isNotEmpty ?? false) {
      _address.text = p.businessAddress!;
    }
    if (p.contactPhone?.trim().isNotEmpty ?? false) _phone.text = p.contactPhone!;
    if (p.contactEmail?.trim().isNotEmpty ?? false) _email.text = p.contactEmail!;
    if (p.portfolioWebsite?.trim().isNotEmpty ?? false) {
      _website.text = p.portfolioWebsite!;
    }
    if (p.startingPrice?.trim().isNotEmpty ?? false) {
      _startingPrice.text = p.startingPrice!;
    }
    if (p.priceRange?.trim().isNotEmpty ?? false) _priceRange.text = p.priceRange!;
    if (p.servicesOffered.isNotEmpty && _services.length == 1 && _services.first.name.text.isEmpty) {
      _services
        ..clear()
        ..addAll(
          p.servicesOffered.map(
            (s) => _ServiceDraft(
              name: TextEditingController(text: s),
              price: TextEditingController(),
            ),
          ),
        );
    }
    _logo = ProfileAvatarValue.fromRemote(p.logoUrl);
    _cover = ProfileAvatarValue.fromRemote(p.coverImageUrl);
    setState(() {});
  }

  @override
  void dispose() {
    _businessName.dispose();
    _displayName.dispose();
    _description.dispose();
    _region.dispose();
    _city.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _startingPrice.dispose();
    _priceRange.dispose();
    _bankName.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    for (final s in _services) {
      s.name.dispose();
      s.price.dispose();
    }
    super.dispose();
  }

  String get _stepTitle => switch (_step) {
        0 => 'Welcome to Vendor OS',
        1 => 'Business information',
        2 => 'Business type',
        3 => 'Business branding',
        4 => 'Business location',
        5 => 'Business contact',
        6 => 'Business hours',
        7 => 'Services',
        8 => 'Pricing',
        9 => 'Bank details',
        10 => 'Review',
        _ => 'Vendor setup',
      };

  Future<void> _next() async {
    setState(() => _error = null);
    if (!_validateCurrentStep()) return;
    if (_step >= 10) {
      await _finish();
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    if (_busy) return;
    if (_step == 0) {
      if (OwanbeIdentityConfig.identityV2) {
        ExperienceNavigation.returnToHub(context);
      } else {
        context.go(PortalRoutes.authFor(UserRole.vendor));
      }
      return;
    }
    setState(() {
      _error = null;
      _step -= 1;
    });
  }

  bool _validateCurrentStep() {
    switch (_step) {
      case 1:
        if (_businessName.text.trim().isEmpty) {
          setState(() => _error = 'Business name is required.');
          return false;
        }
        return true;
      case 2:
        if (_capabilityKeys.isEmpty) {
          setState(() => _error = 'Select at least one business type (Service Provider and/or Rental Provider).');
          return false;
        }
        if (_capabilityKeys.contains('SERVICE_PROVIDER') && _serviceCategoryIds.isEmpty) {
          setState(() => _error = 'Select at least one service category.');
          return false;
        }
        if (_capabilityKeys.contains('RENTAL_PROVIDER') && _rentalCategoryIds.isEmpty) {
          setState(() => _error = 'Select at least one rental category.');
          return false;
        }
        return true;
      case 4:
        if (_selectedCountry == null || _selectedCountry!.isEmpty) {
          setState(() => _error = 'Country is required.');
          return false;
        }
        if (_selectedCountry == 'Nigeria' && (_selectedState == null || _selectedState!.isEmpty)) {
          setState(() => _error = 'State is required.');
          return false;
        }
        return true;
      case 5:
        if (_phone.text.trim().isEmpty) {
          setState(() => _error = 'Phone number is required.');
          return false;
        }
        if (_email.text.trim().isEmpty) {
          setState(() => _error = 'Business email is required.');
          return false;
        }
        return true;
      case 7:
        if (_capabilityKeys.contains('SERVICE_PROVIDER')) {
          final named = _services.where((s) => s.name.text.trim().isNotEmpty).toList();
          if (named.isEmpty) {
            setState(() => _error = 'Add at least one service name.');
            return false;
          }
        }
        return true;
      default:
        return true;
    }
  }

  String _hoursSummary() {
    final days = _weekDays.where(_openDays.contains).join(', ');
    final open = _formatTod(_openAt);
    final close = _formatTod(_closeAt);
    if (days.isEmpty) return 'Hours not set';
    return '$days · $open – $close';
  }

  String _formatTod(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $suffix';
  }

  Future<String?> _uploadIfNeeded(ProfileAvatarValue value, {required String filename, required String purpose}) async {
    if (value.removed) return null;
    if (value.localBytes == null || value.localBytes!.isEmpty) {
      return value.remoteUrl;
    }
    final uploader = ref.read(vendorProfileMediaUploaderProvider);
    return uploader.uploadAvatar(
      bytes: value.localBytes!,
      filename: filename,
      purpose: purpose,
    );
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    _syncCategoryLabels();

    final businessName = _businessName.text.trim();
    final displayName = _displayName.text.trim().isEmpty
        ? businessName
        : _displayName.text.trim();
    final primaryCategory = _categories.isNotEmpty ? _categories.first : 'vendor';
    final categoryCsv = _categories.join(', ');
    final city = _selectedCountry == 'Nigeria'
        ? (_selectedLga ?? _selectedState ?? '')
        : _city.text.trim();
    final state = _selectedCountry == 'Nigeria'
        ? (_selectedState ?? '')
        : _region.text.trim();
    final serviceNames = _services
        .map((s) => s.name.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      // Ensure Nest receives a valid Bearer token before the long create path.
      await OwambeApiAuth.ensureFreshAccessToken();

      final logoUrl = await _uploadIfNeeded(
        _logo,
        filename: 'vendor-logo.jpg',
        purpose: 'logo',
      );
      final coverUrl = await _uploadIfNeeded(
        _cover,
        filename: 'vendor-cover.jpg',
        purpose: 'cover',
      );

      final social = <String, String>{
        'business_hours': _hoursSummary(),
        if (_instagram.text.trim().isNotEmpty) 'instagram': _instagram.text.trim(),
        if (_facebook.text.trim().isNotEmpty) 'facebook': _facebook.text.trim(),
      };

      await ref.read(vendorProfileRepositoryProvider).save(
            VendorWorkspaceProfileUpdate(
              businessName: businessName,
              category: categoryCsv,
              businessDescription: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              servicesOffered: serviceNames,
              servicePrices: [
                for (final s in _services)
                  if (s.name.text.trim().isNotEmpty)
                    (() {
                      final priceText = s.price.text.trim().replaceAll(',', '');
                      final major = double.tryParse(priceText);
                      final priceMinor = major == null ? 0 : (major * 100).round();
                      return {
                        'name': s.name.text.trim(),
                        'basePayoutMinor': priceMinor,
                      };
                    })(),
              ].where((e) => (e['basePayoutMinor'] as int) > 0).toList(),
              country: _selectedCountry,
              state: state.isEmpty ? null : state,
              city: city.isEmpty ? null : city,
              businessAddress:
                  _address.text.trim().isEmpty ? null : _address.text.trim(),
              contactPhone: _phone.text.trim(),
              contactEmail: _email.text.trim(),
              portfolioWebsite:
                  _website.text.trim().isEmpty ? null : _website.text.trim(),
              startingPrice: _startingPrice.text.trim().isEmpty
                  ? null
                  : _startingPrice.text.trim(),
              priceRange:
                  _priceRange.text.trim().isEmpty ? null : _priceRange.text.trim(),
              socialLinks: social,
              logoUrl: logoUrl,
              clearLogo: logoUrl == null && _logo.removed,
              coverImageUrl: coverUrl,
              clearCoverImage: coverUrl == null && _cover.removed,
              availableForBookings: true,
            ),
          );

      try {
        final session = ref.read(authSessionProvider);
        if (session != null) {
          final vendorId = await ref.read(identityApiProvider).resolveVendorId(session);
          if (vendorId != null && vendorId.isNotEmpty) {
            final offerings = VendorOfferingsApi(createOwambeHttpClient());
            await offerings.putCapabilities(vendorId, _capabilityKeys.toList());
            await offerings.putCategories(vendorId, [
              ..._serviceCategoryIds,
              ..._rentalCategoryIds,
            ]);
          }
        }
      } catch (_) {
        // Capability assignment is additive; profile save already succeeded.
      }

      // Best-effort catalog seed for named services with prices.
      try {
        final catalog = ref.read(vendorCatalogApiProvider);
        for (final s in _services) {
          final name = s.name.text.trim();
          if (name.isEmpty) continue;
          final priceText = s.price.text.trim().replaceAll(',', '');
          final major = double.tryParse(priceText);
          final priceMinor = major == null ? 0 : (major * 100).round();
          if (priceMinor <= 0) continue;
          await catalog.createPackage(
            name: name,
            description: name,
            category: primaryCategory,
            priceMinor: priceMinor,
          );
        }
      } catch (_) {
        // Catalog seed is optional; profile + completeOnboarding are canonical.
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'display_name': displayName,
            'business_name': businessName,
            'vendor_category': categoryCsv,
            'country': _selectedCountry,
            'state': state,
            'city': city,
          },
        ),
      );

      try {
        await ref.read(identityApiProvider).completeOnboarding(
              displayName: displayName,
              phoneE164: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              workspace: 'vendor',
            );
      } catch (e) {
        if (!_isApiUnreachable(e)) rethrow;
        await ref.read(authSessionProvider.notifier).markOnboardingCompleteLocally(
              displayName: displayName,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved your vendor profile locally. API at ${OwambeApiAuth.resolveApiBase()} '
              'was unreachable — complete sync when the API is back.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }

      ref.invalidate(vendorWorkspaceProfileProvider);
      bumpVendorRevision(ref);
      await ref.read(userIdentityProvider.notifier).refresh();
      if (!mounted) return;
      _goDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is OwambeAuthRequiredException) {
      return 'Your session expired. Sign out and sign in again, then retry Create Vendor Business.';
    }
    if (error is IdentityApiException) {
      final code = error.code.toUpperCase();
      if (code.contains('401') || code == 'AUTH_REQUIRED' || code == 'INVALID_TOKEN') {
        return 'Authentication failed (401). Sign out and sign in again, then retry.';
      }
      if (code == 'HTTP_TIMEOUT') {
        return 'Request timed out talking to the API. Keep the Nest API running on '
            '${OwambeApiAuth.resolveApiBase()} and try again.';
      }
      return error.message;
    }
    final raw = error.toString();
    if (raw.toLowerCase().contains('timed out') || raw.toLowerCase().contains('timeout')) {
      return 'Request timed out talking to the API. Keep the Nest API running and try again.';
    }
    return raw;
  }

  void _goDashboard() {
    if (OwanbeIdentityConfig.identityV2) {
      context.go(ExperienceNavigation.workspaceHome(ExperienceWorkspace.vendor));
    } else {
      context.go(PortalRoutes.homeFor(UserRole.vendor));
    }
  }

  bool _isApiUnreachable(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('socket') ||
        raw.contains('timeout') ||
        raw.contains('connection') ||
        raw.contains('failed host lookup') ||
        raw.contains('clientexception');
  }

  Future<void> _pickTime({required bool opening}) async {
    final initial = opening ? _openAt : _closeAt;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: EosColors.champagne,
              onPrimary: EosColors.plumDark,
              surface: EosColors.plumDark,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (opening) {
        _openAt = picked;
      } else {
        _closeAt = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / (_totalSteps + 1);

    return PortalAccessGuard(
      requiredRole: UserRole.vendor,
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _stepTitle,
            style: context.eosText.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _busy ? null : _back,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${_step + 1} of ${_totalSteps + 1}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        color: EosColors.champagne,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Material(
                    color: Colors.red.shade900.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: _buildStepBody(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _back,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EosColors.champagne,
                          foregroundColor: EosColors.plumDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _step >= 10 ? 'Create Vendor Business' : 'Continue',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    return switch (_step) {
      0 => _welcomeStep(),
      1 => _businessStep(),
      2 => _categoryStep(),
      3 => _brandingStep(),
      4 => _locationStep(),
      5 => _contactStep(),
      6 => _hoursStep(),
      7 => _servicesStep(),
      8 => _pricingStep(),
      9 => _bankStep(),
      10 => _reviewStep(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _welcomeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Build your vendor business on Owambe',
          style: context.eosText.headlineSmall?.copyWith(
            color: EosColors.champagne,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Vendor OS helps you showcase services, receive bookings, manage '
          'contracts with organizers, and track payouts — all from one workspace.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        const SizedBox(height: 20),
        _bullet('Set up your business profile and branding'),
        _bullet('List services and packages organizers can book'),
        _bullet('Manage requests, events, and wallet activity'),
        const SizedBox(height: 16),
        const Text(
          'This takes a few minutes. You can edit everything later from Vendor Profile.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: EosColors.champagne, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _businessStep() {
    return Column(
      children: [
        EosTextField(
          controller: _businessName,
          label: 'Business name',
          hint: 'E.g. Spice Palace Catering',
        ),
        const SizedBox(height: 16),
        EosTextField(
          controller: _displayName,
          label: 'Display name (optional)',
          hint: 'How you want to appear to organizers',
        ),
        const SizedBox(height: 16),
        EosTextField(
          controller: _description,
          label: 'Business description',
          hint: 'Tell organizers what you offer',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _categoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What type of vendor are you? You may select one or both.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        if (_capabilityDefs.isEmpty)
          const Text(
            'Loading Super Admin capability definitions…',
            style: TextStyle(color: Colors.white54),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cap in _capabilityDefs)
              FilterChip(
                label: Text(cap.label),
                selected: _capabilityKeys.contains(cap.capabilityKey),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _capabilityKeys.add(cap.capabilityKey);
                    } else {
                      _capabilityKeys.remove(cap.capabilityKey);
                      if (cap.capabilityKey == 'SERVICE_PROVIDER') _serviceCategoryIds.clear();
                      if (cap.capabilityKey == 'RENTAL_PROVIDER') _rentalCategoryIds.clear();
                    }
                    _syncCategoryLabels();
                  });
                },
                selectedColor: EosColors.champagne.withValues(alpha: 0.35),
                checkmarkColor: EosColors.champagne,
                labelStyle: TextStyle(
                  color: _capabilityKeys.contains(cap.capabilityKey) ? Colors.white : Colors.white70,
                ),
                backgroundColor: Colors.white10,
                side: const BorderSide(color: Colors.white24),
              ),
          ],
        ),
        if (_capabilityKeys.contains('SERVICE_PROVIDER')) ...[
          const SizedBox(height: 20),
          const Text('What services do you provide?', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _serviceCats)
                FilterChip(
                  label: Text(c.label),
                  selected: _serviceCategoryIds.contains(c.id),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _serviceCategoryIds.add(c.id);
                      } else {
                        _serviceCategoryIds.remove(c.id);
                      }
                      _syncCategoryLabels();
                    });
                  },
                  selectedColor: EosColors.champagne.withValues(alpha: 0.35),
                  checkmarkColor: EosColors.champagne,
                  labelStyle: TextStyle(
                    color: _serviceCategoryIds.contains(c.id) ? Colors.white : Colors.white70,
                  ),
                  backgroundColor: Colors.white10,
                  side: const BorderSide(color: Colors.white24),
                ),
            ],
          ),
        ],
        if (_capabilityKeys.contains('RENTAL_PROVIDER')) ...[
          const SizedBox(height: 20),
          const Text('What rental categories do you provide?', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _rentalCats)
                FilterChip(
                  label: Text(c.label),
                  selected: _rentalCategoryIds.contains(c.id),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _rentalCategoryIds.add(c.id);
                      } else {
                        _rentalCategoryIds.remove(c.id);
                      }
                      _syncCategoryLabels();
                    });
                  },
                  selectedColor: EosColors.champagne.withValues(alpha: 0.35),
                  checkmarkColor: EosColors.champagne,
                  labelStyle: TextStyle(
                    color: _rentalCategoryIds.contains(c.id) ? Colors.white : Colors.white70,
                  ),
                  backgroundColor: Colors.white10,
                  side: const BorderSide(color: Colors.white24),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _brandingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Optional — you can skip and add branding later.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ProfileAvatarEditor(
          value: _logo,
          title: 'Vendor logo',
          subtitle: 'Shown on your Vendor OS header and marketplace cards.',
          enabled: !_busy,
          onChanged: (v) => setState(() => _logo = v),
        ),
        const SizedBox(height: 16),
        ProfileAvatarEditor(
          value: _cover,
          title: 'Cover image',
          subtitle: 'Banner image for your vendor presence.',
          enabled: !_busy,
          onChanged: (v) => setState(() => _cover = v),
        ),
      ],
    );
  }

  Widget _locationStep() {
    final lgas = _selectedState == null ? <String>[] : lgasForState(_selectedState!);
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCountry,
          dropdownColor: EosColors.plumDark,
          decoration: _dropdownDecoration('Country'),
          items: _africanCountries
              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white))))
              .toList(),
          onChanged: (v) => setState(() {
            _selectedCountry = v;
            _selectedState = null;
            _selectedLga = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_selectedCountry == 'Nigeria') ...[
          DropdownButtonFormField<String>(
            value: _selectedState,
            dropdownColor: EosColors.plumDark,
            decoration: _dropdownDecoration('State'),
            items: kNigeriaStates
                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white))))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedState = v;
              _selectedLga = null;
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedLga,
            dropdownColor: EosColors.plumDark,
            decoration: _dropdownDecoration('City / LGA'),
            items: lgas
                .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(color: Colors.white))))
                .toList(),
            onChanged: (v) => setState(() => _selectedLga = v),
          ),
        ] else ...[
          EosTextField(controller: _region, label: 'State / Region'),
          const SizedBox(height: 16),
          EosTextField(controller: _city, label: 'City'),
        ],
        const SizedBox(height: 16),
        EosTextField(
          controller: _address,
          label: 'Address (optional)',
          hint: 'Street / landmark',
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: EosColors.champagne),
      ),
    );
  }

  Widget _contactStep() {
    return Column(
      children: [
        EosTextField(
          controller: _phone,
          label: 'Phone number',
          hint: '+234…',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        EosTextField(
          controller: _email,
          label: 'Business email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        EosTextField(
          controller: _website,
          label: 'Website (optional)',
          hint: 'https://',
        ),
        const SizedBox(height: 16),
        EosTextField(controller: _instagram, label: 'Instagram (optional)'),
        const SizedBox(height: 16),
        EosTextField(controller: _facebook, label: 'Facebook (optional)'),
      ],
    );
  }

  Widget _hoursStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Working days', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _weekDays)
              FilterChip(
                label: Text(d),
                selected: _openDays.contains(d),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _openDays.add(d);
                    } else {
                      _openDays.remove(d);
                    }
                  });
                },
                selectedColor: EosColors.champagne.withValues(alpha: 0.35),
                labelStyle: const TextStyle(color: Colors.white),
                backgroundColor: Colors.white10,
                side: const BorderSide(color: Colors.white24),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(opening: true),
                child: Text('Opens ${_formatTod(_openAt)}', style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(opening: false),
                child: Text('Closes ${_formatTod(_closeAt)}', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(_hoursSummary(), style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  Widget _servicesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add the services or packages you want organizers to book.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _services.length; i++) ...[
          EosTextField(
            controller: _services[i].name,
            label: 'Service / package ${i + 1}',
            hint: 'E.g. Wedding Buffet',
          ),
          const SizedBox(height: 8),
          EosTextField(
            controller: _services[i].price,
            label: 'Price (optional, NGN)',
            hint: 'e.g. 250000',
            keyboardType: TextInputType.number,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _services.length <= 1
                  ? null
                  : () {
                      setState(() {
                        final removed = _services.removeAt(i);
                        removed.name.dispose();
                        removed.price.dispose();
                      });
                    },
              child: const Text('Remove', style: TextStyle(color: Colors.white54)),
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _services.add(
                _ServiceDraft(
                  name: TextEditingController(),
                  price: TextEditingController(),
                ),
              );
            });
          },
          icon: const Icon(Icons.add, color: EosColors.champagne),
          label: const Text('Add another service', style: TextStyle(color: EosColors.champagne)),
        ),
      ],
    );
  }

  Widget _pricingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Optional starting price and range shown on your profile.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        EosTextField(
          controller: _startingPrice,
          label: 'Starting price (optional)',
          hint: 'e.g. From ₦150,000',
        ),
        const SizedBox(height: 16),
        EosTextField(
          controller: _priceRange,
          label: 'Price range (optional)',
          hint: 'e.g. ₦150,000 – ₦2,000,000',
        ),
      ],
    );
  }

  Widget _bankStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Skip for now', style: TextStyle(color: Colors.white)),
          subtitle: const Text(
            'You can add payout details later in Wallet / Payouts.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          value: _skipBank,
          activeColor: EosColors.champagne,
          onChanged: (v) => setState(() => _skipBank = v),
        ),
        if (!_skipBank) ...[
          const SizedBox(height: 8),
          EosTextField(controller: _bankName, label: 'Bank name'),
          const SizedBox(height: 16),
          EosTextField(controller: _accountName, label: 'Account name'),
          const SizedBox(height: 16),
          EosTextField(
            controller: _accountNumber,
            label: 'Account number',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          const Text(
            'Bank details are stored for your reference during setup. '
            'Settlement accounts may still need verification in Wallet.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _reviewStep() {
    final services = _services
        .where((s) => s.name.text.trim().isNotEmpty)
        .map((s) {
          final price = s.price.text.trim();
          return price.isEmpty ? s.name.text.trim() : '${s.name.text.trim()} (₦$price)';
        })
        .join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm your vendor business details before creating.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        _reviewRow('Business', _businessName.text.trim()),
        _reviewRow('Display name', _displayName.text.trim().isEmpty ? '—' : _displayName.text.trim()),
        _reviewRow('Business types', _capabilityKeys.join(', ')),
        _reviewRow('Categories', _categories.join(', ')),
        _reviewRow('Location', [
          _selectedCountry,
          _selectedCountry == 'Nigeria' ? _selectedState : _region.text.trim(),
          _selectedCountry == 'Nigeria' ? _selectedLga : _city.text.trim(),
        ].whereType<String>().where((e) => e.isNotEmpty).join(' · ')),
        _reviewRow('Phone', _phone.text.trim()),
        _reviewRow('Email', _email.text.trim()),
        _reviewRow('Hours', _hoursSummary()),
        _reviewRow('Services', services.isEmpty ? '—' : services),
        _reviewRow(
          'Pricing',
          [
            if (_startingPrice.text.trim().isNotEmpty) _startingPrice.text.trim(),
            if (_priceRange.text.trim().isNotEmpty) _priceRange.text.trim(),
          ].join(' · ').ifEmpty('—'),
        ),
        _reviewRow('Bank', _skipBank ? 'Skipped for now' : '${_bankName.text} / ${_accountNumber.text}'),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text('Edit business details', style: TextStyle(color: EosColors.champagne)),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, height: 1.35)),
        ],
      ),
    );
  }
}

class _ServiceDraft {
  _ServiceDraft({required this.name, required this.price});
  final TextEditingController name;
  final TextEditingController price;
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
