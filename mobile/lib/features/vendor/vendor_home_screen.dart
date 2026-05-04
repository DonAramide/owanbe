import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance/vendor_earnings_dashboard_screen.dart';
import '../disputes/vendor_disputes_screen.dart';

class VendorHomeScreen extends ConsumerWidget {
  const VendorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Vendor'),
            bottom: const TabBar(tabs: [Tab(text: 'Finance'), Tab(text: 'Disputes')]),
          ),
          body: const TabBarView(
            children: [
              VendorEarningsDashboardScreen(),
              VendorDisputesScreen(),
            ],
          ),
        ),
      );
}
