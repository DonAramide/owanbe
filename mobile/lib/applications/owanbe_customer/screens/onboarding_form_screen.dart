import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../eos/eos.dart';
import '../../../platform/identity/identity_models.dart';

import '../../../features/organizer/wizard_v2/models/nigeria_locations.dart';

const _africanCountries = [
  'Algeria', 'Angola', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cameroon', 'Central African Republic',
  'Chad', 'Comoros', 'Democratic Republic of the Congo', 'Republic of the Congo', 'Djibouti', 'Egypt', 'Equatorial Guinea',
  'Eritrea', 'Eswatini', 'Ethiopia', 'Gabon', 'Gambia', 'Ghana', 'Guinea', 'Guinea-Bissau', 'Ivory Coast', 'Kenya',
  'Lesotho', 'Liberia', 'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius', 'Morocco', 'Mozambique',
  'Namibia', 'Niger', 'Nigeria', 'Rwanda', 'Sao Tome and Principe', 'Senegal', 'Seychelles', 'Sierra Leone', 'Somalia',
  'South Africa', 'South Sudan', 'Sudan', 'Tanzania', 'Togo', 'Tunisia', 'Uganda', 'Zambia', 'Zimbabwe'
];

final List<Map<String, dynamic>> _nigerianStatesData = kNigeriaStates.map((s) => {
  "state": s,
  "lgas": kStateLgas[s] ?? <String>[],
}).toList();

class OnboardingFormScreen extends StatefulWidget {
  const OnboardingFormScreen({super.key, required this.role});
  final UserRole role;

  @override
  State<OnboardingFormScreen> createState() => _OnboardingFormScreenState();
}

class _OnboardingFormScreenState extends State<OnboardingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _landmark = TextEditingController();
  
  // Address Dropdown states
  String? _selectedCountry = 'Nigeria';
  String? _selectedState;
  String? _selectedLga;
  
  // Organizer specific
  final _orgName = TextEditingController();
  
  // Vendor specific
  final _bizName = TextEditingController();
  final _category = TextEditingController();

  String _selectedGender = 'Male';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _dob.dispose();
    _landmark.dispose();
    _orgName.dispose();
    _bizName.dispose();
    _category.dispose();
    super.dispose();
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
        _dob.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _busy = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _busy = false);
    
    if (mounted) {
      context.go(widget.role == UserRole.organizer
          ? '/organizer'
          : (widget.role == UserRole.vendor ? '/vendor' : '/home'));
    }
  }

  List<String> _getLgasForSelectedState() {
    if (_selectedState == null) return [];
    final stateData = _nigerianStatesData.firstWhere(
      (element) => element['state'] == _selectedState,
      orElse: () => <String, dynamic>{},
    );
    return List<String>.from(stateData['lgas'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final lgasList = _getLgasForSelectedState();

    return Scaffold(
      backgroundColor: EosColors.plumDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Complete Profile',
          style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Onboarding Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: EosColors.champagne,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please fill out the details below to finish setting up your ${widget.role.label} workspace.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 24),
                
                EosTextField(
                  controller: _name,
                  label: 'Full Name',
                  hint: 'E.g. Ada Okafor',
                  validator: (v) => v == null || v.isEmpty ? 'Full name is required' : null,
                ),
                const SizedBox(height: 16),
                
                // Role Specific Fields
                if (widget.role == UserRole.organizer) ...[
                  EosTextField(
                    controller: _orgName,
                    label: 'Organization Name',
                    hint: 'E.g. Zenith Events',
                    validator: (v) => v == null || v.isEmpty ? 'Organization name is required' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.role == UserRole.vendor) ...[
                  EosTextField(
                    controller: _bizName,
                    label: 'Business Name',
                    hint: 'E.g. Spice Palace Catering',
                    validator: (v) => v == null || v.isEmpty ? 'Business name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  EosTextField(
                    controller: _category,
                    label: 'Vendor Category',
                    hint: 'E.g. Catering, Decor, Sound',
                    validator: (v) => v == null || v.isEmpty ? 'Category is required' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Phone
                EosTextField(
                  controller: _phone,
                  label: 'Phone number',
                  hint: 'E.g. +234 80 1234 5678',
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.isEmpty ? 'Phone number is required' : null,
                ),
                const SizedBox(height: 16),

                // Gender Selection
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

                // Date of Birth
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: EosTextField(
                      controller: _dob,
                      label: 'Date of Birth',
                      hint: 'YYYY-MM-DD',
                      suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                      validator: (v) => v == null || v.isEmpty ? 'Date of Birth is required' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Address Section
                Text(
                  'Address Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: EosColors.champagne,
                      ),
                ),
                const SizedBox(height: 16),
                
                // Country Dropdown
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
                  items: _africanCountries.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCountry = val;
                      _selectedState = null;
                      _selectedLga = null;
                    });
                  },
                  validator: (v) => v == null || v.isEmpty ? 'Country is required' : null,
                ),
                const SizedBox(height: 16),
                
                // State Selector (Dropdown if Nigeria, else Text field)
                if (_selectedCountry == 'Nigeria') ...[
                  Text('State', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 8),
                  FormField<String>(
                    initialValue: _selectedState,
                    validator: (v) => v == null || v.isEmpty ? 'State is required' : null,
                    builder: (FormFieldState<String> fieldState) {
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
                                  borderSide: BorderSide(color: fieldState.hasError ? Colors.red : Colors.white30),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              ),
                              child: Text(
                                _selectedState ?? 'Select State',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          if (fieldState.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, left: 12.0),
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
                  
                  // LGA Selector (Dropdown if State selected)
                  Text('Local Government Area (LGA)', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 8),
                  FormField<String>(
                    initialValue: _selectedLga,
                    validator: (v) => v == null || v.isEmpty ? 'LGA is required' : null,
                    builder: (FormFieldState<String> fieldState) {
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
                                  setState(() {
                                    _selectedLga = val;
                                  });
                                  fieldState.didChange(val);
                                },
                              );
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: fieldState.hasError ? Colors.red : Colors.white30),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              ),
                              child: Text(
                                _selectedLga ?? 'Select LGA',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          if (fieldState.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, left: 12.0),
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
                  // Dynamic generic State & LGA text inputs for other African countries
                  EosTextField(
                    label: 'State/Region',
                    hint: 'E.g. Greater Accra',
                    validator: (v) => v == null || v.isEmpty ? 'State/Region is required' : null,
                  ),
                  const SizedBox(height: 16),
                  EosTextField(
                    label: 'City/Area',
                    hint: 'E.g. Tema',
                    validator: (v) => v == null || v.isEmpty ? 'City/Area is required' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                
                EosTextField(
                  controller: _landmark,
                  label: 'Closest Landmark',
                  hint: 'E.g. Near Ikeja City Mall',
                  validator: (v) => v == null || v.isEmpty ? 'Landmark is required' : null,
                ),
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
                      : const Text('Complete Onboarding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
