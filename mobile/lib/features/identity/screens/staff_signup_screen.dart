import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/user_role.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../auth/auth_error_messages.dart';
import '../../auth/widgets/auth_error_banner.dart';
import '../../../portals/customer/router/event_route_registry.dart';

class StaffSignupScreen extends ConsumerStatefulWidget {
  const StaffSignupScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<StaffSignupScreen> createState() => _StaffSignupScreenState();
}

class _StaffSignupScreenState extends ConsumerState<StaffSignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _busy = false;
  AuthErrorMessage? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).signUpStaff(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
            role: widget.role,
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      if (!mounted) return;
      context.go(switch (widget.role) {
        UserRole.organizer => '/organizer/onboarding',
        UserRole.vendor => '/vendor/onboarding',
        _ => EventRouteRegistry.home,
      });
    } catch (e) {
      setState(() => _error = formatAuthError(e, roleLabel: widget.role.label));
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
              const Center(child: OwambeLogo(size: 56)),
              const SizedBox(height: 24),
              Text(
                'Create ${widget.role.label} account',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              if (widget.role == UserRole.organizer || widget.role == UserRole.vendor) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                obscureText: _obscure,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(error: _error!),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create account'),
              ),
              TextButton(
                onPressed: () => context.go('/staff/login?role=${widget.role.name}'),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
