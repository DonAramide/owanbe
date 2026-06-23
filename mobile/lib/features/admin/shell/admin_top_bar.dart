import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../finance/finance_status_chip.dart';

class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    super.key,
    required this.displayName,
    required this.roleLabel,
    required this.environmentLabel,
    required this.financeState,
    required this.onSetFinanceState,
    required this.onSignOut,
    this.onSearch,
  });

  final String displayName;
  final String roleLabel;
  final String environmentLabel;
  final AsyncValue<String> financeState;
  final Future<void> Function(String) onSetFinanceState;
  final VoidCallback onSignOut;
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.eosColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
          boxShadow: context.eos.shadowSoft,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EosSpacing.lg, vertical: EosSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: EosSearchField(
                  hint: 'Search organizers, events, vendors…',
                  onChanged: onSearch,
                ),
              ),
              SizedBox(width: context.eos.spacing.md),
              IconButton(tooltip: 'Notifications', onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
              _EnvironmentBadge(label: environmentLabel),
              SizedBox(width: context.eos.spacing.sm),
              financeState.when(
                data: (state) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FinanceStatusChip(label: state, compact: true),
                    SizedBox(width: context.eos.spacing.xs),
                    DropdownButton<String>(
                      value: state,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('NORMAL')),
                        DropdownMenuItem(value: 'restricted', child: Text('RESTRICTED')),
                        DropdownMenuItem(value: 'frozen', child: Text('FROZEN')),
                      ],
                      onChanged: (v) async {
                        if (v != null) await onSetFinanceState(v);
                      },
                    ),
                  ],
                ),
                loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, _) => const Icon(Icons.error_outline, size: 20),
              ),
              SizedBox(width: context.eos.spacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName, style: context.eosText.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(roleLabel, style: context.eosText.labelSmall?.copyWith(color: context.eosColors.onSurfaceVariant)),
                ],
              ),
              IconButton(tooltip: 'Sign out', onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvironmentBadge extends StatelessWidget {
  const _EnvironmentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: EosColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: EosColors.warning.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: context.eosText.labelSmall?.copyWith(
          color: EosColors.warning,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
