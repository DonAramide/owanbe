import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_notifier.dart';
import '../../auth/user_role.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialRole});

  final UserRole? initialRole;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _staffRoles = [
    UserRole.organizer,
    UserRole.vendor,
    UserRole.admin,
    UserRole.superAdmin,
  ];

  static const _devAccounts = {
    UserRole.organizer: ('attendee@owanbe.dev', 'organizer'),
    UserRole.vendor: ('attendee@owanbe.dev', 'vendor'),
    UserRole.admin: ('admin@owanbe.dev', 'admin'),
    UserRole.superAdmin: ('superadmin@owanbe.dev', 'super_admin'),
  };

  UserRole _role = UserRole.organizer;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRole;
    if (initial != null && _staffRoles.contains(initial)) {
      _role = initial;
    }
    _applyDevDefaults(_role);
  }

  void _applyDevDefaults(UserRole role) {
    final account = _devAccounts[role];
    if (account != null) {
      _email.text = account.$1;
    }
    _password.clear();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).signInWithEmail(
            email: _email.text,
            password: _password.text,
            expectedRole: _role,
          );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'Owanbe',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in with Supabase — JWT secures every API call.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text('Role', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<UserRole>(
                segments: _staffRoles
                    .map(
                      (r) => ButtonSegment<UserRole>(
                        value: r,
                        label: Text(r.label),
                      ),
                    )
                    .toList(),
                selected: {_role},
                onSelectionChanged: (s) {
                  setState(() {
                    _role = s.first;
                    _applyDevDefaults(_role);
                  });
                },
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              Text(
                'Dev accounts pre-fill email; password is your Supabase user password.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
