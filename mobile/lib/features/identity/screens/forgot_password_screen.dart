import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../public/widgets/public_shell_mixin.dart';

import 'package:flutter/services.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  var _busy = false;
  var _sent = false;
  String? _error;

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
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).resetPassword(email);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                  const Center(child: OwambeLogo(size: 56)),
                  SizedBox(height: context.eos.spacing.lg),
                  Text('Reset your password', style: context.eosText.headlineSmall),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    _sent
                        ? 'If an account exists for that email, you will receive a reset link shortly.'
                        : 'Enter your email and we will send a password reset link.',
                    style: context.eosText.bodyMedium,
                  ),
                  if (!_sent) ...[
                    SizedBox(height: context.eos.spacing.lg),
                    EosTextField(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_error != null) ...[
                      SizedBox(height: context.eos.spacing.sm),
                      Text(_error!, style: context.eosText.bodySmall?.copyWith(color: context.eosColors.error)),
                    ],
                    SizedBox(height: context.eos.spacing.lg),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Send reset link'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
