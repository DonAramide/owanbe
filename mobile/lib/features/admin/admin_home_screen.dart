import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_notifier.dart';
import '../admin/finance/admin_finance_dashboard_screen.dart';
import '../admin/finance/admin_finance_providers.dart';
import '../admin/finance/admin_payouts_screen.dart';
import '../admin/finance/admin_reconciliation_screen.dart';
import '../admin/finance/admin_review_screen.dart';
import '../admin/finance/admin_transactions_screen.dart';
import '../disputes/admin_disputes_screen.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _tab = 0;

  static const _tabs = [
    'Dashboard',
    'Transactions',
    'Payouts',
    'Under Review',
    'Reconciliation',
    'Disputes',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final financeState = ref.watch(financeStateProvider);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (v) => setState(() => _tab = v),
            labelType: NavigationRailLabelType.all,
            destinations: _tabs
                .map((e) => NavigationRailDestination(icon: const Icon(Icons.circle_outlined), label: Text(e)))
                .toList(),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  displayName: session?.displayName ?? 'Admin',
                  financeState: financeState,
                  onSetState: (v) async {
                    await ref.read(adminFinanceApiProvider).setFinanceState(v);
                    ref.invalidate(financeStateProvider);
                  },
                  onSignOut: () => ref.read(authSessionProvider.notifier).signOut(),
                ),
                Expanded(child: _bodyForTab(_tab)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyForTab(int index) => switch (index) {
        0 => const AdminFinanceDashboardScreen(),
        1 => const AdminTransactionsScreen(),
        2 => const AdminPayoutsScreen(),
        3 => const AdminReviewScreen(),
        4 => const AdminReconciliationScreen(),
        5 => const AdminDisputesScreen(),
        _ => const Center(child: Text('Settings coming soon')),
      };
}

class _TopBar extends StatelessWidget {
  const _TopBar({
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
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(
              child: TextField(
                decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search transactions, payout, user'),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
            const SizedBox(width: 12),
            financeState.when(
              data: (state) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _stateColor(state).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
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
              ),
              loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, st) => const Icon(Icons.error_outline),
            ),
            const SizedBox(width: 12),
            Text(displayName),
            IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
          ],
        ),
      ),
    );
  }

  Color _stateColor(String state) => switch (state) {
        'normal' => Colors.green,
        'restricted' => Colors.orange,
        'frozen' => Colors.red,
        _ => Colors.blueGrey,
      };
}
