import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../providers/vendor_providers.dart';

/// Live vendor calendar — reuses `VendorCalendarService` via CRM API.
class VendorCalendarScreen extends ConsumerWidget {
  const VendorCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorIdAsync = ref.watch(canonicalVendorIdProvider);

    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Schedule & Availability',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: vendorIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
          data: (vendorId) {
            final cal = ref.watch(vendorCalendarProvider(vendorId));
            final inbox = ref.watch(vendorInboxProvider(vendorId));
            return cal.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Calendar unavailable', style: context.eosText.titleMedium?.copyWith(color: Colors.white)),
                  Text('$e', style: const TextStyle(color: Colors.white70)),
                  TextButton(
                    onPressed: () {
                      refreshVendorCrm(ref);
                      ref.invalidate(vendorCalendarProvider(vendorId));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (snap) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.white.withValues(alpha: 0.04),
                    child: SwitchListTile(
                      title: const Text('Vacation mode', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text(
                        snap.vacationUntil == null
                            ? 'Pause new booking windows when enabled'
                            : 'Until ${snap.vacationUntil}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      value: snap.vacationMode,
                      onChanged: (val) async {
                        try {
                          await ref.read(vendorCrmApiProvider).patchVacation(vendorId, vacationMode: val);
                          refreshVendorCrm(ref);
                          ref.invalidate(vendorCalendarProvider(vendorId));
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('ASSIGNED EVENTS (CRM)', style: context.eosText.labelMedium?.copyWith(color: EosColors.champagne)),
                  const SizedBox(height: 8),
                  inbox.when(
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, _) => const Text('Inbox unavailable', style: TextStyle(color: Colors.white54)),
                    data: (s) {
                      final assigned = s.items
                          .where((r) => ['accepted', 'scheduled', 'arrived', 'completed'].contains(r.stage))
                          .toList();
                      if (assigned.isEmpty) {
                        return const Text('No assigned CRM jobs yet.', style: TextStyle(color: Colors.white70));
                      }
                      return Column(
                        children: [
                          for (final r in assigned)
                            Card(
                              color: Colors.white.withValues(alpha: 0.04),
                              child: ListTile(
                                leading: const Icon(Icons.event, color: EosColors.champagne),
                                title: Text(r.eventTitle ?? 'Event', style: const TextStyle(color: Colors.white)),
                                subtitle: Text(
                                  '${vendorCrmStageLabels[r.stage] ?? r.stage}'
                                  '${r.scheduledAt != null ? ' · ${r.scheduledAt}' : ''}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('AVAILABILITY & BLOCKS', style: context.eosText.labelMedium?.copyWith(color: EosColors.champagne)),
                  const SizedBox(height: 8),
                  if (snap.blocks.isEmpty)
                    const Text('No calendar blocks — availability open.', style: TextStyle(color: Colors.white70))
                  else
                    for (final b in snap.blocks)
                      Card(
                        color: Colors.white.withValues(alpha: 0.04),
                        child: ListTile(
                          leading: Icon(
                            b.kind == 'blackout' || b.kind == 'vacation' ? Icons.block : Icons.event_busy,
                            color: Colors.redAccent,
                          ),
                          title: Text(b.kind, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            '${b.reason ?? 'Blocked'}\n${b.startsAt} → ${b.endsAt}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
