import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../widgets/public_shell_mixin.dart';
import '../../../platform/identity/identity_models.dart';
import '../../../platform/identity/identity_platform.dart';
import '../../../platform/domains/workspace/identity_workspace_manager.dart';

import 'package:flutter/services.dart';

class PublicAuthScreen extends ConsumerStatefulWidget {
  const PublicAuthScreen({super.key, this.returnPath = '/attendee'});

  final String returnPath;

  @override
  ConsumerState<PublicAuthScreen> createState() => _PublicAuthScreenState();
}

class _PublicAuthScreenState extends ConsumerState<PublicAuthScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _busy = false;
  bool _rememberMe = false;
  UserRole _selectedRole = UserRole.client;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildPublicShell(
      context: context,
      ref: ref,
      compact: true,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: EosSurfaceCard(
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: OwambeLogo(size: 64)),
                  SizedBox(height: context.eos.spacing.lg),
                  Text(
                    _isSignUp ? 'Create your account' : 'Welcome back',
                    style: context.eosText.headlineSmall,
                  ),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    'Access tickets, receipts, and your attendee dashboard.',
                    style: context.eosText.bodyMedium,
                  ),
                  SizedBox(height: context.eos.spacing.lg),



                  if (_isSignUp)
                    EosTextField(
                      controller: _name,
                      label: 'Full name',
                      hint: 'Ada Okafor',
                    ),
                  if (_isSignUp) SizedBox(height: context.eos.spacing.md),
                  EosTextField(
                    controller: _email,
                    label: 'Email',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  EosTextField(
                    controller: _password,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  
                  // Remember Me checkbox & Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: context.eosColors.primary,
                            onChanged: (val) => setState(() => _rememberMe = val ?? false),
                          ),
                          Text('Remember me', style: context.eosText.bodyMedium),
                        ],
                      ),
                      TextButton(
                        onPressed: () => context.push('/auth/forgot-password'),
                        child: const Text('Forgot password?'),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: context.eos.spacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Social Login section
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 12),
                  const OutlinedButton(
                    onPressed: null, // Disabled Apple placeholder
                    child: Text('Continue with Apple (Disabled)'),
                  ),
                  const SizedBox(height: 8),
                  const OutlinedButton(
                    onPressed: null, // Disabled Microsoft placeholder
                    child: Text('Continue with Microsoft (Disabled)'),
                  ),
                  const SizedBox(height: 8),
                  const OutlinedButton(
                    onPressed: null, // Disabled Facebook placeholder
                    child: Text('Continue with Facebook (Disabled)'),
                  ),

                  SizedBox(height: context.eos.spacing.sm),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'New to Owambe? Create account',
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  TextButton(
                    onPressed: () => context.push('/attending'),
                    child: const Text('Looking for an invitation? Find my ticket'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;
    final name = _name.text.trim().isNotEmpty ? _name.text.trim() : email.split('@').first;
    setState(() => _busy = true);
    try {
      if (_isSignUp) {
        await ref.read(authSessionProvider.notifier).signUpAttendee(
              displayName: name,
              email: email,
              password: password,
            );
        await ref.read(identityApiProvider).linkEntitlements(email: email);
      } else {
        await ref.read(authSessionProvider.notifier).signInWithEmail(
              email: email,
              password: password,
              expectedRole: UserRole.client,
            );
        await ref.read(identityApiProvider).linkEntitlements(email: email);
      }
      if (!mounted) return;
      
      // Redirect to the unified workspace selection page
      context.go('/workspace-selection');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatAuthError(e)), duration: const Duration(seconds: 6)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      final outcome = await IdentityPlatform.instance.signInWithGoogle();
      if (outcome == AuthOutcome.authenticated && mounted) {
        // Collect missing onboarding details or route
        context.push('/onboarding/complete?role=${_selectedRole.name}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatAuthError(Object e) {
    final message = e.toString();
    final raw = message.toLowerCase();
    if (raw.contains('failed to fetch') ||
        raw.contains('clientexception') ||
        raw.contains('authretryablefetchexception') ||
        raw.contains('socketexception') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection timed out') ||
        raw.contains('connection refused')) {
      return 'Cannot reach the server. Please check your connection and try again.';
    }
    if (raw.contains('invalid_credentials') || raw.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (raw.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    return message
        .replaceFirst('Bad state: ', '')
        .replaceFirst(RegExp(r'AuthApiException\(message: '), '')
        .replaceFirst(RegExp(r', statusCode:.*'), '');
  }
}
