import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_notifier.dart';
import '../../auth/user_role.dart';
import 'auth_error_messages.dart';
import 'widgets/auth_error_banner.dart';

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
  bool _obscurePassword = true;
  AuthErrorMessage? _error;

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
      if (!mounted) return;
      context.go(switch (_role) {
        UserRole.organizer => '/organizer',
        UserRole.vendor => '/vendor',
        UserRole.admin => '/admin',
        UserRole.superAdmin => '/super-admin',
        UserRole.client => '/attendee',
      });
    } catch (e) {
      setState(() => _error = formatAuthError(e, roleLabel: _role.label));
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
                'Secure access to your celebration workspace.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(error: _error!),
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
                'Development environment · Seeded password: 123456',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
