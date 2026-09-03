import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/event_config_api.dart';
import '../../../core/api/media_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../features/organizer/providers/event_config_providers.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../../../features/organizer/wizard_v2/widgets/wizard_celebrant_image_picker.dart';
import '../../../identity/experience_navigation.dart';
import '../../../shared/widgets/unsaved_changes.dart';
import '../data/event_details_patch.dart';
import '../models/customer_event_models.dart';
import '../navigation/event_navigator.dart';
import '../providers/customer_event_command_providers.dart';
import '../providers/customer_event_providers.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_friendly_errors.dart';
import '../workspace/widgets/event_loading_skeleton.dart';

/// Organizer Event Details editor at `/events/:eventId/edit`.
class CustomerEventEditScreen extends ConsumerStatefulWidget {
  const CustomerEventEditScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventEditScreen> createState() => _CustomerEventEditScreenState();
}

class _CustomerEventEditScreenState extends ConsumerState<CustomerEventEditScreen> {
  final _title = TextEditingController();
  final _tagline = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _lga = TextEditingController();
  final _guests = TextEditingController();

  DateTime _starts = DateTime.now();
  DateTime _ends = DateTime.now();
  String _category = '';
  String _categorySlug = '';
  CustomerVenueType _venueType = CustomerVenueType.physical;
  String? _imageUrl;
  Uint8List? _imageBytes;
  String? _hydratedEventId;
  Map<String, dynamic> _baseline = const {};
  var _saving = false;

