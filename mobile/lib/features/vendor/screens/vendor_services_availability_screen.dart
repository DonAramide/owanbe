import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/vendors_api.dart';
import '../../../eos/eos.dart';
import '../../../shared/widgets/unsaved_changes.dart';
import '../providers/vendor_inbox_integration.dart';
import '../widgets/vendor_service_capability_editor.dart';
import 'vendor_profile_edit_sheet.dart';

/// Vendor Services & Availability — existing vendor_services + CRM bookings.
class VendorServicesAvailabilityScreen extends ConsumerStatefulWidget {
  const VendorServicesAvailabilityScreen({super.key});

  @override
  ConsumerState<VendorServicesAvailabilityScreen> createState() =>
      _VendorServicesAvailabilityScreenState();
}

class _VendorServicesAvailabilityScreenState
    extends ConsumerState<VendorServicesAvailabilityScreen> {
  final _editorKey = GlobalKey<VendorServiceCapabilityEditorState>();

  @override
  void initState() {
    super.initState();
    UnsavedChangesRegistry.vendorServices = UnsavedChangesBinder(
      isDirty: () => _editorKey.currentState?.hasUnsavedChanges ?? false,
      discard: () => _editorKey.currentState?.discardLocalChanges(),
    );
  }

  @override
  void dispose() {
    if (UnsavedChangesRegistry.vendorServices != null) {
      UnsavedChangesRegistry.vendorServices = null;
    }
    super.dispose();
  }

  Future<bool> _guardLeave() {
    return UnsavedChangesRegistry.confirmLeave(
      context,
      binder: UnsavedChangesRegistry.vendorServices,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(vendorInboxSnapshotProvider);
    final dirty = _editorKey.currentState?.hasUnsavedChanges ?? false;

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _guardLeave();
        if (leave && context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/vendor');
          }
        }
      },
      // Do NOT wrap with ThemeData.dark() — that strips EosTokens and crashes
      // any widget using context.eos / EosSurfaceCard (Unexpected null value).
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              final leave = await _guardLeave();
              if (!leave || !context.mounted) return;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/vendor');
              }
            },
          ),
          title: Text(
            'Services & Availability',
            style: context.eosText.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.push('/vendor/calendar'),
              child: const Text('My Schedule', style: TextStyle(color: EosColors.champagne)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'MY SERVICES',
              style: context.eosText.labelMedium?.copyWith(color: EosColors.champagne),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toggle Available for Requests, then choose which Admin Core and Additional '
              'catalogue items you provide. Marketplace shows Admin-enabled ∩ you provide.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            VendorServiceCapabilityEditor(
              key: _editorKey,
              dark: true,
              onAddServices: () => showVendorProfileEditor(context, ref),
              onDirtyChanged: (_) {
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 24),
            Text(
              'UPCOMING BOOKINGS',
              style: context.eosText.labelMedium?.copyWith(color: EosColors.champagne),
            ),
            const SizedBox(height: 8),
            inbox.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text('$e', style: const TextStyle(color: Colors.white54)),
              data: (snap) {
                final booked = snap.items
                    .where((r) => ['accepted', 'scheduled', 'arrived', 'completed'].contains(r.stage))
                    .toList()
                  ..sort((a, b) {
                    final ad = a.eventStartsAt ?? a.scheduledAt ?? a.updatedAt;
                    final bd = b.eventStartsAt ?? b.scheduledAt ?? b.updatedAt;
                    return ad.compareTo(bd);
                  });
                if (booked.isEmpty) {
                  return const Text(
                    'No booked event windows yet. Accepted requests appear here.',
                    style: TextStyle(color: Colors.white70),
                  );
                }
                return Column(
                  children: [
                    for (final r in booked)
                      Card(
                        color: Colors.white.withValues(alpha: 0.04),
                        child: ListTile(
                          leading: const Icon(Icons.event, color: EosColors.champagne),
                          title: Text(
                            r.eventTitle ?? 'Event',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            [
                              if (r.eventStartsAt != null || r.scheduledAt != null)
                                formatDateTimeWindow(
                                  r.eventStartsAt ?? r.scheduledAt!,
                                  r.eventEndsAt ?? r.scheduledEnd,
                                ),
                              r.serviceLabel ?? 'Service',
                              'BOOKED — CONFIRMED',
                            ].join(' · '),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
