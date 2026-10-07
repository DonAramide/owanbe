import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/password_recovery.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../../router/experience_routes.dart';

/// Sets a new password only while a Supabase recovery session is active.
class RecoveryPasswordScreen extends ConsumerStatefulWidget {
  const RecoveryPasswordScreen({super.key});

  @override
  ConsumerState<RecoveryPasswordScreen> createState() => _RecoveryPasswordScreenState();
}

class _RecoveryPasswordScreenState extends ConsumerState<RecoveryPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _done = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    final confirmation = _confirm.text;
    final validation = PasswordRecovery.validateNewPassword(
      password: password,
      confirmation: confirmation,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(authSessionProvider.notifier);
      await notifier.updateRecoveryPassword(password);
      await notifier.endRecoverySession();
      _password.clear();
      _confirm.clear();
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object error) {
    final text = error.toString();
    if (text.contains('RECOVERY_REQUIRED')) {
      return 'This page is only available from a password recovery link.';
    }
    if (text.contains('RECOVERY_SESSION_REQUIRED')) {
      return 'The recovery session is missing. Request a new reset link.';
    }
    return 'Could not update the password. Request a new reset link and try again.';
  }

  void _returnToLogin() {
    ref.read(passwordRecoveryActiveProvider.notifier).state = false;
    context.go(ExperienceRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
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
                    const Center(child: OwambeLogo(size: 56)),
                    const SizedBox(height: 24),
                    Text(
                      _done ? 'Password updated' : 'Choose a new password',
                      style: context.eosText.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _done
                          ? 'Your password has been updated. Sign in with your new password.'
                          : 'Enter a new password for your Owanbe account.',
                      style: context.eosText.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (!_done) ...[
                      const SizedBox(height: 24),
                      EosTextField(
                        controller: _password,
                        label: 'New password',
                        obscureText: _obscure,
                        autofillHints: const [],
                        enableSuggestions: false,
                        autocorrect: false,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      EosTextField(
                        controller: _confirm,
                        label: 'Confirm password',
                        obscureText: _obscure,
                        autofillHints: const [],
                        enableSuggestions: false,
                        autocorrect: false,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: context.eosText.bodySmall?.copyWith(color: context.eosColors.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Update password'),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _returnToLogin,
                        child: const Text('Back to sign in'),
                      ),
                    ],
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
