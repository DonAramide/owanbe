import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/identity_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owambe_logo.dart';
import '../../public/widgets/public_shell_mixin.dart';
import 'attendee_signup_screen.dart';

enum _DiscoveryStep { contact, results }

class AttendeeDiscoveryScreen extends ConsumerStatefulWidget {
  const AttendeeDiscoveryScreen({super.key});

  @override
  ConsumerState<AttendeeDiscoveryScreen> createState() => _AttendeeDiscoveryScreenState();
}

class _AttendeeDiscoveryScreenState extends ConsumerState<AttendeeDiscoveryScreen> {
  final _contact = TextEditingController();
  var _step = _DiscoveryStep.contact;
  var _busy = false;
  String? _error;
  List<TicketInvitationSummary> _invitations = const [];
  String? _resolvedEmail;
  String? _resolvedPhone;

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  bool get _isEmail => _contact.text.contains('@');

  Future<void> _lookup() async {
    final raw = _contact.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter your phone number or email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(identityApiProvider);
      final email = raw.contains('@') ? raw : null;
      final phone = raw.contains('@') ? null : raw;
      final items = await api.lookupInvitations(email: email, phone: phone);
      setState(() {
        _invitations = items;
        _resolvedEmail = email;
        _resolvedPhone = phone;
        _step = _DiscoveryStep.results;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continueToSignup() {
    context.push(
      '/attending/signup',
      extra: AttendeeSignupArgs(
        email: _resolvedEmail ?? (_isEmail ? _contact.text.trim() : null),
        phone: _resolvedPhone ?? (_isEmail ? null : _contact.text.trim()),
        invitations: _invitations,
      ),
    );
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
            constraints: const BoxConstraints(maxWidth: 520),
            child: EosSurfaceCard(
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: OwambeLogo(size: 56)),
                  SizedBox(height: context.eos.spacing.lg),
                  Text('I\'m attending an event', style: context.eosText.headlineSmall),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    'Enter the phone number or email on your invitation to find your ticket.',
                    style: context.eosText.bodyMedium,
                  ),
                  SizedBox(height: context.eos.spacing.lg),
                  if (_step == _DiscoveryStep.contact) ...[
                    EosTextField(
                      controller: _contact,
                      label: 'Phone or email',
                      hint: 'you@example.com or +234…',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_error != null) ...[
                      SizedBox(height: context.eos.spacing.sm),
                      Text(_error!, style: context.eosText.bodySmall?.copyWith(color: context.eosColors.error)),
                    ],
                    SizedBox(height: context.eos.spacing.lg),
                    FilledButton(
                      onPressed: _busy ? null : _lookup,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Find my invitation'),
                    ),
                  ],
                  if (_step == _DiscoveryStep.results) ...[
                    if (_invitations.isEmpty) ...[
                      Icon(Icons.event_busy_outlined, size: 48, color: context.eosColors.onSurfaceVariant),
                      SizedBox(height: context.eos.spacing.md),
                      Text('No event invitation found.', style: context.eosText.titleMedium),
                      SizedBox(height: context.eos.spacing.sm),
                      Text(
                        'We could not find a ticket linked to that contact.',
                        style: context.eosText.bodyMedium,
                      ),
                      SizedBox(height: context.eos.spacing.lg),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _step = _DiscoveryStep.contact;
                          _invitations = const [];
                        }),
                        child: const Text('Try another phone or email'),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      TextButton(
                        onPressed: () => context.go('/events'),
                        child: const Text('Browse public events'),
                      ),
                    ] else ...[
                      Text(
                        '${_invitations.length} invitation${_invitations.length == 1 ? '' : 's'} found',
                        style: context.eosText.titleMedium,
                      ),
                      SizedBox(height: context.eos.spacing.md),
                      ..._invitations.map((inv) => _InvitationCard(invitation: inv)),
                      SizedBox(height: context.eos.spacing.lg),
                      Text(
                        'Create your free Owambe account to unlock your attendee dashboard.',
                        style: context.eosText.bodyMedium,
                      ),
                      SizedBox(height: context.eos.spacing.md),
                      FilledButton(
                        onPressed: _continueToSignup,
                        child: const Text('Create account'),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      TextButton(
                        onPressed: () => context.push('/auth?return=/attendee'),
                        child: const Text('Already have an account? Sign in'),
                      ),
                    ],
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

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation});
  final TicketInvitationSummary invitation;

  @override
  Widget build(BuildContext context) {
    final local = invitation.startsAt.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: EosSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invitation.eventTitle, style: context.eosText.titleSmall),
            SizedBox(height: context.eos.spacing.xxs),
            Text(date, style: context.eosText.bodySmall),
            Text('Ticket: ${invitation.tierName}', style: context.eosText.bodySmall),
            if (invitation.eventVenue.isNotEmpty)
              Text(invitation.eventVenue, style: context.eosText.bodySmall),
          ],
        ),
      ),
    );
  }
}
