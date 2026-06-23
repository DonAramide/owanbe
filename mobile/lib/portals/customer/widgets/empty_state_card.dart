import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Friendly empty state for customer lists and hubs.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.celebration_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        children: [
          Icon(icon, size: 48, color: context.eosColors.primary.withValues(alpha: 0.85)),
          SizedBox(height: context.eos.spacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.eosText.bodyMedium?.copyWith(
              color: context.eosColors.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
