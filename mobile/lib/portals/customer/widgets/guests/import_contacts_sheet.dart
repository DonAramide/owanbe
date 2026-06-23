import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../data/customer_guest_persistence.dart';
import '../../models/customer_guest_models.dart';

class ImportContactsSheet extends ConsumerStatefulWidget {
  const ImportContactsSheet({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<ImportContactsSheet> createState() => _ImportContactsSheetState();
}

class _ImportContactsSheetState extends ConsumerState<ImportContactsSheet> {
  final _selected = <int>{};
  var _importing = false;

  Future<void> _import() async {
    if (_selected.isEmpty) return;
    final contacts = _selected.map((i) => mockImportContacts[i]).toList();
    setState(() => _importing = true);
    try {
      await importCustomerContacts(ref, widget.eventId, contacts);
      if (!mounted) return;
      Navigator.pop(context, contacts.length);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Import contacts', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Select contacts from your address book to invite.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.md),
          SizedBox(
            height: 240,
            child: ListView.builder(
              itemCount: mockImportContacts.length,
              itemBuilder: (context, index) {
                final contact = mockImportContacts[index];
                return CheckboxListTile(
                  value: _selected.contains(index),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(index);
                      } else {
                        _selected.remove(index);
                      }
                    });
                  },
                  title: Text(contact.name),
                  subtitle: Text(contact.email),
                );
              },
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          FilledButton(
            onPressed: _importing || _selected.isEmpty ? null : _import,
            child: Text(_importing ? 'Importing…' : 'Import ${_selected.length} contact(s)'),
          ),
        ],
      ),
    );
  }
}
