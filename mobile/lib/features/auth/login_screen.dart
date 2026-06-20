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
  static const _staffRoles = [UserRole.organizer, UserRole.vendor, UserRole.admin, UserRole.superAdmin];
  UserRole _role = UserRole.organizer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRole;
    if (initial != null && _staffRoles.contains(initial)) {
      _role = initial;
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
                'One app — sign in to open your role home.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Text('Dev role', style: Theme.of(context).textTheme.titleSmall),
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
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  ref.read(authSessionProvider.notifier).signInDemo(role: _role);
                },
                child: const Text('Continue'),
              ),
              const SizedBox(height: 12),
              Text(
                'Replace with real auth; routing already respects role.',
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
