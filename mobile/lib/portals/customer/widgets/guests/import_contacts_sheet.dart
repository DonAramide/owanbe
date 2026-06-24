import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../data/customer_guest_persistence.dart';
import '../../services/contact_import_service.dart';

class ImportContactsSheet extends ConsumerStatefulWidget {
  const ImportContactsSheet({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<ImportContactsSheet> createState() => _ImportContactsSheetState();
}

class _ImportContactsSheetState extends ConsumerState<ImportContactsSheet> {
  final _selected = <int>{};
  var _importing = false;
  var _loading = true;
  var _query = '';
  List<DeviceContact> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await loadDeviceContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  List<DeviceContact> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _import() async {
    if (_selected.isEmpty) return;
    final contacts = _selected.map((i) => _filtered[i]).toList();
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
    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Import from phone contacts', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Select contacts from your address book to invite and share celebration cards.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.md),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search name, email, or phone',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          SizedBox(height: context.eos.spacing.sm),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.eos.spacing.lg),
              child: Text(
                'No contacts found. Grant contacts permission on your device or add guests manually.',
                style: context.eosText.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else
            SizedBox(
              height: 280,
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final contact = filtered[index];
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
                    subtitle: Text(
                      [
                        if (contact.phone.isNotEmpty) contact.phone,
                        if (contact.email.isNotEmpty) contact.email,
                      ].join(' · '),
                    ),
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
