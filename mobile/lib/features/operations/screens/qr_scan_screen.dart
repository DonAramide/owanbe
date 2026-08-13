import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/operations_models.dart';
import '../providers/operations_providers.dart';
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
      subtitle: 'QR payload or ticket code → entitlement check-in',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EosSurfaceCard(
            elevated: true,
            child: Column(
              children: [
                Semantics(
                  label: 'Ticket scanner ready',
                  child: Container(
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
                        Icon(
                          _scanning ? Icons.hourglass_top : Icons.qr_code_scanner,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        SizedBox(height: context.eos.spacing.sm),
                        Text(
                          _scanning ? 'Validating entitlement…' : 'Ready — paste QR or enter code',
                          style: context.eosText.titleMedium?.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        if (_scanning) ...[
                          SizedBox(height: context.eos.spacing.sm),
                          const EosStatusPulse(color: Colors.white, size: 10),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.eos.spacing.lg),
                EosTextField(
                  controller: _ticketCtrl,
                  label: 'Ticket code or QR payload',
                  hint: 'INV-…, ticket code, or OWANBE:event:tier:code',
                ),
                SizedBox(height: context.eos.spacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanning ? null : _pasteClipboard,
                        icon: const Icon(Icons.content_paste, size: 18),
                        label: const Text('Paste'),
                      ),
                    ),
                    SizedBox(width: context.eos.spacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _scanning ? null : _scan,
                        icon: const Icon(Icons.verified_outlined, size: 18),
                        label: Text(_scanning ? 'Processing…' : 'Check in'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  'Camera scan packages are not bundled — paste the attendee pass QR payload or type the ticket code. Offline devices cannot admit guests.',
                  style: context.eosText.labelSmall,
                ),
              ],
            ),
          ),
          if (lastScan != null) ...[
            SizedBox(height: context.eos.spacing.lg),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: QrScanResultPanel(key: ValueKey('${lastScan.result}-${lastScan.message}'), response: lastScan),
            ),
          ],
          SizedBox(height: context.eos.spacing.lg),
          EosSection(
            title: 'Door outcomes',
            subtitle: 'Success · already checked-in · invalid · cancelled · offline',
            child: Wrap(
              spacing: context.eos.spacing.xs,
              runSpacing: context.eos.spacing.xs,
              children: [
                for (final label in [
                  'Paid ticket',
                  'Complimentary',
                  'Invitation (INV-)',
                  'Duplicate',
                  'Invalid / cancelled',
                ])
                  Chip(label: Text(label, style: context.eosText.labelSmall)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _ticketCtrl.text = text;
    await _scan();
  }

  Future<void> _scan() async {
    final ticket = _ticketCtrl.text.trim();
    if (ticket.isEmpty) {
      ref.read(lastQrScanProvider.notifier).state = const QrScanResponse(
        result: QrScanResult.invalid,
        message: 'Enter or paste a ticket code / QR payload',
      );
      return;
    }
    setState(() => _scanning = true);
    final response = await performQrCheckIn(ref, widget.eventId, ticket);
    ref.read(lastQrScanProvider.notifier).state = response;
    if (response.result == QrScanResult.valid ||
        response.result == QrScanResult.vip ||
        response.result == QrScanResult.vvip) {
      _ticketCtrl.clear();
    }
    if (mounted) setState(() => _scanning = false);
  }
}
