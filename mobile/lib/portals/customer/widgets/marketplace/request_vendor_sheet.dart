import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/api/vendor_availability_display.dart';
import '../../../../core/api/vendors_api.dart';
import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../workspace/widgets/event_friendly_errors.dart';
import '../../data/customer_event_persistence.dart';
import '../../providers/customer_event_providers.dart';
import '../../providers/customer_home_providers.dart';
import '../../providers/marketplace_providers.dart';
import 'vendor_availability_list.dart';

class RequestVendorSheet extends ConsumerStatefulWidget {
  const RequestVendorSheet({
    super.key,
    required this.vendor,
    this.lockedEventId,
    this.serviceCategory,
    this.serviceKey,
    this.vendorServiceId,
    this.vendorBuyerMode = false,
  });

  final MarketplaceVendor vendor;

  /// When set (Event Desktop marketplace), the request is bound to this event — no picker.
  final String? lockedEventId;

  /// Planning / marketplace category for this request (e.g. Catering, DJ).
  final String? serviceCategory;

  final String? serviceKey;
  final String? vendorServiceId;
  final bool vendorBuyerMode;

  @override
  ConsumerState<RequestVendorSheet> createState() => _RequestVendorSheetState();
}

class _RequestVendorSheetState extends ConsumerState<RequestVendorSheet> {
  String? _eventId;
  final _messageController = TextEditingController();
  var _submitting = false;
  final Set<String> _selectedCapKeys = {};

