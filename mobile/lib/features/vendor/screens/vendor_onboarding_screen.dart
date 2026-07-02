import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../eos/eos.dart';

class VendorOnboardingScreen extends ConsumerStatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  ConsumerState<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends ConsumerState<VendorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentSection = 0;
  bool _busy = false;

  // SECTION 1: Account Setup
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _referralCode = TextEditingController();
  bool _whatsappEnabled = false;

  // SECTION 2: Business Information
  final _businessName = TextEditingController();
  final List<String> _selectedCategories = [];
  final _yearsOfExperience = TextEditingController();
  final _businessDescription = TextEditingController();
  bool _cacRegistered = false;
  final _cacNumber = TextEditingController();
  final _businessAddress = TextEditingController();
  final _operatingCities = TextEditingController();

  // SECTION 3: Vendor Profile (stubs / handles)
  final _instagram = TextEditingController();
  final _tiktok = TextEditingController();
  final _website = TextEditingController();
  String? _uploadedProfilePhoto;
  String? _uploadedBrandLogo;
  String? _uploadedCoverBanner;
  String? _uploadedPortfolio;
  String? _uploadedGallery;

  // SECTION 4: Services & Pricing
  final List<DynamicServiceEntry> _dynamicServices = [];
  bool _customQuotesSupported = false;

  // SECTION 5: Availability
  final List<String> _selectedWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  final _leadTime = TextEditingController();
  bool _peakSeasonAvailability = false;
  bool _emergencyBooking = false;

  // SECTION 6: Trust & Verification
  String? _uploadedGovId;
  String? _uploadedBizReg;
  String? _uploadedProofOfAddress;
  bool _faceVerified = false;
  bool _bankVerified = false;

  // SECTION 7: Fulfillment Details
  final _teamSize = TextEditingController();
  final _setupDuration = TextEditingController();
  final _cancellationPolicy = TextEditingController();
  final _reschedulePolicy = TextEditingController();
  String _arrivalTimePreference = '2 Hours Before Event';

  // SECTION 8: Payments
  String? _selectedBankName;
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _taxInfo = TextEditingController();
  String _payoutPreference = 'Weekly';

  final List<Map<String, String>> _availableBanks = const [
    {'name': 'Access Bank', 'code': '044'},
    {'name': 'Guaranty Trust Bank (GTB)', 'code': '058'},
    {'name': 'Zenith Bank', 'code': '057'},
    {'name': 'United Bank for Africa (UBA)', 'code': '033'},
    {'name': 'Sterling Bank', 'code': '232'},
    {'name': 'First Bank of Nigeria', 'code': '011'},
  ];

  // SECTION 9: Performance & Discovery
  final List<String> _selectedLanguages = ['English'];
  final List<String> _selectedEventTypes = ['Weddings', 'Birthdays'];
  final _avgEventCapacity = TextEditingController();
  bool _featuredSubscription = false;

  // SECTION 10: Agreements
  bool _agreeTerms = false;
  bool _agreeCommission = false;
  bool _agreeProtection = false;

  final List<String> _availableCategories = [
    'Catering & Food',
    'Photography & Videography',
    'Decoration & Styling',
    'DJ & Live Music',
    'Fashion & Attire',
    'Rentals & Equipment',
    'Event Security',
    'Host / MC Services'
  ];

  @override
  void initState() {
    super.initState();
    _dynamicServices.add(DynamicServiceEntry());
    _accountNumber.addListener(_onAccountNumberChanged);
  }

  void _onAccountNumberChanged() {
    if (_accountNumber.text.length == 10 && _selectedBankName != null) {
      setState(() {
        _accountName.text = 'Jollof Catering Service Limited';
      });
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _referralCode.dispose();
    _businessName.dispose();
    _yearsOfExperience.dispose();
    _businessDescription.dispose();
    _cacNumber.dispose();
    _businessAddress.dispose();
    _operatingCities.dispose();
    _instagram.dispose();
    _tiktok.dispose();
    _website.dispose();
    _leadTime.dispose();
    _teamSize.dispose();
    _setupDuration.dispose();
    _cancellationPolicy.dispose();
    _reschedulePolicy.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _taxInfo.dispose();
    _avgEventCapacity.dispose();
    for (final entry in _dynamicServices) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_agreeTerms || !_agreeCommission || !_agreeProtection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must agree to all platform policies to submit')),
      );
      return;
    }
    setState(() => _busy = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _busy = false);
    if (mounted) {
      context.go('/vendor');
    }
  }

  void _nextSection() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _currentSection++;
      });
    }
  }

  void _prevSection() {
    setState(() {
      _currentSection--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentSection + 1) / 10;
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Vendor Registration',
          style: context.eosText.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _currentSection > 0 ? _prevSection : () => context.go('/vendor'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Linear Progress Indicator
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: EosColors.champagne,
              minHeight: 6,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Section ${_currentSection + 1} of 10: ${_getSectionTitle()}',
                style: context.eosText.titleSmall?.copyWith(color: EosColors.champagne, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildSectionFields(),
              ),
            ),
            // Navigation Footer
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentSection > 0)
                    OutlinedButton(
                      onPressed: _prevSection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(),
                  FilledButton(
                    onPressed: _currentSection == 9 ? _submit : _nextSection,
                    style: FilledButton.styleFrom(
                      backgroundColor: EosColors.champagne,
                      foregroundColor: EosColors.plumDark,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_currentSection == 9 ? 'Submit for Review' : 'Next'),
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

  String _getSectionTitle() {
    switch (_currentSection) {
      case 0:
        return 'Account Setup';
      case 1:
        return 'Business Information';
      case 2:
        return 'Vendor Profile';
      case 3:
        return 'Services & Pricing';
      case 4:
        return 'Availability';
      case 5:
        return 'Trust & Verification';
      case 6:
        return 'Fulfillment Details';
      case 7:
        return 'Payments';
      case 8:
        return 'Performance & Discovery';
      case 9:
        return 'Agreements';
      default:
        return '';
    }
  }

  Widget _buildSectionFields() {
    switch (_currentSection) {
      case 0:
        return Column(
          children: [
            EosTextField(
              controller: _fullName,
              label: 'Full Name',
              hint: 'E.g. John Doe',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _email,
              label: 'Email Address',
              hint: 'E.g. john@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _phone,
              label: 'Phone Number',
              hint: 'E.g. +234 80 1234 5678',
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _whatsappEnabled,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _whatsappEnabled = v ?? false),
                ),
                const Text('WhatsApp enabled number?', style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _password,
              label: 'Password',
              hint: '••••••••',
              obscureText: true,
              validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _referralCode,
              label: 'Referral Code (Optional)',
              hint: 'E.g. REF-123',
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EosTextField(
              controller: _businessName,
              label: 'Business / Brand Name',
              hint: 'E.g. Zenith Decorators',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Text('Business Categories (multi-select):', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableCategories.map((cat) {
                final isSelected = _selectedCategories.contains(cat);
                return FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: EosColors.champagne,
                  checkmarkColor: EosColors.plumDark,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedCategories.add(cat);
                      } else {
                        _selectedCategories.remove(cat);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _yearsOfExperience,
              label: 'Years of Experience',
              hint: 'E.g. 5',
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _businessDescription,
              label: 'Business Description',
              hint: 'Provide details about your brand and services...',
              maxLines: 3,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _cacRegistered,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _cacRegistered = v ?? false),
                ),
                const Text('CAC Registered Business?', style: TextStyle(color: Colors.white)),
              ],
            ),
            if (_cacRegistered) ...[
              const SizedBox(height: 16),
              EosTextField(
                controller: _cacNumber,
                label: 'CAC Number (Optional)',
                hint: 'RC-123456',
              ),
            ],
            const SizedBox(height: 16),
            EosTextField(
              controller: _businessAddress,
              label: 'Business Address',
              hint: 'E.g. 15 Allen Avenue, Ikeja, Lagos',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _operatingCities,
              label: 'Operating Cities',
              hint: 'E.g. Lagos, Ibadan, Abuja',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visual Brand Assets', style: context.eosText.titleMedium?.copyWith(color: EosColors.champagne)),
            const SizedBox(height: 16),
            _buildAssetSelector('Profile Photo'),
            const SizedBox(height: 16),
            _buildAssetSelector('Brand Logo'),
            const SizedBox(height: 16),
            _buildAssetSelector('Cover Banner'),
            const SizedBox(height: 24),
            EosTextField(
              controller: _instagram,
              label: 'Instagram Handle',
              hint: 'E.g. @yourbrand',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _tiktok,
              label: 'TikTok Handle',
              hint: 'E.g. @yourbrand',
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _website,
              label: 'Website URL (Optional)',
              hint: 'https://',
            ),
            const SizedBox(height: 16),
            _buildAssetSelector('Portfolio PDF / Catalog'),
            const SizedBox(height: 16),
            _buildAssetSelector('Previous Event Gallery Upload'),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add the services you offer to Owanbe organizers and clients:',
              style: context.eosText.labelMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _dynamicServices.length; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Service #${i + 1}',
                          style: context.eosText.titleMedium?.copyWith(
                            color: EosColors.champagne,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_dynamicServices.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                final entry = _dynamicServices.removeAt(i);
                                entry.dispose();
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Service Type', style: context.eosText.labelSmall?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _dynamicServices[i].category,
                      dropdownColor: EosColors.plumDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _availableCategories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)));
                      }).toList(),
                      onChanged: (v) => setState(() => _dynamicServices[i].category = v!),
                    ),
                    const SizedBox(height: 16),
                    Text('Premium Package / Offer tier', style: context.eosText.labelSmall?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _dynamicServices[i].package,
                      dropdownColor: EosColors.plumDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Basic Coverage', child: Text('Basic Coverage', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Standard Package', child: Text('Standard Package', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Premium Package', child: Text('Premium Package', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Deluxe Gold Package', child: Text('Deluxe Gold Package', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (v) => setState(() => _dynamicServices[i].package = v!),
                    ),
                    const SizedBox(height: 16),
                    EosTextField(
                      controller: _dynamicServices[i].startingPriceController,
                      label: 'Starting Price (₦)',
                      hint: 'E.g. 150000',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setSubState) {
                        _dynamicServices[i].startingPriceController.addListener(() {
                          if (mounted) setSubState(() {});
                        });
                        final fee = (double.tryParse(_dynamicServices[i].startingPriceController.text) ?? 0) * 0.05;
                        return Text(
                          'Owanbe Platform Commission (5% Admin Fee): ₦${fee.toStringAsFixed(0)}',
                          style: context.eosText.bodySmall?.copyWith(color: EosColors.champagne),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    EosTextField(
                      controller: _dynamicServices[i].minBookingController,
                      label: 'Minimum Booking Amount (₦)',
                      hint: 'E.g. 50000',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    EosTextField(
                      controller: _dynamicServices[i].serviceRadiusController,
                      label: 'Service Radius (km)',
                      hint: 'E.g. 50',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    EosTextField(
                      controller: _dynamicServices[i].travelFeeController,
                      label: 'Travel Fee Rules',
                      hint: 'E.g. Free within Lagos; ₦500/km outside.',
                    ),
                    const SizedBox(height: 16),
                    _buildDynamicServiceAssetSelector(_dynamicServices[i]),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _dynamicServices.add(DynamicServiceEntry());
                  });
                },
                icon: const Icon(Icons.add, color: EosColors.plumDark),
                label: const Text('Add Another Service', style: TextStyle(color: EosColors.plumDark, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EosColors.champagne,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _customQuotesSupported,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _customQuotesSupported = v ?? false),
                ),
                const Text('Supports custom event quotes?', style: TextStyle(color: Colors.white)),
              ],
            ),
          ],
        );
      case 4:
        final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Working Days:', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((day) {
                final isSelected = _selectedWorkingDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  selectedColor: EosColors.champagne,
                  checkmarkColor: EosColors.plumDark,
                  labelStyle: TextStyle(color: isSelected ? EosColors.plumDark : Colors.white),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedWorkingDays.add(day);
                      } else {
                        _selectedWorkingDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _leadTime,
              label: 'Lead Time Required',
              hint: 'E.g. 2 Weeks',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _peakSeasonAvailability,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _peakSeasonAvailability = v ?? false),
                ),
                const Text('Peak Season Availability?', style: TextStyle(color: Colors.white)),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _emergencyBooking,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _emergencyBooking = v ?? false),
                ),
                const Text('Emergency Booking Available? (within 24h)', style: TextStyle(color: Colors.white)),
              ],
            ),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verification Documentation', style: context.eosText.titleMedium?.copyWith(color: EosColors.champagne)),
            const SizedBox(height: 16),
            _buildAssetSelector('Government Issued ID (NIN, Passport)'),
            const SizedBox(height: 16),
            _buildAssetSelector('Business Registration Proof (CAC)'),
            const SizedBox(height: 16),
            _buildAssetSelector('Proof of Address (Utility Bill)'),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.face, color: _faceVerified ? Colors.green : EosColors.champagne),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: Card(
                          color: EosColors.plumDark,
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: EosColors.champagne),
                                SizedBox(height: 16),
                                Text('Scanning Face and verifying identity...', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {
                        _faceVerified = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Face Verification completed successfully!')),
                      );
                    }
                  },
                  child: Text(
                    _faceVerified ? 'Face Verified ✓' : 'Start Face Verification Scan',
                    style: TextStyle(color: _faceVerified ? Colors.green : Colors.white),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.verified_user, color: _bankVerified ? Colors.green : EosColors.champagne),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: Card(
                          color: EosColors.plumDark,
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: EosColors.champagne),
                                SizedBox(height: 16),
                                Text('Completing Bank Verification (BVN)...', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {
                        _bankVerified = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bank Verification (BVN) completed successfully!')),
                      );
                    }
                  },
                  child: Text(
                    _bankVerified ? 'Bank Verified ✓' : 'Complete Bank Verification (BVN)',
                    style: TextStyle(color: _bankVerified ? Colors.green : Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Apply for Verified Owanbe Badge',
                  style: context.eosText.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        );
      case 6:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EosTextField(
              controller: _teamSize,
              label: 'Team Size',
              hint: 'E.g. 5 members',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _setupDuration,
              label: 'Setup Duration Required',
              hint: 'E.g. 3 Hours',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Text('Arrival Time Preference:', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _arrivalTimePreference,
              dropdownColor: EosColors.plumDark,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: '1 Hour Before Event', child: Text('1 Hour Before', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: '2 Hours Before Event', child: Text('2 Hours Before', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: '3 Hours Before Event', child: Text('3 Hours Before', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'Day Before Event', child: Text('Day Before Event', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _arrivalTimePreference = v!),
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _cancellationPolicy,
              label: 'Cancellation Policy Description',
              hint: 'E.g. Full refund up to 30 days prior...',
              maxLines: 2,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _reschedulePolicy,
              label: 'Reschedule Policy Description',
              hint: 'E.g. Allowed up to 14 days prior...',
              maxLines: 2,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        );
      case 7:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bank Name', style: context.eosText.labelSmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedBankName,
              dropdownColor: EosColors.plumDark,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _availableBanks.map((b) {
                return DropdownMenuItem(
                  value: b['name'],
                  child: Text('${b['name']} (${b['code']})', style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedBankName = v),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _accountNumber,
              label: 'Account Number',
              hint: 'E.g. 0123456789',
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.length != 10 ? 'Account number must be 10 digits' : null,
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _accountName,
              label: 'Account Name (Auto-Validated)',
              hint: 'Type bank & account number to validate...',
              enabled: false,
              validator: (v) => v == null || v.isEmpty ? 'Validation Required' : null,
            ),
            const SizedBox(height: 16),
            Text('Payout Preference:', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _payoutPreference,
              dropdownColor: EosColors.plumDark,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'Immediate', child: Text('Immediate (Within 24 Hours)', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'Weekly', child: Text('Weekly (Every Monday)', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'Bi-Weekly', child: Text('Bi-Weekly', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'Monthly', child: Text('Monthly', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _payoutPreference = v!),
            ),
            const SizedBox(height: 16),
            EosTextField(
              controller: _taxInfo,
              label: 'Tax Information (TIN) (Optional)',
              hint: 'E.g. 12345678-0001',
            ),
          ],
        );
      case 8:
        final langs = ['English', 'Yoruba', 'Igbo', 'Hausa', 'Pidgin'];
        final eventTypes = ['Weddings', 'Birthdays', 'Corporate', 'Festivals', 'Conferences'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Languages Spoken:', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: langs.map((lang) {
                final isSelected = _selectedLanguages.contains(lang);
                return FilterChip(
                  label: Text(lang),
                  selected: isSelected,
                  selectedColor: EosColors.champagne,
                  checkmarkColor: EosColors.plumDark,
                  labelStyle: TextStyle(color: isSelected ? EosColors.plumDark : Colors.white),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLanguages.add(lang);
                      } else {
                        _selectedLanguages.remove(lang);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Event Types Covered (selection-based):', style: context.eosText.labelMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: eventTypes.map((type) {
                final isSelected = _selectedEventTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: EosColors.champagne,
                  checkmarkColor: EosColors.plumDark,
                  labelStyle: TextStyle(color: isSelected ? EosColors.plumDark : Colors.white),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedEventTypes.add(type);
                      } else {
                        _selectedEventTypes.remove(type);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            EosTextField(
              controller: _avgEventCapacity,
              label: 'Average Event Capacity Handled',
              hint: 'E.g. 500 Guests',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _featuredSubscription,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _featuredSubscription = v ?? false),
                ),
                const Text('Subscribe as Featured Vendor? (Boost reach)', style: TextStyle(color: Colors.white)),
              ],
            ),
          ],
        );
      case 9:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Your Application Details', style: context.eosText.titleMedium?.copyWith(color: EosColors.champagne, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView(
                children: [
                  Text('Business Name: ${_businessName.text}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Experience: ${_yearsOfExperience.text} Years', style: const TextStyle(color: Colors.white70)),
                  Text('Operating Cities: ${_operatingCities.text}', style: const TextStyle(color: Colors.white70)),
                  const Divider(color: Colors.white10, height: 16),
                  Text('Services Offered:', style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                  for (final service in _dynamicServices) ...[
                    const SizedBox(height: 4),
                    Text(
                      '- ${service.category} (${service.package}) starting at ₦${service.startingPriceController.text} (Admin commission: ₦${service.serviceFee.toStringAsFixed(0)})',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                  const Divider(color: Colors.white10, height: 16),
                  Text('Fulfillment Details:', style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                  Text('- Team Size: ${_teamSize.text}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('- Setup Duration: ${_setupDuration.text}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('- Working Days: ${_selectedWorkingDays.join(', ')}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const Divider(color: Colors.white10, height: 16),
                  Text('Verification & Billing Status:', style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                  Text('- Face Scan: ${_faceVerified ? 'VERIFIED ✓' : 'Not Verified'}', style: TextStyle(color: _faceVerified ? Colors.green : Colors.redAccent, fontSize: 13)),
                  Text('- BVN Bank Check: ${_bankVerified ? 'VERIFIED ✓' : 'Not Verified'}', style: TextStyle(color: _bankVerified ? Colors.green : Colors.redAccent, fontSize: 13)),
                  Text('- Settlement Bank: $_selectedBankName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('- Account Name: ${_accountName.text}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Terms & Conditions', style: context.eosText.titleMedium?.copyWith(color: EosColors.champagne)),
            const SizedBox(height: 8),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black12,
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SingleChildScrollView(
                child: Text(
                  '1. Acceptance of Terms\n'
                  'By registering as a vendor on Owanbe, you agree to comply with our platform policies, commission rates, and fulfillment timelines.\n\n'
                  '2. Fee Structure\n'
                  'Owanbe deducts a standard 5% administrative fee on all bookings handled through our marketplace engine.\n\n'
                  '3. Customer Protection\n'
                  'Vendors must honor booking confirmations. Unauthorized cancellations will result in penalties or account suspension.',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreeTerms,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('I agree to the Owambe Platform Terms and Conditions', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreeCommission,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _agreeCommission = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('I agree to the standard platform commission and fee policies', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreeProtection,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _agreeProtection = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('I agree to uphold the Owambe customer protection standards and cancellation rules', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildAssetSelector(String labelName) {
    String? currentFile;
    if (labelName.contains('Profile Photo')) currentFile = _uploadedProfilePhoto;
    else if (labelName.contains('Brand Logo')) currentFile = _uploadedBrandLogo;
    else if (labelName.contains('Cover Banner')) currentFile = _uploadedCoverBanner;
    else if (labelName.contains('Portfolio PDF')) currentFile = _uploadedPortfolio;
    else if (labelName.contains('Previous Event Gallery')) currentFile = _uploadedGallery;
    else if (labelName.contains('Government Issued ID')) currentFile = _uploadedGovId;
    else if (labelName.contains('Business Registration')) currentFile = _uploadedBizReg;
    else if (labelName.contains('Proof of Address')) currentFile = _uploadedProofOfAddress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labelName, style: const TextStyle(color: Colors.white70)),
                if (currentFile != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.file_present, color: EosColors.champagne, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          currentFile,
                          style: const TextStyle(color: EosColors.champagne, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                final fakeName = '${labelName.toLowerCase().replaceAll(' ', '_')}_uploaded.png';
                if (labelName.contains('Profile Photo')) _uploadedProfilePhoto = fakeName;
                else if (labelName.contains('Brand Logo')) _uploadedBrandLogo = fakeName;
                else if (labelName.contains('Cover Banner')) _uploadedCoverBanner = fakeName;
                else if (labelName.contains('Portfolio PDF')) _uploadedPortfolio = fakeName;
                else if (labelName.contains('Previous Event Gallery')) _uploadedGallery = fakeName;
                else if (labelName.contains('Government Issued ID')) _uploadedGovId = fakeName;
                else if (labelName.contains('Business Registration')) _uploadedBizReg = fakeName;
                else if (labelName.contains('Proof of Address')) _uploadedProofOfAddress = fakeName;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Simulated upload of $labelName completed.')),
              );
            },
            icon: const Icon(Icons.upload, color: EosColors.champagne, size: 18),
            label: Text(currentFile == null ? 'Upload' : 'Replace', style: const TextStyle(color: EosColors.champagne)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: EosColors.champagne),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicServiceAssetSelector(DynamicServiceEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload Service Contract/Brochure (Optional)', style: TextStyle(color: Colors.white70)),
                if (entry.uploadedFile != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.file_present, color: EosColors.champagne, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          entry.uploadedFile!,
                          style: const TextStyle(color: EosColors.champagne, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                entry.uploadedFile = '${entry.category.toLowerCase().replaceAll(' ', '_')}_contract.pdf';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Uploaded brochure for ${entry.category}.')),
              );
            },
            icon: const Icon(Icons.upload, color: EosColors.champagne, size: 18),
            label: Text(entry.uploadedFile == null ? 'Upload' : 'Replace', style: const TextStyle(color: EosColors.champagne)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: EosColors.champagne),
            ),
          ),
        ],
      ),
    );
  }
}

class DynamicServiceEntry {
  DynamicServiceEntry() {
    startingPriceController.addListener(_updateFee);
  }

  String category = 'Catering & Food';
  String package = 'Standard Package';
  final startingPriceController = TextEditingController(text: '150000');
  final minBookingController = TextEditingController(text: '50000');
  final serviceRadiusController = TextEditingController(text: '50');
  final travelFeeController = TextEditingController(text: 'Free within Lagos; ₦500/km outside.');
  String? uploadedFile;
  double serviceFee = 7500;

  void _updateFee() {
    final val = double.tryParse(startingPriceController.text) ?? 0;
    serviceFee = val * 0.05;
  }

  void dispose() {
    startingPriceController.dispose();
    minBookingController.dispose();
    serviceRadiusController.dispose();
    travelFeeController.dispose();
  }
}
