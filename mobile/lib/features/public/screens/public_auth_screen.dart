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
  bool _isSignUp = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
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
                    'Phase 1 demo auth — no password required.',
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

  void _submit() {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    final name = _name.text.trim().isNotEmpty ? _name.text.trim() : email.split('@').first;
    ref.read(authSessionProvider.notifier).signInAttendee(displayName: name, email: email);
    context.go(widget.returnPath);
  }
}
