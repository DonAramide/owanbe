import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../widgets/public_shell_mixin.dart';

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

  @override
  void initState() {
    super.initState();
    _email.text = 'attendee@owanbe.dev';
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
                    hint: 'Your Supabase password',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.lg),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'New to Owanbe? Create account',
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  Text(
                    'Use your Supabase attendee account credentials.',
                    style: context.eosText.bodySmall,
                    textAlign: TextAlign.center,
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
    try {
      await ref.read(authSessionProvider.notifier).signInAttendee(
            displayName: name,
            email: email,
            password: password,
          );
      if (!mounted) return;
      context.go(widget.returnPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatAuthError(e)), duration: const Duration(seconds: 6)),
      );
    }
  }

  String _formatAuthError(Object e) {
    final message = e.toString();
    if (message.contains('Failed to fetch') || message.contains('AuthRetryableFetchException')) {
      return 'Cannot reach Supabase — check internet and that your Supabase project is active.';
    }
    if (message.contains('invalid_credentials') || message.contains('Invalid login credentials')) {
      return 'Wrong email or password. After seed script, dev password is 123456.';
    }
    return message
        .replaceFirst('Bad state: ', '')
        .replaceFirst(RegExp(r'AuthApiException\(message: '), '')
        .replaceFirst(RegExp(r', statusCode:.*'), '');
  }
}
