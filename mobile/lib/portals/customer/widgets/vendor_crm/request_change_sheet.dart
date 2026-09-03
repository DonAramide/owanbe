import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/vendors_api.dart';
import '../../models/vendor_change_request_models.dart';
import '../../models/vendor_crm_models.dart';
import '../../providers/marketplace_providers.dart';
import '../../providers/vendor_crm_providers.dart';
import 'change_request_comparison.dart';

/// Organizer sheet: propose a structured change against an accepted booking.
Future<void> showRequestChangeSheet(
  BuildContext context, {
  required VendorRequest request,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _RequestChangeSheet(request: request),
    ),
  );
}

class _RequestChangeSheet extends ConsumerStatefulWidget {
  const _RequestChangeSheet({required this.request});

  final VendorRequest request;

  @override
  ConsumerState<_RequestChangeSheet> createState() => _RequestChangeSheetState();
}

class _RequestChangeSheetState extends ConsumerState<_RequestChangeSheet> {
  String _type = 'ADD_CAPABILITY';
  String? _capabilityKey;
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();
  final _requirementController = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  var _submitting = false;

  VendorRequest get request => widget.request;

  @override
  void initState() {
    super.initState();
    _startsAt = request.eventStartsAt ?? request.scheduledAt;
    _endsAt = request.eventEndsAt ?? request.scheduledEnd;
  }

