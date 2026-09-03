import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vendor_change_request_models.dart';
import '../../models/vendor_crm_models.dart';
import '../../providers/vendor_crm_providers.dart';
import 'change_request_comparison.dart';

/// Lists change requests for a parent vendor request (REST + SSE refresh).
class VendorChangeRequestsPanel extends ConsumerWidget {
  const VendorChangeRequestsPanel({
    super.key,
    required this.request,
    required this.role,
    this.onLight = true,
    this.dense = false,
  });

  final VendorRequest request;
  final ChangeRequestPanelRole role;
  final bool onLight;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorChangeRequestsProvider(request.id));
    final muted = onLight ? Colors.black54 : Colors.white54;
    final strong = onLight ? Colors.black87 : Colors.white;

    return async.when(
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 8 : 12),
        child: const LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Change requests unavailable: $e', style: TextStyle(color: muted, fontSize: 12)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 4 : 8),
            child: Text(
              role == ChangeRequestPanelRole.vendor
                  ? 'No change requests for this booking.'
                  : 'No change requests yet. Use “Request a Change” if you need to adjust this booking.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final change in items) ...[
              _ChangeRequestCard(
                change: change,
                role: role,
                onLight: onLight,
                strong: strong,
                muted: muted,
              ),
              SizedBox(height: dense ? 8 : 12),
            ],
          ],
        );
      },
    );
  }
}

enum ChangeRequestPanelRole { organizer, vendor }

class _ChangeRequestCard extends ConsumerStatefulWidget {
  const _ChangeRequestCard({
    required this.change,
    required this.role,
    required this.onLight,
    required this.strong,
    required this.muted,
  });

  final VendorChangeRequest change;
  final ChangeRequestPanelRole role;
  final bool onLight;
  final Color strong;
  final Color muted;

  @override
  ConsumerState<_ChangeRequestCard> createState() => _ChangeRequestCardState();
}

class _ChangeRequestCardState extends ConsumerState<_ChangeRequestCard> {
  var _busy = false;

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final change = widget.change;
    final border = widget.onLight ? Colors.black12 : Colors.white24;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  change.typeLabel,
                  style: TextStyle(color: widget.strong, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                change.statusLabel.toUpperCase(),
                style: TextStyle(
                  color: change.isPending ? Colors.orange : widget.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Requested ${_fmt(change.createdAt)}',
            style: TextStyle(color: widget.muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          ChangeRequestComparison(change: change, compact: true, onLight: widget.onLight),
          if (change.isPending) ...[
            const SizedBox(height: 10),
            if (widget.role == ChangeRequestPanelRole.vendor)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () async {
                                  await ref.read(vendorCrmApiProvider).acceptChangeRequest(change.id);
                                  refreshVendorCrm(ref);
                                },
                                'Change request accepted',
                              ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () async {
                                  await ref.read(vendorCrmApiProvider).declineChangeRequest(change.id);
                                  refreshVendorCrm(ref);
                                },
                                'Change request declined',
                              ),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () async {
                              await ref.read(vendorCrmApiProvider).cancelChangeRequest(change.id);
                              refreshVendorCrm(ref);
                            },
                            'Change request cancelled',
                          ),
                  child: const Text('Cancel change request'),
                ),
              ),
          ],
        ],
      ),
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
