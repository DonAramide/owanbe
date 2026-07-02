import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

/// Canonical empty state for Event OS modules (Phase 42.6).
class EventEmptyState extends StatelessWidget {
  const EventEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $description',
      child: EosSurfaceCard(
        elevated: true,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.eos.spacing.sm),
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
                description,
                textAlign: TextAlign.center,
                style: context.eosText.bodyMedium?.copyWith(
                  color: context.eosColors.onSurfaceVariant,
                ),
              ),
              if (primaryActionLabel != null && onPrimaryAction != null) ...[
                SizedBox(height: context.eos.spacing.lg),
                FilledButton(onPressed: onPrimaryAction, child: Text(primaryActionLabel!)),
              ],
              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                SizedBox(height: context.eos.spacing.sm),
                OutlinedButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
