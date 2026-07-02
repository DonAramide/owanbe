import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/user_role.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../../portals/customer/router/event_route_registry.dart';

class OrganizerOnboardingScreen extends ConsumerStatefulWidget {
  const OrganizerOnboardingScreen({super.key});

  @override
  ConsumerState<OrganizerOnboardingScreen> createState() => _OrganizerOnboardingScreenState();
}

class _OrganizerOnboardingScreenState extends ConsumerState<OrganizerOnboardingScreen> {
  final _displayName = TextEditingController();
  final _organization = TextEditingController();
  final _phone = TextEditingController();
  var _step = 0;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    _organization.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _markEmailVerified() async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(identityApiProvider).upsertOrganizerProfile(
            session,
            markEmailVerified: true,
            onboardingStep: 'phone',
          );
      setState(() => _step = 1);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePhone() async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Phone number is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(identityApiProvider).upsertOrganizerProfile(
            session,
            phoneE164: _phone.text.trim(),
            markPhoneVerified: true,
            onboardingStep: 'profile',
          );
      setState(() => _step = 2);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfile() async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    if (_displayName.text.trim().isEmpty) {
      setState(() => _error = 'Display name is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(identityApiProvider).upsertOrganizerProfile(
            session,
            displayName: _displayName.text.trim(),
            onboardingStep: 'organization',
          );
      setState(() => _step = 3);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveOrganization() async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    if (_organization.text.trim().isEmpty) {
      setState(() => _error = 'Organization name is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(identityApiProvider).upsertOrganizerProfile(
            session,
            organizationName: _organization.text.trim(),
            onboardingStep: 'complete',
          );
      if (!mounted) return;
      context.go(EventRouteRegistry.home);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Verify email', 'Verify phone', 'Your profile', 'Organization'];
    return Scaffold(
      appBar: AppBar(title: const Text('Organizer setup')),
      body: ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          const Center(child: OwambeLogo(size: 72)),
          SizedBox(height: context.eos.spacing.lg),
          Text('Welcome, organizer', style: context.eosText.headlineSmall),
          SizedBox(height: context.eos.spacing.sm),
          Text('Complete these steps to access your dashboard.', style: context.eosText.bodyMedium),
          SizedBox(height: context.eos.spacing.lg),
          Stepper(
            currentStep: _step,
            controlsBuilder: (_, __) => const SizedBox.shrink(),
            steps: [
              for (var i = 0; i < steps.length; i++)
                Step(
                  title: Text(steps[i]),
                  isActive: _step >= i,
                  state: _step > i ? StepState.complete : (_step == i ? StepState.editing : StepState.indexed),
                  content: const SizedBox.shrink(),
                ),
            ],
          ),
          if (_error != null) ...[
            Text(_error!, style: context.eosText.bodySmall?.copyWith(color: context.eosColors.error)),
            SizedBox(height: context.eos.spacing.md),
          ],
          if (_step == 0) ...[
            Text(
              'Confirm the verification email we sent when you signed up, then continue.',
              style: context.eosText.bodyMedium,
            ),
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(
              onPressed: _busy ? null : _markEmailVerified,
              child: const Text('I verified my email'),
            ),
          ],
          if (_step == 1) ...[
            EosTextField(controller: _phone, label: 'Phone number', hint: '+2348012345678'),
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(onPressed: _busy ? null : _savePhone, child: const Text('Continue')),
          ],
          if (_step == 2) ...[
            EosTextField(controller: _displayName, label: 'Your name', hint: 'Lagos Events Co'),
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(onPressed: _busy ? null : _saveProfile, child: const Text('Continue')),
          ],
          if (_step == 3) ...[
            EosTextField(controller: _organization, label: 'Organization name', hint: 'Lagos Events Co'),
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(onPressed: _busy ? null : _saveOrganization, child: const Text('Go to dashboard')),
          ],
        ],
      ),
    );
  }
}

/// Redirect organizer after login if onboarding incomplete.
Future<String?> organizerOnboardingRedirect(WidgetRef ref) async {
  final session = ref.read(authSessionProvider);
  if (session == null || session.role != UserRole.organizer) return null;
  try {
    final profile = await ref.read(identityApiProvider).fetchOrganizerProfile(session);
    if (profile.isComplete) return null;
    return '/organizer/onboarding';
  } catch (_) {
    return '/organizer/onboarding';
  }
}
