import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../data/customer_guest_persistence.dart';

class AddGuestSheet extends ConsumerStatefulWidget {
  const AddGuestSheet({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends ConsumerState<AddGuestSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) return;

    setState(() => _saving = true);
    try {
      await addCustomerGuest(ref, widget.eventId, name: name, email: email);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text('Add guest', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.md),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full name'),
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: context.eos.spacing.sm),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          SizedBox(height: context.eos.spacing.lg),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Adding…' : 'Add guest'),
          ),
        ],
      ),
    );
  }
}
