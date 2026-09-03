import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/invitation_public_api.dart';
import '../../../eos/eos.dart';
import '../../../auth/auth_notifier.dart';
import '../../attendee/providers/attendee_hub_providers.dart';

final invitationPublicApiProvider = Provider<InvitationPublicApi>((ref) => InvitationPublicApi());

/// Deep-link RSVP: `/events/:eventId/rsvp?token=…&action=accept|decline`
class EventRsvpScreen extends ConsumerStatefulWidget {
  const EventRsvpScreen({
    super.key,
    required this.eventId,
    this.token,
    this.action,
  });

  final String eventId;
  final String? token;
  /// Email CTA: `accept` or `decline` — auto-submits after token validation.
  final String? action;

  @override
  ConsumerState<EventRsvpScreen> createState() => _EventRsvpScreenState();
}

class _EventRsvpScreenState extends ConsumerState<EventRsvpScreen> {
  InvitationValidateResult? _invite;
  String? _errorReason;
  String? _errorMessage;
  var _loading = true;
  var _submitting = false;
  String? _doneStatus;
  String? _ticketCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Maps email CTA query param to existing RSVP API status values.
  static String? _statusFromAction(String? action) {
    switch (action?.trim().toLowerCase()) {
      case 'accept':
        return 'confirmed';
      case 'decline':
        return 'declined';
      default:
        return null;
    }
  }

  Future<void> _load() async {
    final token = widget.token?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _errorReason = 'invalid';
        _errorMessage = 'This invitation link is missing a token.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorReason = null;
      _errorMessage = null;
    });
    try {
      final result = await ref.read(invitationPublicApiProvider).validate(token);
      if (!mounted) return;
      if (!result.valid) {
        setState(() {
          _invite = result;
          _errorReason = result.reason ?? 'invalid';
          _errorMessage = switch (result.reason) {
            'expired' => 'This invitation has expired.',
            'cancelled' => 'This invitation was cancelled.',
            _ => 'This invitation is no longer valid.',
          };
          _loading = false;
        });
        return;
      }

      if (result.rsvpStatus == 'confirmed' || result.rsvpStatus == 'declined') {
        setState(() {
          _invite = result;
          _loading = false;
          _doneStatus = result.rsvpStatus;
        });
        return;
      }

      final autoStatus = _statusFromAction(widget.action);
      if (autoStatus != null) {
        setState(() {
          _invite = result;
          _loading = false;
        });
        await _respond(autoStatus);
        return;
      }

      setState(() {
        _invite = result;
        _loading = false;
      });
    } on InvitationPublicApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorReason = e.reason ?? e.code.toLowerCase();
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorReason = 'error';
        _errorMessage = '$e';
      });
    }
  }

  Future<void> _respond(String status) async {
    if (_submitting || _doneStatus != null) return;
    final token = widget.token?.trim() ?? '';
    if (token.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final result = await ref.read(invitationPublicApiProvider).rsvp(token: token, status: status);
      if (!mounted) return;
      setState(() {
        _doneStatus = result.rsvpStatus;
        _ticketCode = result.ticketCode;
        _submitting = false;
      });
      // Refresh invitations + ticket passes so My Events picks up the entitlement.
      invalidateAttendeePassesAfterRsvp(ref);
    } on InvitationPublicApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RSVP')),
      body: SafeArea(
        child: _loading || _submitting
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(context.eos.spacing.lg),
                child: _buildBody(context),
              ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_errorReason != null && _invite == null) {
      return EosSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _errorReason == 'expired' ? 'Invitation expired' : 'Invalid invitation',
              style: context.eosText.titleLarge,
            ),
            SizedBox(height: context.eos.spacing.sm),
            Text(_errorMessage ?? 'Unable to open this invitation.', style: context.eosText.bodyMedium),
            SizedBox(height: context.eos.spacing.md),
            OutlinedButton(onPressed: () => context.go('/'), child: const Text('Go home')),
          ],
        ),
      );
    }

    final invite = _invite!;
    final blocked = _errorReason == 'expired' ||
        _errorReason == 'cancelled' ||
        _errorReason == 'invitation_expired' ||
        _errorReason == 'invitation_cancelled';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(invite.eventTitle, style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Hi ${invite.guestName}',
          style: context.eosText.titleMedium,
        ),
        if (invite.startsAt != null || (invite.venue ?? '').isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.sm),
          Text(
            [
              if (invite.startsAt != null) invite.startsAt!.toLocal().toString().split('.').first,
              if ((invite.venue ?? '').isNotEmpty) invite.venue,
              if ((invite.city ?? '').isNotEmpty) invite.city,
            ].whereType<String>().join(' · '),
            style: context.eosText.bodyMedium,
          ),
        ],
        SizedBox(height: context.eos.spacing.lg),
        if (blocked)
          EosSurfaceCard(
            child: Text(
              _errorMessage ?? 'This invitation cannot be used.',
              style: context.eosText.bodyMedium,
            ),
          )
        else if (_doneStatus != null) ...[
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _doneStatus == 'confirmed' ? 'You’re going!' : 'RSVP declined',
                  style: context.eosText.titleLarge,
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  _doneStatus == 'confirmed'
                      ? 'Your invitation is confirmed.'
                          '${_ticketCode != null ? ' Ticket: $_ticketCode' : ' Sign in with your invitation email to see your pass in My Events.'}'
                      : 'Thanks for letting the host know.',
                  style: context.eosText.bodyMedium,
                ),
                SizedBox(height: context.eos.spacing.md),
                if (_doneStatus == 'confirmed')
                  FilledButton(
                    onPressed: () {
                      final session = ref.read(authSessionProvider);
                      if (session != null) {
                        context.go('/attendee/passes');
                      } else {
                        context.go('/auth/sign-in');
                      }
                    },
                    child: Text(ref.read(authSessionProvider) != null ? 'View my passes' : 'Sign in for your pass'),
                  ),
              ],
            ),
          ),
        ] else ...[
          EosSurfaceCard(
            child: Text(
              'Will you attend ${invite.eventTitle}?',
              style: context.eosText.titleMedium,
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          FilledButton(
            onPressed: () => _respond('confirmed'),
            child: const Text('Accept invitation'),
          ),
          SizedBox(height: context.eos.spacing.sm),
          OutlinedButton(
            onPressed: () => _respond('declined'),
            child: const Text('Decline'),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            'Maybe is not available for this invitation — please accept or decline.',
            style: context.eosText.bodySmall,
          ),
        ],
      ],
    );
  }
}