  @override
  void initState() {
    super.initState();
    final locked = widget.lockedEventId;
    if (locked != null && locked.isNotEmpty) {
      _eventId = locked;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  MarketplaceVendorService? _resolveService(List<MarketplaceVendorService> services) {
    if (widget.vendorServiceId != null && widget.vendorServiceId!.trim().isNotEmpty) {
      for (final s in services) {
        if (s.id == widget.vendorServiceId) return s;
      }
    }
    final key = widget.serviceKey?.trim();
    if (key != null && key.isNotEmpty) {
      for (final s in services) {
        if (s.serviceKey.toLowerCase() == key.toLowerCase()) return s;
      }
    }
    final label = widget.serviceCategory?.trim();
    if (label != null && label.isNotEmpty) {
      for (final s in services) {
        if (s.matchesLabel(label)) return s;
      }
    }
    if (services.length == 1) return services.first;
    return null;
  }

  Future<void> _submit(MarketplaceVendorService service) async {
    if (_eventId == null) return;
    if (serviceOfferInactive(service.offerStatus)) return;
    if (serviceWindowBlocksNewRequest(service.availabilityStatus)) return;
    setState(() => _submitting = true);
    try {
      final selected = [
        for (final c in service.capabilities)
          if (_selectedCapKeys.contains(c.key)) {'key': c.key, 'label': c.label},
      ];
      await inviteVendorToEvent(
        ref,
        _eventId!,
        widget.vendor,
        message: _messageController.text.trim(),
        serviceLabel: service.serviceName,
        serviceKey: service.serviceKey,
        vendorServiceId: service.id,
        selectedCapabilities: selected,
        vendorBuyer: widget.vendorBuyerMode,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(customerOwnedEventsProvider);
    final lockedEventId = widget.lockedEventId;
    final isEventLocked = lockedEventId != null && lockedEventId.isNotEmpty;
    final eventId = _eventId;
    final servicesAsync = eventId == null || eventId.isEmpty
        ? null
        : ref.watch(
            marketplaceVendorServicesForEventProvider((vendorId: widget.vendor.id, eventId: eventId)),
          );
    final event = eventId == null || eventId.isEmpty
        ? null
        : ref.watch(customerEventProvider(eventId)).valueOrNull;
    final services = servicesAsync?.valueOrNull ?? widget.vendor.services;
    final service = _resolveService(services);

    return Padding(
      padding: EdgeInsets.only(
        left: context.eos.spacing.lg,
        right: context.eos.spacing.lg,
        top: context.eos.spacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + context.eos.spacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              service != null ? 'Request ${service.serviceName}' : 'Request ${widget.vendor.businessName}',
              style: context.eosText.titleLarge,
            ),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              widget.vendorBuyerMode
                  ? 'You are requesting as the current vendor for the selected event. The provider sees this in their existing inbox.'
                  : 'Select requirements, then send. Dates and pricing are taken from the event.',
              style: context.eosText.bodySmall,
            ),
            SizedBox(height: context.eos.spacing.md),
            if (isEventLocked)
              _LockedEventBanner(eventId: lockedEventId)
            else
              events.when(
                data: (owned) {
                  if (owned.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create an event first to request vendors.', style: context.eosText.bodyMedium),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/events/create');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create an Event'),
                        ),
                      ],
                    );
                  }
                  _eventId ??= owned.first.id;
                  return EosSelectField<String>(
                    label: 'Celebration event',
                    value: _eventId,
                    items: [
                      for (final e in owned)
                        DropdownMenuItem(value: e.id, child: Text(e.title)),
                    ],
                    onChanged: (v) => setState(() {
                      _eventId = v;
                      _selectedCapKeys.clear();
                    }),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(EventFriendlyErrors.genericMessage),
              ),
            if (servicesAsync?.isLoading == true) ...[
              SizedBox(height: context.eos.spacing.sm),
              const LinearProgressIndicator(),
            ],
            if (service != null) ...[
              SizedBox(height: context.eos.spacing.md),
              EosSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.serviceName, style: context.eosText.titleSmall),
                    if (service.priceFromMinor != null && service.priceFromMinor! > 0)
                      Text(formatRevenue(service.priceFromMinor!), style: context.eosText.bodyMedium),
                    if (event != null) ...[
                      SizedBox(height: context.eos.spacing.xs),
                      Text('YOUR EVENT', style: context.eosText.labelSmall),
                      Text(
                        formatDateTimeWindow(event.startsAt, event.endsAt),
                        style: context.eosText.bodySmall,
                      ),
                    ],
                    if (service.availabilityStatus != null && service.availabilityStatus!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: context.eos.spacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Chip(
                              label: Text(
                                'VENDOR AVAILABILITY · ${formatServiceAvailability(service.availabilityStatus)}',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (availabilityConflictExplanation(service.availabilityStatus, service.bookedRanges) !=
                                null)
                              Padding(
                                padding: EdgeInsets.only(top: context.eos.spacing.xs),
                                child: Text(
                                  availabilityConflictExplanation(
                                    service.availabilityStatus,
                                    service.bookedRanges,
                                  )!,
                                  style: context.eosText.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    Builder(
                      builder: (context) {
                        final displayRange = organizerAvailabilityDisplayRange();
                        final rangeAsync = ref.watch(
                          marketplaceVendorServicesForRangeProvider((
                            vendorId: widget.vendor.id,
                            from: displayRange.from.toUtc().toIso8601String(),
                            to: displayRange.to.toUtc().toIso8601String(),
                          )),
                        );
                        MarketplaceVendorService? rangeService;
                        final items = rangeAsync.valueOrNull;
                        if (items != null) {
                          for (final item in items) {
                            if (item.id == service.id) {
                              rangeService = item;
                              break;
                            }
                          }
                          rangeService ??= () {
                            for (final item in items) {
                              if (item.serviceKey.toLowerCase() == service.serviceKey.toLowerCase()) {
                                return item;
                              }
                            }
                            return null;
                          }();
                        }
                        final browserRanges = rangeService?.bookedRanges ?? const <BookedRange>[];
                        final overlayRanges = rangeService?.unavailableRanges ?? const <BookedRange>[];
                        return Padding(
                          padding: EdgeInsets.only(top: context.eos.spacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (rangeAsync.isLoading)
                                const LinearProgressIndicator()
                              else
                                NextBookedSummary(
                                  bookedRanges: browserRanges,
                                ),
                              SizedBox(height: context.eos.spacing.sm),
                              OutlinedButton(
                                onPressed: rangeAsync.hasValue
                                    ? () => showVendorAvailabilitySheet(
                                          context,
                                          vendorName: widget.vendor.businessName,
                                          serviceName: service.serviceName,
                                          serviceCode: service.serviceCode,
                                          from: displayRange.from,
                                          to: displayRange.to,
                                          bookedRanges: browserRanges,
                                          unavailableRanges: overlayRanges,
                                          availabilityStatus: rangeService?.availabilityStatus,
                                        )
                                    : null,
                                child: const Text('View Availability'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (service.capabilities.isNotEmpty) ...[
                SizedBox(height: context.eos.spacing.md),
                Text('Required capabilities', style: context.eosText.titleSmall),
                Text(
                  'Only what this vendor provides is listed.',
                  style: context.eosText.bodySmall,
                ),
                for (final cap in service.capabilities)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(cap.label),
                    value: _selectedCapKeys.contains(cap.key),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedCapKeys.add(cap.key);
                      } else {
                        _selectedCapKeys.remove(cap.key);
                      }
                    }),
                  ),
              ],
              if (event != null) ...[
                SizedBox(height: context.eos.spacing.md),
                EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Review request', style: context.eosText.titleSmall),
                      Text('Vendor: ${widget.vendor.businessName}'),
                      Text('Service: ${service.serviceName}'),
                      Text('Event: ${event.title}'),
                      Text('Dates: ${formatDateTimeWindow(event.startsAt, event.endsAt)}'),
                      if (_selectedCapKeys.isNotEmpty)
                        Text(
                          'Required: ${[
                            for (final c in service.capabilities)
                              if (_selectedCapKeys.contains(c.key)) c.label,
                          ].join(', ')}',
                        ),
                    ],
                  ),
                ),
              ],
            ] else if (servicesAsync != null && servicesAsync.hasValue) ...[
              SizedBox(height: context.eos.spacing.md),
              Text(
                'Select an active service on this vendor before sending a request.',
                style: context.eosText.bodyMedium,
              ),
            ],
            SizedBox(height: context.eos.spacing.sm),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'Share guest count and vision…',
              ),
            ),
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(
              onPressed: _submitting ||
                      _eventId == null ||
                      service == null ||
                      serviceOfferInactive(service.offerStatus) ||
                      serviceWindowBlocksNewRequest(service.availabilityStatus)
                  ? null
                  : () => _submit(service),
              child: Text(
                _submitting
                    ? 'Sending…'
                    : serviceOfferInactive(service?.offerStatus)
                        ? 'Service inactive'
                        : serviceWindowBlocksNewRequest(service?.availabilityStatus)
                            ? formatServiceAvailability(service?.availabilityStatus)
                            : 'Send request',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedEventBanner extends ConsumerWidget {
  const _LockedEventBanner({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(customerEventProvider(eventId)).valueOrNull;

    return EosSurfaceCard(
      child: Row(
        children: [
          Icon(Icons.event_outlined, color: context.eosColors.primary, size: 20),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Request for this celebration', style: context.eosText.labelSmall),
                Text(
                  event?.title ?? 'Your event',
                  style: context.eosText.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event != null)
                  Text(
                    formatDateWindow(event.startsAt, event.endsAt),
                    style: context.eosText.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