  @override
  void dispose() {
    _venueController.dispose();
    _addressController.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  String get _currentSummary {
    final caps = request.selectedCapabilities.map((c) => c.label).join(', ');
    return [
      request.serviceLabel ?? 'Service',
      if (request.eventStartsAt != null) _fmt(request.eventStartsAt!),
      if (request.eventEndsAt != null) '– ${_fmt(request.eventEndsAt!)}',
      if ((request.venueName ?? request.eventLocation)?.isNotEmpty == true)
        request.venueName ?? request.eventLocation!,
      if (caps.isNotEmpty) 'Capabilities: $caps',
    ].join('\n');
  }

  String get _typeLabel {
    switch (_type) {
      case 'ADD_CAPABILITY':
        return 'Add capability';
      case 'REMOVE_CAPABILITY':
        return 'Remove capability';
      case 'CHANGE_DATE':
        return 'Change date';
      case 'CHANGE_TIME':
        return 'Change time';
      case 'CHANGE_VENUE':
        return 'Change venue';
      case 'SPECIAL_REQUIREMENT':
        return 'Special requirement';
      default:
        return _type;
    }
  }

  String _requestedPreview(List<ServiceCapability> vendorCaps) {
    switch (_type) {
      case 'ADD_CAPABILITY':
      case 'REMOVE_CAPABILITY':
        final match = [
          ...vendorCaps,
          ...request.selectedCapabilities.map(
            (c) => ServiceCapability(key: c.key, label: c.label),
          ),
        ].where((c) => c.key == _capabilityKey);
        final label = match.isEmpty ? (_capabilityKey ?? '—') : match.first.label;
        return _type == 'ADD_CAPABILITY' ? 'Add: $label' : 'Remove: $label';
      case 'CHANGE_DATE':
      case 'CHANGE_TIME':
        if (_startsAt == null) return 'Pick a new window';
        return [
          _fmt(_startsAt!),
          if (_endsAt != null) '– ${_fmt(_endsAt!)}',
        ].join(' ');
      case 'CHANGE_VENUE':
        return [
          _venueController.text.trim(),
          if (_addressController.text.trim().isNotEmpty) _addressController.text.trim(),
        ].where((s) => s.isNotEmpty).join('\n');
      case 'SPECIAL_REQUIREMENT':
        return _requirementController.text.trim();
      default:
        return '';
    }
  }

  Map<String, dynamic>? _buildBody() {
    switch (_type) {
      case 'ADD_CAPABILITY':
      case 'REMOVE_CAPABILITY':
        if (_capabilityKey == null || _capabilityKey!.isEmpty) return null;
        return {'type': _type, 'capabilityKey': _capabilityKey};
      case 'CHANGE_DATE':
      case 'CHANGE_TIME':
        if (_startsAt == null || _endsAt == null) return null;
        return {
          'type': _type,
          'startsAt': _startsAt!.toUtc().toIso8601String(),
          'endsAt': _endsAt!.toUtc().toIso8601String(),
        };
      case 'CHANGE_VENUE':
        final name = _venueController.text.trim();
        if (name.isEmpty) return null;
        return {
          'type': _type,
          'venueName': name,
          if (_addressController.text.trim().isNotEmpty)
            'venueAddress': _addressController.text.trim(),
        };
      case 'SPECIAL_REQUIREMENT':
        final text = _requirementController.text.trim();
        if (text.length < 3) return null;
        return {'type': _type, 'requirement': text};
      default:
        return null;
    }
  }

  Future<void> _pickWindow({required bool dateOnly}) async {
    final base = _startsAt ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null || !mounted) return;

    TimeOfDay startTod = TimeOfDay.fromDateTime(base);
    TimeOfDay endTod = TimeOfDay.fromDateTime(
      _endsAt ?? base.add(const Duration(hours: 4)),
    );
    if (!dateOnly) {
      final s = await showTimePicker(context: context, initialTime: startTod);
      if (s == null || !mounted) return;
      startTod = s;
      final e = await showTimePicker(context: context, initialTime: endTod);
      if (e == null || !mounted) return;
      endTod = e;
    }

    final start = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      startTod.hour,
      startTod.minute,
    );
    var end = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      endTod.hour,
      endTod.minute,
    );
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 4));
    }
    setState(() {
      _startsAt = start;
      _endsAt = end;
    });
  }

  Future<void> _submit() async {
    final body = _buildBody();
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete the change details before sending.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(vendorCrmApiProvider).createChangeRequest(request.id, body);
      refreshVendorCrm(ref);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Change request sent — waiting for vendor response.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<ServiceCapability> _resolveVendorCaps(List<MarketplaceVendorService> services) {
    for (final s in services) {
      if (request.vendorServiceId != null && s.id == request.vendorServiceId) {
        return s.capabilities.where((c) => c.provided && c.enabled).toList();
      }
      if (request.serviceKey != null &&
          s.serviceKey.toLowerCase() == request.serviceKey!.toLowerCase()) {
        return s.capabilities.where((c) => c.provided && c.enabled).toList();
      }
    }
    if (services.length == 1) {
      return services.first.capabilities.where((c) => c.provided && c.enabled).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(
      marketplaceVendorServicesForEventProvider((
        vendorId: request.vendorId,
        eventId: request.eventId,
      )),
    );
    final vendorCaps = servicesAsync.maybeWhen(
      data: _resolveVendorCaps,
      orElse: () => const <ServiceCapability>[],
    );

    final selectedKeys = request.selectedCapabilities.map((c) => c.key).toSet();
    final addable = vendorCaps.where((c) => !selectedKeys.contains(c.key)).toList();
    final removable = request.selectedCapabilities;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request a Change', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Proposals do not change the booking until the vendor accepts.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('What do you need?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _typeChip('Forgot something?', 'ADD_CAPABILITY'),
                _typeChip('Need to change date?', 'CHANGE_DATE'),
                _typeChip('Need to change timing?', 'CHANGE_TIME'),
                _typeChip('Need to change venue?', 'CHANGE_VENUE'),
                _typeChip('Need another requirement?', 'SPECIAL_REQUIREMENT'),
                if (removable.isNotEmpty) _typeChip('Remove a capability', 'REMOVE_CAPABILITY'),
              ],
            ),
            const SizedBox(height: 16),
            if (_type == 'ADD_CAPABILITY') ...[
              if (addable.isEmpty)
                const Text('No additional capabilities available from this vendor for this service.')
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('add-$_type-$_capabilityKey'),
                  initialValue: _capabilityKey,
                  decoration: const InputDecoration(labelText: 'Capability to add'),
                  items: [
                    for (final c in addable)
                      DropdownMenuItem(value: c.key, child: Text(c.label)),
                  ],
                  onChanged: (v) => setState(() => _capabilityKey = v),
                ),
            ],
            if (_type == 'REMOVE_CAPABILITY')
              DropdownButtonFormField<String>(
                key: ValueKey('remove-$_capabilityKey'),
                initialValue: _capabilityKey,
                decoration: const InputDecoration(labelText: 'Capability to remove'),
                items: [
                  for (final c in removable)
                    DropdownMenuItem(value: c.key, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => _capabilityKey = v),
              ),
            if (_type == 'CHANGE_DATE' || _type == 'CHANGE_TIME') ...[
              OutlinedButton.icon(
                onPressed: () => _pickWindow(dateOnly: _type == 'CHANGE_DATE'),
                icon: const Icon(Icons.event),
                label: Text(
                  _startsAt == null
                      ? 'Pick new ${_type == 'CHANGE_DATE' ? 'date' : 'date & time'}'
                      : '${_fmt(_startsAt!)}${_endsAt != null ? ' – ${_fmt(_endsAt!)}' : ''}',
                ),
              ),
            ],
            if (_type == 'CHANGE_VENUE') ...[
              TextField(
                controller: _venueController,
                decoration: const InputDecoration(labelText: 'Venue name'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address (optional)'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_type == 'SPECIAL_REQUIREMENT')
              TextField(
                controller: _requirementController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Special requirement',
                  hintText: 'Describe what you need…',
                ),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ChangeRequestPreviewComparison(
                typeLabel: _typeLabel,
                currentSummary: _currentSummary,
                requestedSummary: _requestedPreview(vendorCaps),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting || !vendorRequestAllowsChangeRequests(request.stage)
                  ? null
                  : _submit,
              child: Text(_submitting ? 'Sending…' : 'Send Change Request'),
            ),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String label, String type) {
    final selected = _type == type;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _type = type;
        _capabilityKey = null;
      }),
    );
  }

  static String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
