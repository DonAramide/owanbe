import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/app_entrypoint.dart';
import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../../router/experience_routes.dart';
import '../auth_error_messages.dart';
import '../widgets/auth_error_banner.dart';

/// Dedicated Admin Flutter login — Control Tower only (never Customer Hub).
class AdminAuthScreen extends ConsumerStatefulWidget {
  const AdminAuthScreen({super.key});

  @override
  ConsumerState<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends ConsumerState<AdminAuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  AuthErrorMessage? _error;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _email.text = 'superadmin@owanbe.dev';
      _password.text = '123456';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authSessionProvider.notifier).signInAdminWithEmail(
            email: email,
            password: password,
          );
      if (!mounted) return;
      context.go(ExperienceRoutes.adminHome);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Admin auth failed: $e\n$st');
      if (!mounted) return;
      setState(() => _error = formatAuthError(e, isSignUp: false));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (prev, next) {
      if (next != null && prev == null && mounted && AppEntrypoint.isAdminApp) {
        context.go(ExperienceRoutes.adminHome);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: EosSurfaceCard(
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: OwambeLogo(size: 56)),
                    const SizedBox(height: 20),
                    Text(
                      'Owanbe Control Tower',
                      style: context.eosText.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Administration Portal — authorized staff only.',
                      style: context.eosText.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    EosTextField(
                      controller: _email,
                      label: 'Administrator email',
                      hint: 'superadmin@owanbe.dev',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    EosTextField(
                      controller: _password,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.visiblePassword,
                      autofillHints: const [],
                      enableSuggestions: false,
                      autocorrect: false,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      AuthErrorBanner(error: _error!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in to Control Tower'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
