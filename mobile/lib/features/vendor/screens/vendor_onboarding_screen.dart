import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/user_role.dart';
import '../../../core/api/onboarding_api.dart';
import '../../../core/api/owanbe_api_auth.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../features/auth/widgets/portal_access_guard.dart';
import '../../../features/organizer/wizard_v2/models/nigeria_locations.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/owanbe_identity_config.dart';
import '../../../identity/workspace_models.dart';
import '../../../router/experience_routes.dart';
import '../../../router/portal_routes.dart';

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

final List<Map<String, dynamic>> _nigerianStatesData = kNigeriaStates
    .map((s) => {
          'state': s,
          'lgas': kStateLgas[s] ?? <String>[],
        })
    .toList();

/// Official vendor first-time onboarding — profile, business, and location (country / state / LGA).
class VendorOnboardingScreen extends ConsumerStatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  ConsumerState<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends ConsumerState<VendorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _landmark = TextEditingController();
  final _bizName = TextEditingController();
  final _category = TextEditingController();
  final _region = TextEditingController();
  final _city = TextEditingController();

  String? _selectedCountry = 'Nigeria';
  String? _selectedState;
  String? _selectedLga;
  String _selectedGender = 'Male';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(authSessionProvider);
      if (session != null && _name.text.isEmpty) {
        _name.text = session.displayName;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _dob.dispose();
    _landmark.dispose();
    _bizName.dispose();
    _category.dispose();
    _region.dispose();
    _city.dispose();
    super.dispose();
  }

  List<String> _getLgasForSelectedState() {
    if (_selectedState == null) return [];
    final stateData = _nigerianStatesData.firstWhere(
      (element) => element['state'] == _selectedState,
      orElse: () => <String, dynamic>{},
    );
    return List<String>.from(stateData['lgas'] ?? []);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
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
    if (picked != null) {
      setState(() {
        _dob.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  String _countryCode(String? country) {
    return switch (country) {
      'Nigeria' => 'NG',
      'Ghana' => 'GH',
      'Kenya' => 'KE',
      'South Africa' => 'ZA',
      _ => 'NG',
    };
  }

  String _locationCity() {
    if (_selectedCountry == 'Nigeria') {
      final parts = [_selectedLga, _selectedState].whereType<String>().where((p) => p.isNotEmpty).join(', ');
      return parts.isEmpty ? _landmark.text.trim() : parts;
    }
    final parts = [_city.text.trim(), _region.text.trim()].where((p) => p.isNotEmpty).join(', ');
    return parts.isEmpty ? _landmark.text.trim() : parts;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final displayName = _name.text.trim();
    final phone = _phone.text.trim();

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'display_name': displayName,
            'business_name': _bizName.text.trim(),
            'vendor_category': _category.text.trim(),
            'gender': _selectedGender,
            'date_of_birth': _dob.text.trim(),
            'country': _selectedCountry,
            'state': _selectedCountry == 'Nigeria' ? _selectedState : _region.text.trim(),
            'lga': _selectedCountry == 'Nigeria' ? _selectedLga : _city.text.trim(),
            'landmark': _landmark.text.trim(),
          },
        ),
      );

      try {
        await ref.read(identityApiProvider).completeOnboarding(
              displayName: displayName,
              phoneE164: phone.isEmpty ? null : phone,
              workspace: 'vendor',
            );

        try {
          final application = await ref.read(onboardingApiProvider).createApplication(
                OnboardingApi.devVendorId,
              );
          await ref.read(onboardingApiProvider).upsertBusiness(
                vendorId: OnboardingApi.devVendorId,
                applicationId: application.id,
                legalName: _bizName.text.trim(),
                tradingName: _bizName.text.trim(),
                countryCode: _countryCode(_selectedCountry),
                city: _locationCity(),
              );
        } catch (_) {
          // Business profile sync is best-effort during local dev.
        }

        await ref.read(userIdentityProvider.notifier).refresh();
      } catch (e) {
        if (!_isApiUnreachable(e)) rethrow;
        await ref.read(authSessionProvider.notifier).markOnboardingCompleteLocally(
              displayName: displayName,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved your profile locally. Owambe API at ${OwambeApiAuth.resolveApiBase()} '
              'was unreachable — run adb reverse or fix Wi‑Fi/firewall, then pull to refresh.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        _goPostOnboarding(context);
        return;
      }

      await ref.read(userIdentityProvider.notifier).refresh();
      if (!mounted) return;
      _goPostOnboarding(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goPostOnboarding(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final lgasList = _getLgasForSelectedState();

    return PortalAccessGuard(
      requiredRole: UserRole.vendor,
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Vendor onboarding',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (OwanbeIdentityConfig.identityV2) {
                ExperienceNavigation.returnToHub(context);
              } else {
                context.go(PortalRoutes.authFor(UserRole.vendor));
              }
            },
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Set up your vendor profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: EosColors.champagne,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your business and where you operate.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  EosTextField(
                    controller: _name,
                    label: 'Contact name',
                    hint: 'E.g. Ada Okafor',
                    validator: (v) => v == null || v.isEmpty ? 'Contact name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  EosTextField(
                    controller: _bizName,
                    label: 'Business name',
                    hint: 'E.g. Spice Palace Catering',
                    validator: (v) => v == null || v.isEmpty ? 'Business name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  EosTextField(
                    controller: _category,
                    label: 'Vendor category',
                    hint: 'E.g. Catering, Decor, Sound',
                    validator: (v) => v == null || v.isEmpty ? 'Category is required' : null,
                  ),
                  const SizedBox(height: 16),
                  EosTextField(
                    controller: _phone,
                    label: 'Phone number',
                    hint: 'E.g. +234 80 1234 5678',
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty ? 'Phone number is required' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Gender', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'Male',
                        groupValue: _selectedGender,
                        activeColor: EosColors.champagne,
                        onChanged: (v) => setState(() => _selectedGender = v!),
                      ),
                      const Text('Male', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'Female',
                        groupValue: _selectedGender,
                        activeColor: EosColors.champagne,
                        onChanged: (v) => setState(() => _selectedGender = v!),
                      ),
                      const Text('Female', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'Other',
                        groupValue: _selectedGender,
                        activeColor: EosColors.champagne,
                        onChanged: (v) => setState(() => _selectedGender = v!),
                      ),
                      const Text('Other', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: EosTextField(
                        controller: _dob,
                        label: 'Date of birth',
                        hint: 'YYYY-MM-DD',
                        suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                        validator: (v) => v == null || v.isEmpty ? 'Date of birth is required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: EosColors.champagne,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text('Country', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCountry,
                    dropdownColor: EosColors.plumDark,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _africanCountries
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(color: Colors.white)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCountry = val;
                        _selectedState = null;
                        _selectedLga = null;
                        _region.clear();
                        _city.clear();
                      });
                    },
                    validator: (v) => v == null || v.isEmpty ? 'Country is required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_selectedCountry == 'Nigeria') ...[
                    Text('State', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 8),
                    FormField<String>(
                      initialValue: _selectedState,
                      validator: (v) => v == null || v.isEmpty ? 'State is required' : null,
                      builder: (fieldState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                showSearchableSelector(
                                  context: context,
                                  title: 'Select State',
                                  options: kNigeriaStates,
                                  onSelected: (val) {
                                    setState(() {
                                      _selectedState = val;
                                      _selectedLga = null;
                                    });
                                    fieldState.didChange(val);
                                  },
                                );
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: fieldState.hasError ? Colors.red : Colors.white30,
                                    ),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                ),
                                child: Text(
                                  _selectedState ?? 'Select state',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            if (fieldState.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 12),
                                child: Text(
                                  fieldState.errorText ?? '',
                                  style: const TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Local Government Area (LGA)',
                      style: context.eosText.labelMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    FormField<String>(
                      initialValue: _selectedLga,
                      validator: (v) => v == null || v.isEmpty ? 'LGA is required' : null,
                      builder: (fieldState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                if (_selectedState == null) return;
                                showSearchableSelector(
                                  context: context,
                                  title: 'Select Local Government',
                                  options: lgasList,
                                  onSelected: (val) {
                                    setState(() => _selectedLga = val);
                                    fieldState.didChange(val);
                                  },
                                );
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: fieldState.hasError ? Colors.red : Colors.white30,
                                    ),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                ),
                                child: Text(
                                  _selectedLga ?? 'Select LGA',
                                  style: TextStyle(
                                    color: _selectedState == null ? Colors.white54 : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (fieldState.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 12),
                                child: Text(
                                  fieldState.errorText ?? '',
                                  style: const TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    EosTextField(
                      controller: _region,
                      label: 'State / region',
                      hint: 'E.g. Greater Accra',
                      validator: (v) => v == null || v.isEmpty ? 'State / region is required' : null,
                    ),
                    const SizedBox(height: 16),
                    EosTextField(
                      controller: _city,
                      label: 'City / area',
                      hint: 'E.g. Tema',
                      validator: (v) => v == null || v.isEmpty ? 'City / area is required' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  EosTextField(
                    controller: _landmark,
                    label: 'Closest landmark',
                    hint: 'E.g. Near Ikeja City Mall',
                    validator: (v) => v == null || v.isEmpty ? 'Landmark is required' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: EosColors.champagne,
                      foregroundColor: EosColors.plumDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Complete onboarding',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
