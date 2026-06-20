import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_notifier.dart';
import '../../eos/eos.dart';
import 'finance/admin_finance_providers.dart';
import 'finance/admin_payouts_screen.dart';
import 'finance/admin_reconciliation_screen.dart';
import 'finance/admin_review_screen.dart';
import 'finance/admin_transactions_screen.dart';
import 'finance/finance_status_chip.dart';
import 'platform/compliance_audit_screen.dart';
import 'platform/event_oversight_screen.dart';
import 'platform/finance_supervision_screen.dart';
import 'platform/operations_center_screen.dart';
import 'platform/organizer_oversight_screen.dart';
import 'platform/platform_dashboard_screen.dart';
import 'platform/vendor_oversight_screen.dart';
import '../disputes/admin_disputes_screen.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  static final _destinations = EosRoleDestinations.platformAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final financeState = ref.watch(financeStateProvider);
    final shell = ref.watch(adminShellTabProvider);

    return EosAppShell(
      brandLabel: 'Owanbe',
      brandSubtitle: 'Event OS · Platform',
      destinations: _destinations,
      selectedIndex: shell.tab,
      onSelected: (v) => ref.read(adminShellTabProvider.notifier).select(v),
      topBar: _AdminTopBar(
        displayName: session?.displayName ?? 'Platform Admin',
        financeState: financeState,
        onSetState: (v) async {
          await ref.read(adminFinanceApiProvider).setFinanceState(v);
          ref.invalidate(financeStateProvider);
        },
        onSignOut: () => ref.read(authSessionProvider.notifier).signOut(),
      ),
      body: _bodyForTab(shell),
    );
  }

  Widget _bodyForTab(AdminShellState shell) => switch (shell.tab) {
        0 => const PlatformDashboardScreen(),
        1 => const OrganizerOversightScreen(),
        2 => const EventOversightScreen(),
        3 => const VendorOversightScreen(),
        4 => const OperationsCenterScreen(),
        5 => _financeBody(shell.financeSub),
        6 => const ComplianceAuditScreen(),
        _ => const PlatformDashboardScreen(),
      };

  Widget _financeBody(int? sub) => switch (sub) {
        1 => const AdminTransactionsScreen(),
        2 => const AdminPayoutsScreen(),
        3 => const AdminReviewScreen(),
        4 => const AdminReconciliationScreen(),
        5 => const AdminDisputesScreen(),
        _ => const FinanceSupervisionScreen(),
      };
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.displayName,
    required this.financeState,
    required this.onSetState,
    required this.onSignOut,
  });

  final String displayName;
  final AsyncValue<String> financeState;
  final Future<void> Function(String) onSetState;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.eosColors.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.eos.spacing.lg,
            vertical: context.eos.spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: EosSearchField(hint: 'Search organizers, events, vendors…'),
              ),
              SizedBox(width: context.eos.spacing.sm),
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
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
                        if (v != null) await onSetState(v);
                      },
                    ),
                  ],
                ),
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, st) => const Icon(Icons.error_outline),
              ),
              SizedBox(width: context.eos.spacing.sm),
              Text(displayName, style: context.eosText.titleSmall),
              IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
        ),
      ),
    );
  }
}
