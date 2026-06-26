import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/vendors_api.dart';
import '../../../../eos/eos.dart';
import '../../../../features/organizer/data/organizer_persistence.dart';
import '../../providers/customer_home_providers.dart';

class RequestVendorSheet extends ConsumerStatefulWidget {
  const RequestVendorSheet({
    super.key,
    required this.vendor,
  });

  final MarketplaceVendor vendor;

  @override
  ConsumerState<RequestVendorSheet> createState() => _RequestVendorSheetState();
}

class _RequestVendorSheetState extends ConsumerState<RequestVendorSheet> {
  String? _eventId;
  final _messageController = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_eventId == null) return;
    setState(() => _submitting = true);
    try {
      await inviteVendor(
        ref,
        _eventId!,
        widget.vendor,
        message: _messageController.text.trim(),
        serviceLabel: widget.vendor.slug,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(customerOwnedEventsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: context.eos.spacing.lg,
        right: context.eos.spacing.lg,
        top: context.eos.spacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + context.eos.spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Request ${widget.vendor.businessName}', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Send a vendor request for your celebration.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.md),
          events.when(
            data: (owned) {
              if (owned.isEmpty) {
                return Text('Create an event first to request vendors.', style: context.eosText.bodyMedium);
              }
              _eventId ??= owned.first.id;
              return EosSelectField<String>(
                label: 'Celebration event',
                value: _eventId,
                items: [
                  for (final e in owned)
                    DropdownMenuItem(value: e.id, child: Text(e.title)),
                ],
                onChanged: (v) => setState(() => _eventId = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          SizedBox(height: context.eos.spacing.sm),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message (optional)',
              hintText: 'Share your date, guest count, and vision…',
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
          FilledButton(
            onPressed: _submitting || _eventId == null ? null : _submit,
            child: Text(_submitting ? 'Sending…' : 'Send request'),
          ),
        ],
      ),
    );
  }
}
