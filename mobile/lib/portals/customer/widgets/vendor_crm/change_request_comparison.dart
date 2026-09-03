import 'package:flutter/material.dart';

import '../../models/vendor_change_request_models.dart';

/// CURRENT vs REQUESTED comparison for a structured change proposal.
class ChangeRequestComparison extends StatelessWidget {
  const ChangeRequestComparison({
    super.key,
    required this.change,
    this.compact = false,
    this.onLight = true,
  });

  final VendorChangeRequest change;
  final bool compact;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final muted = onLight ? Colors.black54 : Colors.white54;
    final strong = onLight ? Colors.black87 : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          change.typeLabel,
          style: TextStyle(color: strong, fontWeight: FontWeight.w700, fontSize: compact ? 13 : 14),
        ),
        const SizedBox(height: 8),
        Text('CURRENT', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(change.currentSummary, style: TextStyle(color: strong, fontSize: compact ? 12 : 13)),
        const SizedBox(height: 10),
        Text('REQUESTED', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          change.requestedSummary.isEmpty ? '—' : change.requestedSummary,
          style: TextStyle(color: strong, fontSize: compact ? 12 : 13, fontWeight: FontWeight.w600),
        ),
        if ((change.requestedPayload['requirement'] ?? '').toString().isNotEmpty &&
            change.type != 'SPECIAL_REQUIREMENT') ...[
          const SizedBox(height: 6),
          Text(
            'Note: ${change.requestedPayload['requirement']}',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Preview comparison before a change request is submitted (no REST id yet).
class ChangeRequestPreviewComparison extends StatelessWidget {
  const ChangeRequestPreviewComparison({
    super.key,
    required this.currentSummary,
    required this.requestedSummary,
    required this.typeLabel,
    this.onLight = true,
  });

  final String currentSummary;
  final String requestedSummary;
  final String typeLabel;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final muted = onLight ? Colors.black54 : Colors.white54;
    final strong = onLight ? Colors.black87 : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(typeLabel, style: TextStyle(color: strong, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('CURRENT', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(currentSummary, style: TextStyle(color: strong, fontSize: 13)),
        const SizedBox(height: 10),
        Text('REQUESTED', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(requestedSummary, style: TextStyle(color: strong, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
