import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/identity_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../public/widgets/public_shell_mixin.dart';

class AttendeeSignupArgs {
  const AttendeeSignupArgs({
    this.email,
    this.phone,
    this.invitations = const [],
  });

  final String? email;
  final String? phone;
  final List<TicketInvitationSummary> invitations;
}

class AttendeeSignupScreen extends ConsumerStatefulWidget {
  const AttendeeSignupScreen({super.key, this.args});

  final AttendeeSignupArgs? args;

  @override
  ConsumerState<AttendeeSignupScreen> createState() => _AttendeeSignupScreenState();
}

class _AttendeeSignupScreenState extends ConsumerState<AttendeeSignupScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  var _obscure = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _email = TextEditingController(text: widget.args?.email ?? '');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim().isNotEmpty ? _name.text.trim() : email.split('@').first;
    if (email.isEmpty || password.length < 6) {
      setState(() => _error = 'Enter a valid email and password (min 6 characters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).signUpAttendee(
            displayName: name,
            email: email,
            password: password,
          );
      await ref.read(identityApiProvider).linkEntitlements(
            email: email,
            phone: widget.args?.phone,
          );
      if (!mounted) return;
      context.go('/attendee');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteCount = widget.args?.invitations.length ?? 0;
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
                  Text('Create your account', style: context.eosText.headlineSmall),
                  if (inviteCount > 0) ...[
                    SizedBox(height: context.eos.spacing.xs),
                    Text(
                      'We will link $inviteCount ticket${inviteCount == 1 ? '' : 's'} to your new account.',
                      style: context.eosText.bodyMedium,
                    ),
                  ],
                  SizedBox(height: context.eos.spacing.lg),
                  EosTextField(controller: _name, label: 'Full name', hint: 'Ada Okafor'),
                  SizedBox(height: context.eos.spacing.md),
                  EosTextField(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    enabled: widget.args?.email == null,
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  EosTextField(
                    controller: _password,
                    label: 'Password',
                    obscureText: _obscure,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
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
                        : const Text('Create account & view tickets'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
