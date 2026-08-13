import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/vendor_providers.dart';
import '../providers/vendor_intelligence_engine.dart';
import '../vendor_os_demo_mode.dart';
import '../widgets/vendor_shared.dart';
import '../widgets/vendor_empty_state.dart';

class VendorRentalsScreen extends ConsumerStatefulWidget {
  const VendorRentalsScreen({super.key});

  @override
  ConsumerState<VendorRentalsScreen> createState() => _VendorRentalsScreenState();
}

class _VendorRentalsScreenState extends ConsumerState<VendorRentalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late final List<Map<String, dynamic>> _mockInventory = VendorOsDemoMode.isEnabled
      ? [
          {
            'name': 'Chafing Dishes (Stainless Steel)',
            'type': 'Rental Asset',
            'stock': 40,
            'reserved': 10,
            'warehouse': 'Lagos Mainland Warehouse',
            'qrCode': 'QR-CHAFE-09A',
          },
          {
            'name': 'Wedding Arch (Gold Circle Metal)',
            'type': 'Rental Asset',
            'stock': 3,
            'reserved': 1,
            'warehouse': 'Lagos Island Studio',
            'qrCode': 'QR-ARCH-88B',
          },
        ]
      : <Map<String, dynamic>>[];

  late final List<Map<String, dynamic>> _mockMaintenance = VendorOsDemoMode.isEnabled
      ? [
          {'name': 'JBL Party Sound Speakers', 'issue': 'Blown tweeter replacement', 'date': '2026-07-10', 'status': 'Pending'},
        ]
      : <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EosColors.plumDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Inventory & Asset Hub', style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: EosColors.champagne,
          labelColor: EosColors.champagne,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Warehouse Stock'),
            Tab(text: 'Reservations & QR'),
            Tab(text: 'Damage & Maintenance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockTab(),
          _buildReservationsTab(),
          _buildMaintenanceTab(),
        ],
      ),
    );
  }

  Widget _buildStockTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('WAREHOUSE ASSET COUNTS', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final item in _mockInventory)
          Card(
            color: Colors.white.withOpacity(0.02),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              leading: const Icon(Icons.warehouse, color: EosColors.champagne),
              title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Warehouse: ${item['warehouse']} • Type: ${item['type']}'),
              trailing: Text('Stock: ${item['stock']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
      ],
    );
  }

  Widget _buildReservationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ACTIVE RESERVATIONS & QR TRACKING', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final item in _mockInventory)
          Card(
            color: Colors.white.withOpacity(0.02),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.white),
              title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('QR Tag: ${item['qrCode']} • Reserved: ${item['reserved']} units'),
              trailing: IconButton(
                icon: const Icon(Icons.print_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Printing barcode / QR label for ${item['qrCode']}...')));
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMaintenanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('MAINTENANCE & DAMAGE REPORTS', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final maint in _mockMaintenance)
          Card(
            color: Colors.white.withOpacity(0.02),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              leading: const Icon(Icons.build_outlined, color: Colors.amberAccent),
              title: Text(maint['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Issue: ${maint['issue']} • Deadline: ${maint['date']}'),
              trailing: Text(maint['status'] as String, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _mockMaintenance.add({
                'name': 'Chafing Dishes (Stainless Steel)',
                'issue': 'Lid weld reinforcement',
                'date': '2026-07-15',
                'status': 'Scheduled',
              });
            });
          },
          child: const Text('Log Damaged Asset'),
        ),
      ],
    );
  }
}
