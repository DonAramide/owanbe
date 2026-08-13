import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../models/customer_guest_models.dart';
import '../../providers/customer_guest_providers.dart';

/// Pick one/many/all guests before sending private invitations.
class SendInvitationGuestPickerSheet extends ConsumerStatefulWidget {
  const SendInvitationGuestPickerSheet({
    super.key,
    required this.eventId,
    this.templateLabel,
  });

  final String eventId;
  final String? templateLabel;

  @override
  ConsumerState<SendInvitationGuestPickerSheet> createState() =>
      _SendInvitationGuestPickerSheetState();
}

class _SendInvitationGuestPickerSheetState extends ConsumerState<SendInvitationGuestPickerSheet> {
  final _selected = <String>{};
  var _initialized = false;

  void _ensureSelection(List<CustomerGuestView> guests) {
    if (_initialized || guests.isEmpty) return;
    _initialized = true;
    // Default: select guests who still need an invite / response.
    final pending = guests
        .where(
          (g) =>
              g.rsvpStatus == GuestRsvpStatus.pending ||
              g.email.trim().isNotEmpty,
        )
        .map((g) => g.id)
        .toSet();
    _selected
      ..clear()
      ..addAll(pending.isNotEmpty ? pending : guests.map((g) => g.id));
  }

  @override
  Widget build(BuildContext context) {
    final guestsAsync = ref.watch(customerEventGuestsProvider(widget.eventId));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.eos.spacing.lg,
          context.eos.spacing.md,
          context.eos.spacing.lg,
          context.eos.spacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: guestsAsync.when(
          loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Could not load guests', style: context.eosText.titleMedium),
              SizedBox(height: context.eos.spacing.sm),
              Text('$e', style: context.eosText.bodySmall),
              SizedBox(height: context.eos.spacing.md),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
          data: (guests) {
            _ensureSelection(guests);
            final allSelected = guests.isNotEmpty && _selected.length == guests.length;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Send invitations', style: context.eosText.titleLarge),
                SizedBox(height: context.eos.spacing.xxs),
                Text(
                  widget.templateLabel == null
                      ? 'Pick who should receive this private invite.'
                      : 'Template: ${widget.templateLabel}',
                  style: context.eosText.bodySmall,
                ),
                SizedBox(height: context.eos.spacing.md),
                if (guests.isEmpty)
                  EosSurfaceCard(
                    child: Text(
                      'No guests yet. Add guests first, then come back to send.',
                      style: context.eosText.bodyMedium,
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _selected
                            ..clear()
                            ..addAll(guests.map((g) => g.id));
                        }),
                        child: const Text('Select all'),
                      ),
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      Text(
                        '${_selected.length} selected',
                        style: context.eosText.labelSmall,
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allSelected,
                    tristate: true,
                    title: const Text('All guests on this event'),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected
                          ..clear()
                          ..addAll(guests.map((g) => g.id));
                      } else {
                        _selected.clear();
                      }
                    }),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: guests.length,
                      itemBuilder: (context, index) {
                        final g = guests[index];
                        final checked = _selected.contains(g.id);
                        final rsvp = switch (g.rsvpStatus) {
                          GuestRsvpStatus.confirmed => 'Accepted',
                          GuestRsvpStatus.declined => 'Declined',
                          _ => 'Pending',
                        };
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: checked,
                          title: Text(g.name, style: context.eosText.titleSmall),
                          subtitle: Text(
                            '${g.email.isEmpty ? 'No email' : g.email} · $rsvp',
                            style: context.eosText.bodySmall,
                          ),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(g.id);
                            } else {
                              _selected.remove(g.id);
                            }
                          }),
                        );
                      },
                    ),
                  ),
                ],
                SizedBox(height: context.eos.spacing.md),
                FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    _selected.isEmpty
                        ? 'Select at least one guest'
                        : 'Send to ${_selected.length} guest${_selected.length == 1 ? '' : 's'}',
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
