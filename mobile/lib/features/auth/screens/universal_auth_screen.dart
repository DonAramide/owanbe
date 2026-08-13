import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/app_entrypoint.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../../identity/owanbe_identity_config.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../router/experience_routes.dart';
import '../auth_error_messages.dart';
import '../widgets/auth_error_banner.dart';
import '../../../platform/identity/identity_models.dart';
import '../../../platform/identity/identity_platform.dart';

/// Universal authentication — one front door for all of Owanbe.
class UniversalAuthScreen extends ConsumerStatefulWidget {
  const UniversalAuthScreen({super.key});

  @override
  ConsumerState<UniversalAuthScreen> createState() => _UniversalAuthScreenState();
}

class _UniversalAuthScreenState extends ConsumerState<UniversalAuthScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _busy = false;
  AuthErrorMessage? _error;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _email.text = 'attendee@owanbe.dev';
      _password.text = '123456';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _devQuickSignIn() async {
    setState(() {
      _busy = true;
      _error = null;
      _isSignUp = false;
      _email.text = 'attendee@owanbe.dev';
      _password.text = '123456';
    });
    try {
      await ref.read(authSessionProvider.notifier).signInUniversalWithEmail(
            email: 'attendee@owanbe.dev',
            password: '123456',
          );
      if (!mounted) return;
      final identity = await ref.read(userIdentityProvider.notifier).refresh();
      if (!mounted) return;
      if (identity == null) {
        throw StateError('Signed in, but profile could not be loaded. Try again.');
      }
      context.go(ExperienceNavigation.postLogin(identity));
    } catch (e, st) {
      if (kDebugMode) debugPrint('Dev quick sign-in failed: $e\n$st');
      if (!mounted) return;
      setState(() => _error = formatAuthError(e, isSignUp: false));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final notifier = ref.read(authSessionProvider.notifier);
      if (_isSignUp) {
        final name = _name.text.trim().isNotEmpty ? _name.text.trim() : email.split('@').first;
        await notifier.signUpUniversalWithEmail(
          email: email,
          password: password,
          displayName: name,
        );
      } else {
        await notifier.signInUniversalWithEmail(
          email: email,
          password: password,
        );
      }
      if (!mounted) return;
      // Force a fresh /auth/ensure-user with the new JWT (avoids stale in-flight sync).
      final identity = await ref.read(userIdentityProvider.notifier).refresh();
      if (!mounted) return;
      if (identity == null) {
        throw StateError('Signed in, but profile could not be loaded. Try again.');
      }
      context.go(ExperienceNavigation.postLogin(identity));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Universal auth failed: $e\n$st');
      }
      if (!mounted) return;
      final afterSupabase = Supabase.instance.client.auth.currentSession != null;
      setState(() => _error = formatAuthError(
            e,
            isSignUp: _isSignUp,
            afterSupabaseAuth: afterSupabase && e is! AuthException,
          ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).prepareUniversalGoogleSignIn();
      final outcome = await IdentityPlatform.instance.signInWithGoogle();
      if (outcome == AuthOutcome.sessionExpired) {
        throw StateError('Could not open Google sign-in.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete Google sign-in in your browser, then return here.'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatAuthError(e, isSignUp: false));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (prev, next) async {
      if (next != null && prev == null && mounted) {
        if (AppEntrypoint.isAdminApp) {
          context.go(ExperienceRoutes.adminHome);
          return;
        }
        try {
          final identity = ref.read(userIdentityProvider).valueOrNull ??
              await ref.read(userIdentityProvider.future);
          if (!mounted) return;
          context.go(ExperienceNavigation.postLogin(identity));
        } catch (e, st) {
          // API unreachable (Failed to fetch) must not red-screen the auth page.
          if (kDebugMode) debugPrint('Post-login identity sync failed: $e\n$st');
          if (!mounted) return;
          setState(() => _error = formatAuthError(e, afterSupabaseAuth: true));
        }
      }
    });

    return Scaffold(
      backgroundColor: EosColors.plumDark,
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
                    const Center(child: OwambeLogo(size: 64)),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Owanbe',
                      style: context.eosText.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'One customer account for Attendee, Organizer, and Vendor.',
                      style: context.eosText.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: _busy ? null : _devQuickSignIn,
                        child: const Text('Dev: one-tap sign in'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pre-filled with attendee@owanbe.dev / 123456. '
                        'If Sign in still fails, check flutter logs for passwordLen.',
                        style: context.eosText.bodySmall?.copyWith(color: Colors.amber.shade200),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_isSignUp) ...[
                      EosTextField(
                        controller: _name,
                        label: 'Full name',
                        hint: 'Ada Okafor',
                      ),
                      const SizedBox(height: 16),
                    ],
                    EosTextField(
                      controller: _email,
                      label: 'Email',
                      hint: 'you@example.com',
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
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                      onPressed: _busy ? null : _submitEmail,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: null,
                      child: Text(
                        'Continue with Apple',
                        style: TextStyle(color: context.eosColors.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                      }),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : 'New to Owanbe? Create your account',
                      ),
                    ),
                    if (OwanbeIdentityConfig.identityV2)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Organizer, Vendor, and Attendee are workspaces — activate them after sign-in.',
                          style: context.eosText.bodySmall?.copyWith(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
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
