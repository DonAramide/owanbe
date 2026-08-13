import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/user_role.dart';
import '../../../core/api/identity_api.dart';
import '../../../core/api/owanbe_api_auth.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/owanbe_identity_config.dart';
import '../../../identity/workspace_models.dart';
import '../../../router/experience_routes.dart';
import '../../../router/portal_routes.dart';

/// Attendee first-time profile — name and optional phone (Phase 4).
class AttendeeOnboardingScreen extends ConsumerStatefulWidget {
  const AttendeeOnboardingScreen({super.key});

  @override
  ConsumerState<AttendeeOnboardingScreen> createState() => _AttendeeOnboardingScreenState();
}

class _AttendeeOnboardingScreenState extends ConsumerState<AttendeeOnboardingScreen> {
  final _displayName = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(authSessionProvider);
      if (session != null && _displayName.text.isEmpty) {
        _displayName.text = session.displayName;
      }
    });
  }

  @override
  void dispose() {
    _displayName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final name = _displayName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'display_name': name}),
      );
      try {
        await ref.read(identityApiProvider).completeOnboarding(
              displayName: name,
              phoneE164: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              workspace: 'client',
            );
      } catch (e) {
        if (!_isApiUnreachable(e)) rethrow;
        // Dev: name saved in Supabase; enter portal and sync API when reachable.
        await ref.read(authSessionProvider.notifier).markOnboardingCompleteLocally(
              displayName: name,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved your name locally. Owambe API at ${OwambeApiAuth.resolveApiBase()} '
              'was unreachable — run adb reverse or fix Wi‑Fi/firewall, then pull to refresh.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        _goPostOnboarding(context);
        return;
      }
      await ref.read(userIdentityProvider.notifier).refresh();
      if (!mounted) return;
      _goPostOnboarding(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _formatOnboardingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goPostOnboarding(BuildContext context) {
    if (OwanbeIdentityConfig.identityV2) {
      context.go(ExperienceNavigation.workspaceHome(ExperienceWorkspace.attendee));
    } else {
      context.go(PortalRoutes.homeFor(UserRole.client));
    }
  }

  bool _isApiUnreachable(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('socket') ||
        raw.contains('timeout') ||
        raw.contains('connection') ||
        raw.contains('failed host lookup') ||
        raw.contains('clientexception');
  }

  String _formatOnboardingError(Object error) {
    if (_isApiUnreachable(error)) {
      return 'Cannot reach Owambe API at ${OwambeApiAuth.resolveApiBase()}.\n\n'
          'USB fix: adb reverse tcp:8080 tcp:8080\n'
          'Wi‑Fi fix: set OWANBE_API_BASE to your PC IP in owanbe_config '
          '(run ipconfig), allow port 8080 in Windows Firewall, then restart the app.';
    }
    if (error is IdentityApiException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendee setup')),
      body: ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          const Center(child: OwambeLogo(size: 72)),
          SizedBox(height: context.eos.spacing.lg),
          Text('Welcome, guest', style: context.eosText.headlineSmall),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            'Tell us how to address you on invitations and tickets.',
            style: context.eosText.bodyMedium,
          ),
          SizedBox(height: context.eos.spacing.lg),
          EosTextField(
            controller: _displayName,
            label: 'Full name',
            hint: 'Ada Okafor',
          ),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(
            controller: _phone,
            label: 'Phone (optional)',
            hint: '+2348012345678',
            keyboardType: TextInputType.phone,
          ),
          if (_error != null) ...[
            SizedBox(height: context.eos.spacing.md),
            Text(
              _error!,
              style: context.eosText.bodySmall?.copyWith(color: context.eosColors.error),
            ),
          ],
          SizedBox(height: context.eos.spacing.lg),
          FilledButton(
            onPressed: _busy ? null : _complete,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue to Attendee Portal'),
          ),
        ],
      ),
    );
  }
}
