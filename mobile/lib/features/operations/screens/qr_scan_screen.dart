import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../data/operations_store.dart';
import '../providers/operations_providers.dart';
import '../../organizer/providers/organizer_providers.dart';
import '../widgets/operations_shared.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final _ticketCtrl = TextEditingController();
  bool _scanning = false;

  @override
  void dispose() {
    _ticketCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastScan = ref.watch(lastQrScanProvider);

    return EosPageScaffold(
      title: 'Scan ticket',
      subtitle: 'Instant QR validation and check-in',
      body: Column(
        children: [
          EosSurfaceCard(
            elevated: true,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: context.eos.radius.card,
                    gradient: LinearGradient(
                      colors: [EosColors.plumDark.withValues(alpha: 0.9), EosColors.plum],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 64, color: Colors.white.withValues(alpha: 0.9)),
                      SizedBox(height: context.eos.spacing.sm),
                      Text(
                        _scanning ? 'Scanning…' : 'Ready to scan',
                        style: context.eosText.titleMedium?.copyWith(color: Colors.white),
                      ),
                      if (_scanning) ...[
                        SizedBox(height: context.eos.spacing.sm),
                        const EosStatusPulse(color: Colors.white, size: 10),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: context.eos.spacing.lg),
                EosTextField(
                  controller: _ticketCtrl,
                  label: 'Ticket ID',
                  hint: 'tkt_vvip_1, tkt_0, tkt_gen_0…',
                ),
                SizedBox(height: context.eos.spacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: const Icon(Icons.flash_on, size: 18),
                    label: Text(_scanning ? 'Processing…' : 'Scan now'),
                  ),
                ),
              ],
            ),
          ),
          if (lastScan != null) ...[
            SizedBox(height: context.eos.spacing.lg),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: QrScanResultPanel(key: ValueKey(lastScan.message), response: lastScan),
            ),
          ],
          SizedBox(height: context.eos.spacing.lg),
          EosSection(
            title: 'Quick test tickets',
            child: Wrap(
              spacing: context.eos.spacing.xs,
              children: [
                for (final id in ['tkt_vvip_2', 'tkt_vip_0', 'tkt_gen_5', 'tkt_0', 'tkt_invalid'])
                  ActionChip(
                    label: Text(id),
                    onPressed: () {
                      _ticketCtrl.text = id == 'tkt_invalid' ? 'bad_ticket' : id;
                      _scan();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    final ticket = _ticketCtrl.text.trim();
    if (ticket.isEmpty) return;
    setState(() => _scanning = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final response = OperationsStore.instance.scanTicket(widget.eventId, ticket);
    ref.read(lastQrScanProvider.notifier).state = response;
    bumpOperationsRevision(ref);
    bumpOrganizerRevision(ref);
    if (mounted) setState(() => _scanning = false);
  }
}