  @override
  void initState() {
    super.initState();
    UnsavedChangesRegistry.eventDetails = UnsavedChangesBinder(
      isDirty: () => _isDirty,
      discard: _discard,
    );
    for (final c in [_title, _tagline, _description, _venue, _address, _city, _state, _lga, _guests]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    if (UnsavedChangesRegistry.eventDetails != null) {
      UnsavedChangesRegistry.eventDetails = null;
    }
    _title.dispose();
    _tagline.dispose();
    _description.dispose();
    _venue.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _lga.dispose();
    _guests.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  EventDetailsDraft _currentDraft() {
    return EventDetailsDraft(
      title: _title.text,
      tagline: _tagline.text,
      description: _description.text,
      category: _category,
      categorySlug: _categorySlug,
      startsAt: _starts,
      endsAt: _ends,
      venueName: _venue.text,
      venueAddress: _address.text,
      city: _city.text,
      state: _state.text,
      lga: _lga.text,
      expectedGuests: int.tryParse(_guests.text.trim()) ?? 0,
      venueType: _venueType,
      celebrantImageUrl: _imageUrl,
    );
  }

  bool get _isDirty {
    if (_hydratedEventId == null) return false;
    if (_imageBytes != null) return true;
    return !_mapEquals(_currentDraft().toPatchBody(), _baseline);
  }

  void _hydrate(CustomerEvent event) {
    _title.text = event.title;
    _tagline.text = event.tagline;
    _description.text = event.description;
    _venue.text = event.venueName.isNotEmpty ? event.venueName : event.venue;
    _address.text = event.venueAddress;
    _city.text = event.city;
    _state.text = event.state;
    _lga.text = event.lga;
    _guests.text = event.expectedGuests > 0 ? '${event.expectedGuests}' : '';
    _starts = event.startsAt.toLocal();
    _ends = event.endsAt.toLocal();
    _category = event.category;
    _categorySlug = event.categorySlug;
    _venueType = event.venueType;
    _imageUrl = event.celebrantImageUrl;
    _imageBytes = null;
    _hydratedEventId = event.id;
    _baseline = EventDetailsDraft.fromEvent(event).toPatchBody();
  }

  void _discard() {
    final event = ref.read(customerEventProvider(widget.eventId)).valueOrNull;
    if (event == null) return;
    _hydrate(event);
    setState(() {});
  }

  Future<bool> _guardLeave() {
    return UnsavedChangesRegistry.confirmLeave(
      context,
      binder: UnsavedChangesRegistry.eventDetails,
    );
  }

  Future<void> _tryLeave() async {
    final leave = await _guardLeave();
    if (!leave || !mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      ExperienceNavigation.navigateBack(context);
    }
  }

  Future<void> _save() async {
    final error = _currentDraft().validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    try {
      var imageUrl = _imageUrl;
      if (_imageBytes != null) {
        imageUrl = await _uploadImage(_imageBytes!);
      }
      final body = _currentDraft().copyWith(celebrantImageUrl: imageUrl).toPatchBody();
      final session = ref.read(authSessionProvider);
      await ref.read(customerEventsApiProvider).patchEvent(
            widget.eventId,
            body,
            session: session,
          );
      bumpCustomerEventRevision(ref);
      bumpOrganizerRevision(ref);
      refreshEventCommandCenter(ref);
      final refreshed = await ref.read(customerEventProvider(widget.eventId).future);
      if (refreshed != null) _hydrate(refreshed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event details saved')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(EventFriendlyErrors.actionFailedMessage)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _uploadImage(Uint8List bytes) async {
    final media = ref.read(mediaApiProvider);
    final presign = await media.presignUpload(
      filename: 'celebrant.jpg',
      contentType: 'image/jpeg',
      purpose: 'celebrant_image',
    );
    if (presign.uploadUrl.isEmpty || presign.publicUrl.isEmpty) {
      throw MediaApiException(code: 'INVALID_PRESIGN', message: 'Upload could not be prepared');
    }
    await media.uploadBytes(
      uploadUrl: presign.uploadUrl,
      bytes: bytes,
      contentType: 'image/jpeg',
    );
    return presign.publicUrl;
  }

  Future<void> _pickDateTime({required bool start}) async {
    final current = start ? _starts : _ends;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final next = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (start) {
        _starts = next;
      } else {
        _ends = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(customerEventProvider(widget.eventId));
    final categories = ref.watch(eventCategoriesProvider).valueOrNull ?? const <EventCategoryConfig>[];

    return eventAsync.when(
      loading: () => EventModuleScaffold(
        eventId: widget.eventId,
        title: 'Event details',
        body: const EventLoadingSkeleton(),
      ),
      error: (_, _) => EventModuleScaffold(
        eventId: widget.eventId,
        title: 'Event details',
        body: ListView(
          padding: EosResponsive.pagePaddingOf(context),
          children: [
            EventErrorView.module(
              moduleLabel: 'event details',
              onRetry: () => ref.invalidate(customerEventProvider(widget.eventId)),
              onBackToOverview: () => context.eventNav.backToOverview(widget.eventId),
            ),
          ],
        ),
      ),
      data: (event) {
        if (event == null) {
          return EventModuleScaffold(
            eventId: widget.eventId,
            title: 'Event details',
            body: const Center(child: Text('Event not found')),
          );
        }
        if (_hydratedEventId != event.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _hydrate(event));
          });
        }
        final published = event.status == CustomerEventStatus.published ||
            event.status == CustomerEventStatus.live;
        final cols = EosResponsive.formColumnsFor(context);

        return PopScope(
          canPop: !_isDirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _tryLeave();
          },
          child: EventModuleScaffold(
            eventId: widget.eventId,
            title: 'Event details',
            subtitle: 'Edit this event',
            busy: _saving,
            onBack: _tryLeave,
            footer: _SaveBar(
              dirty: _isDirty,
              saving: _saving,
              onCancel: _isDirty ? _discard : _tryLeave,
              onSave: _isDirty && !_saving ? _save : null,
            ),
            body: ListView(
              padding: EosResponsive.pagePaddingOf(context),
              children: [
                if (published)
                  EosAttentionBanner(
                    headline: 'Published event',
                    message:
                        'Changing dates or venue does not update tickets, RSVPs, vendor bookings, or payments.',
                  ),
                EosSection(
                  title: 'Basic information',
                  child: Column(
                    children: [
                      EosTextField(controller: _title, label: 'Event name'),
                      SizedBox(height: context.eos.spacing.sm),
                      EosTextField(controller: _tagline, label: 'Tagline'),
                      SizedBox(height: context.eos.spacing.sm),
                      EosTextField(controller: _description, label: 'Description', maxLines: 4),
                      SizedBox(height: context.eos.spacing.sm),
                      EosSelectField<String>(
                        label: 'Category',
                        value: _categorySlug.isNotEmpty ? _categorySlug : null,
                        hint: _category.isEmpty ? 'Select category' : _category,
                        items: [
                          for (final c in categories)
                            DropdownMenuItem(value: c.slug, child: Text(c.label)),
                        ],
                        onChanged: (slug) {
                          if (slug == null) return;
                          final match = categories.where((c) => c.slug == slug).firstOrNull;
                          setState(() {
                            _categorySlug = slug;
                            _category = match?.label ?? _category;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                EosSection(
                  title: 'Date & time',
                  subtitle: 'Times use this device’s local timezone.',
                  child: _FormRow(
                    columns: cols,
                    children: [
                      _DateTimeTile(
                        label: 'Starts',
                        value: _formatDateTime(_starts),
                        onTap: () => _pickDateTime(start: true),
                      ),
                      _DateTimeTile(
                        label: 'Ends',
                        value: _formatDateTime(_ends),
                        onTap: () => _pickDateTime(start: false),
                      ),
                    ],
                  ),
                ),
                EosSection(
                  title: 'Venue & location',
                  child: Column(
                    children: [
                      EosSelectField<CustomerVenueType>(
                        label: 'Venue type',
                        value: _venueType,
                        items: [
                          for (final t in CustomerVenueType.values)
                            DropdownMenuItem(value: t, child: Text(t.name)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _venueType = v);
                        },
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      EosTextField(controller: _venue, label: 'Venue name'),
                      SizedBox(height: context.eos.spacing.sm),
                      EosTextField(controller: _address, label: 'Address'),
                      SizedBox(height: context.eos.spacing.sm),
                      _FormRow(
                        columns: cols,
                        children: [
                          EosTextField(controller: _city, label: 'City'),
                          EosTextField(controller: _state, label: 'State / region'),
                        ],
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      EosTextField(controller: _lga, label: 'LGA'),
                      if (event.venueLatitude != null && event.venueLongitude != null) ...[
                        SizedBox(height: context.eos.spacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Map coordinates: ${event.venueLatitude}, ${event.venueLongitude}',
                            style: context.eosText.bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                EosSection(
                  title: 'Media',
                  child: WizardCelebrantImagePicker(
                    imageBytes: _imageBytes,
                    imageUrl: _imageUrl,
                    onPicked: (bytes) => setState(() => _imageBytes = bytes),
                    onClear: () => setState(() {
                      _imageBytes = null;
                      _imageUrl = '';
                    }),
                  ),
                ),
                EosSection(
                  title: 'Other details',
                  child: EosTextField(
                    controller: _guests,
                    label: 'Expected guests',
                    keyboardType: TextInputType.number,
                  ),
                ),
                EosSection(
                  title: 'Read-only',
                  subtitle: 'These values cannot be changed here.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Event ID: ${event.id}', style: context.eosText.bodySmall),
                      Text('Status: ${event.status.name}', style: context.eosText.bodySmall),
                      Text(
                        'Created: ${event.createdAt != null ? _formatDateTime(event.createdAt!.toLocal()) : 'Unavailable'}',
                        style: context.eosText.bodySmall,
                      ),
                      Text('Access: ${event.eventAccessMode.name}', style: context.eosText.bodySmall),
                    ],
                  ),
                ),
                SizedBox(height: context.eos.spacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m';
  }
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1 || children.length < 2) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: context.eos.spacing.sm),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: context.eos.spacing.sm),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value, style: context.eosText.bodyLarge),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(context.eos.spacing.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  child: Text(dirty ? 'Cancel' : 'Close'),
                ),
              ),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onSave,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
