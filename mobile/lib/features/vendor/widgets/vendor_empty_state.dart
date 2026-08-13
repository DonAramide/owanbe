import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Reusable empty-state panel for Vendor OS sections.
class VendorEmptyState extends StatelessWidget {
  const VendorEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.compact = false,
  });

  final String message;
  final String? title;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 24, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: compact ? 28 : 40),
          SizedBox(height: compact ? 8 : 12),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: context.eosText.titleSmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: compact ? 13 : 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
