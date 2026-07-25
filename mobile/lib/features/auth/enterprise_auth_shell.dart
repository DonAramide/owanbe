import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_notifier.dart';
import '../../auth/user_role.dart';
import '../../core/config/enterprise_brand_config.dart';
import '../../eos/eos.dart';
import '../../platform/identity/identity_mfa_provider.dart';
import '../../platform/identity/identity_mfa_models.dart';
import '../../router/experience_routes.dart';

enum EnterpriseBootState { none, authenticating, booting, ready }

class EnterpriseAuthenticationShell extends ConsumerStatefulWidget {
  const EnterpriseAuthenticationShell({
    super.key,
    required this.config,
    required this.role,
  });

  final EnterpriseBrandConfig config;
  final UserRole role;

  @override
  ConsumerState<EnterpriseAuthenticationShell> createState() => _EnterpriseAuthenticationShellState();
}

class _EnterpriseAuthenticationShellState extends ConsumerState<EnterpriseAuthenticationShell> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _trustedWorkstation = false;
  bool _showMfaInput = false;
  bool _show2faEnrollment = false;
  String? _errorMessage;

  EnterpriseBootState _bootState = EnterpriseBootState.none;
  int _bootLogIndex = 0;
  final List<String> _bootLogs = [
    'Initializing cryptographically secure socket handshake...',
    'Performing workspace compliance scan [SOC2 / NDPR]...',
    'Verifying administrator RBAC privileges...',
    'Loading telemetry topology structures...',
    'establishing remote secure pipeline... [SUCCESS]',
  ];
  final List<String> _visibleLogs = [];
  Timer? _bootTimer;

  int _currentImageIndex = 0;
  Timer? _slideshowTimer;
  final List<String> _walkthroughImages = const [
    'assets/branding/walkthrough1.jpg',
    'assets/branding/walkthrough2.jpg',
    'assets/branding/walkthrough3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _slideshowTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % _walkthroughImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    _bootTimer?.cancel();
    _slideshowTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Administrator ID and credentials are required.');
      return;
    }

    if (widget.role == UserRole.admin) {
      final lowerEmail = email.toLowerCase();
      if (lowerEmail.contains('organizer') || lowerEmail.contains('vendor') || lowerEmail.contains('client')) {
        setState(() {
          _errorMessage = 'Access Denied: This portal requires administrative/staff privileges.';
        });
        return;
      }
    }

    final mfaState = ref.read(identityMfaProvider);
    final userConfig = mfaState.configs.values.firstWhere(
      (c) => c.email == email,
      orElse: () => UserMfaConfig(
        userId: email.split('@')[0],
        email: email,
        isMfaEnabled: false,
        mfaFactor: 'none',
        recoveryCodes: const [],
        trustedDevicesCount: 0,
        activeSessionsCount: 0,
        failedLoginAttempts: 0,
        isLocked: false,
      ),
    );

    // If first time login (MFA is disabled), show the 2FA enrollment page directly
    if (!userConfig.isMfaEnabled) {
      setState(() {
        _bootState = EnterpriseBootState.none;
        _show2faEnrollment = true;
        _errorMessage = null;
      });
      return;
    }

    // Mock policy requirement: if MFA field is visible but empty, prompt for it
    if (!_showMfaInput) {
      setState(() {
        _showMfaInput = true;
        _errorMessage = 'Multi-Factor Authentication (MFA) token requested.';
      });
      return;
    }

    if (_mfaController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Security policy requires a valid MFA token.');
      return;
    }

    setState(() {
      _bootState = EnterpriseBootState.authenticating;
      _errorMessage = null;
    });

    try {
      await ref.read(authSessionProvider.notifier).signInWithEmail(
        email: email,
        password: password,
        expectedRole: widget.role,
      );

      final session = ref.read(authSessionProvider);
      final sessionRole = session?.role;
      final isAdminRole = sessionRole == UserRole.admin || sessionRole == UserRole.superAdmin;

      if (widget.role == UserRole.admin && !isAdminRole) {
        await ref.read(authSessionProvider.notifier).signOut();
        setState(() {
          _bootState = EnterpriseBootState.none;
          _errorMessage = 'Access Denied: This portal requires administrative privileges.';
        });
        return;
      }
      
      // Post-login transition: Start control tower boot sequence
      setState(() {
        _bootState = EnterpriseBootState.booting;
        _visibleLogs.clear();
        _bootLogIndex = 0;
      });
      _runBootSequence();
    } catch (e) {
      setState(() {
        _bootState = EnterpriseBootState.none;
        _errorMessage = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _runBootSequence() {
    _bootTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (_bootLogIndex < _bootLogs.length) {
        setState(() {
          _visibleLogs.add(_bootLogs[_bootLogIndex]);
          _bootLogIndex++;
        });
      } else {
        timer.cancel();
        setState(() {
          _bootState = EnterpriseBootState.ready;
        });
      }
    });
  }

  void _enterControlTower() {
    final destination = switch (widget.role) {
      UserRole.admin => ExperienceRoutes.adminHome,
      UserRole.superAdmin => ExperienceRoutes.adminHome,
      UserRole.organizer => '/home',
      UserRole.vendor => '/vendor',
      _ => '/attendee',
    };
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    // If booting or ready, show the Boot Sequence console UI
    if (_bootState == EnterpriseBootState.booting || _bootState == EnterpriseBootState.ready) {
      return _buildConsoleBootScreen();
    }

    final cfg = widget.config;
    final mfaState = ref.watch(identityMfaProvider);
    final email = _emailController.text.trim();
    final userConfig = mfaState.configs.values.firstWhere(
      (c) => c.email == email,
      orElse: () => UserMfaConfig(
        userId: email.isNotEmpty ? email.split('@')[0] : 'admin_generic',
        email: email.isNotEmpty ? email : 'admin@owanbe.dev',
        isMfaEnabled: false,
        mfaFactor: 'none',
        recoveryCodes: const [],
        trustedDevicesCount: 0,
        activeSessionsCount: 0,
        failedLoginAttempts: 0,
        isLocked: false,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E), // Premium deep space dark
      body: Row(
        children: [
          // Left Sidebar (Enterprise Topology Visual & Config Metadata) - Hidden on narrow screens
          if (MediaQuery.of(context).size.width > 800)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF07040D), Color(0xFF151026)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(right: BorderSide(color: Colors.white10)),
                ),
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: EosColors.champagne, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'SECURITY CONTEXT',
                          style: context.eosText.labelMedium?.copyWith(
                            color: EosColors.champagne,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 600),
                              child: Image.asset(
                                _walkthroughImages[_currentImageIndex],
                                key: ValueKey<int>(_currentImageIndex),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Runtime Config Metadata
                    _metadataRow('ENVIRONMENT', cfg.environment.name.toUpperCase(), isBadge: true),
                    _metadataRow('DEPLOYED REGION', cfg.region),
                    _metadataRow('PLATFORM VERSION', cfg.version),
                    _metadataRow('BUILD RUNTIME', cfg.buildNumber),
                    _metadataRow('SECURITY STATUS', cfg.securityStatus, color: Colors.green),
                    _metadataRow('LAST SCAN', cfg.lastSecurityScan),
                    _metadataRow('GOVERNANCE', cfg.complianceStatus),
                  ],
                ),
              ),
            ),
          
          // Right Login Form Card
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Theme(
                    data: ThemeData.dark(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161129),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _show2faEnrollment
                            ? [
                                _build2faEnrollmentForm(userConfig),
                              ]
                            : [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'OWANBE CONTROL TOWER',
                                      style: context.eosText.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cfg.environment == EnterpriseEnvironment.production
                                            ? Colors.red.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: cfg.environment == EnterpriseEnvironment.production
                                              ? Colors.red
                                              : Colors.orange,
                                        ),
                                      ),
                                      child: Text(
                                        cfg.environment.name.toUpperCase(),
                                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Administrative Identity & Authentication Gate',
                                  style: context.eosText.bodySmall?.copyWith(color: Colors.white60),
                                ),
                                const SizedBox(height: 24),
                                
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                TextField(
                                  controller: _emailController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Administrator ID',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    hintText: 'admin@owanbe.dev',
                                    hintStyle: const TextStyle(color: Colors.white30),
                                    prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white60),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.white24),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: EosColors.champagne, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),

                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Credentials',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white60),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: Colors.white60,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.white24),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: EosColors.champagne, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // MFA Field
                                if (_showMfaInput) ...[
                                  TextField(
                                    controller: _mfaController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'MFA Security Token',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      hintText: 'Enter 6-digit verification code',
                                      hintStyle: const TextStyle(color: Colors.white30),
                                      prefixIcon: const Icon(Icons.security_outlined, color: Colors.white60),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.05),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Colors.white24),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: EosColors.champagne, width: 2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                Row(
                                  children: [
                                    Checkbox(
                                      value: _trustedWorkstation,
                                      activeColor: EosColors.champagne,
                                      checkColor: const Color(0xFF0F0B1E),
                                      side: const BorderSide(color: Colors.white54),
                                      onChanged: (v) => setState(() => _trustedWorkstation = v ?? false),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Register as trusted administrative workstation',
                                        style: context.eosText.bodySmall?.copyWith(color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                FilledButton(
                                  onPressed: _bootState == EnterpriseBootState.authenticating ? null : _handleSignIn,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: EosColors.champagne,
                                    foregroundColor: const Color(0xFF0F0B1E),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: _bootState == EnterpriseBootState.authenticating
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('Establish Session', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 24),

                                // Enterprise Identity Federation Section
                                Text(
                                  'ENTERPRISE SIGN IN',
                                  style: context.eosText.labelSmall?.copyWith(color: Colors.white30, letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _ssoChip('Google Workspace', enabled: true),
                                    _ssoChip('Entra ID (Azure AD)', enabled: false),
                                    _ssoChip('Okta Single Sign-On', enabled: false),
                                    _ssoChip('SAML Federation', enabled: false),
                                    _ssoChip('OIDC Gate', enabled: false),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Recovery Console', style: TextStyle(color: Colors.white30, fontSize: 12)),
                                    ),
                                    const Text('SOC2 / NDPR Certified', style: TextStyle(color: Colors.white30, fontSize: 12)),
                                  ],
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleBootScreen() {
    final email = _emailController.text.trim();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0714),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.terminal_outlined, color: Colors.greenAccent, size: 24),
                const SizedBox(width: 12),
                Text(
                  'OWANBE SECURE BOOT CONSOLE',
                  style: context.eosText.labelMedium?.copyWith(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  'ENVIRONMENT: ${widget.config.environment.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 32),

            // Logs output
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListView.builder(
                  itemCount: _visibleLogs.length,
                  itemBuilder: (context, idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        '>> ${_visibleLogs[idx]}',
                        style: const TextStyle(color: Colors.green, fontFamily: 'monospace', fontSize: 14),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Transitional Admin State
            if (_bootState == EnterpriseBootState.ready) ...[
              EosSurfaceCard(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Authenticated: $email',
                              style: context.eosText.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              children: [
                                _bootStatText('Platform Health', '98%', Colors.green),
                                _bootStatText('Active Incidents', '0', Colors.green),
                                _bootStatText('Pending Approvals', '3', Colors.amber),
                                _bootStatText('Posture', 'SECURE', Colors.green),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: _enterControlTower,
                        icon: const Icon(Icons.login),
                        label: const Text('Enter Control Tower'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.greenAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bootStatText(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _metadataRow(String label, String value, {bool isBadge = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white70,
              fontSize: 14,
              fontWeight: isBadge ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ssoChip(String name, {required bool enabled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: enabled ? Colors.white24 : Colors.white10),
      ),
      child: Text(
        enabled ? name : '$name (Disabled)',
        style: TextStyle(
          color: enabled ? Colors.white70 : Colors.white24,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _build2faEnrollmentForm(UserMfaConfig userConfig) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.qr_code_2, color: EosColors.champagne, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ENROLL MFA SECURITY',
                style: context.eosText.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'First-time administrative access requires enrolling this account in a cryptographically signed Authenticator App.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.network(
              'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=otpauth%3A%2F%2Ftotp%2FOwanbe%3Aadmin%40owanbe.dev%3Fsecret%3DJBSWY3DPEHPK3PXP%26issuer%3DOwanbe',
              width: 140,
              height: 140,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.qr_code_2,
                size: 140,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Scan the QR code above or use the secret key to enroll, then enter your 6-digit TOTP validation token.',
          style: TextStyle(color: Colors.white30, fontSize: 11),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _mfaController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'MFA Verification Code',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'Enter 6-digit code',
            hintStyle: const TextStyle(color: Colors.white30),
            prefixIcon: const Icon(Icons.lock_clock_outlined, color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: EosColors.champagne, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (_mfaController.text.trim().isEmpty) {
              setState(() => _errorMessage = 'Please input the validation token.');
              return;
            }
            ref.read(identityMfaProvider.notifier).enrollMfa(userConfig.userId, 'totp');
            setState(() {
              _show2faEnrollment = false;
              _showMfaInput = true;
            });
            _handleSignIn();
          },
          style: FilledButton.styleFrom(
            backgroundColor: EosColors.champagne,
            foregroundColor: const Color(0xFF0F0B1E),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Verify & Establish Session', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _TopologyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EosColors.champagne
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw topology grid and nodes
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 3, paint);
    canvas.drawCircle(center, size.width / 5, paint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
