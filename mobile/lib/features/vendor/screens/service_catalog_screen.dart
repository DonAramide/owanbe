import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

class ServiceCatalogScreen extends ConsumerStatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  ConsumerState<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends ConsumerState<ServiceCatalogScreen> {
  int _activeTab = 0;

  // Local state mocks for full marketplace features
  final List<Map<String, dynamic>> _customProducts = [
    {
      'id': 'prod_1',
      'name': 'Luxury Wedding Catering Package',
      'category': 'Catering',
      'priceMinor': 120000000,
      'commission': '5%',
      'stock': 12,
      'status': 'Approved',
      'visibility': 'Public',
      'seoTitle': 'Best Wedding Catering Lagos - Jollof & Co',
      'damImage': 'wedding_feast_luxury.jpg',
      'variants': ['Deluxe Buffet (₦1,200,000)', 'Standard Buffet (₦850,000)'],
      'version': 'v1.4',
    },
    {
      'id': 'prod_2',
      'name': 'Elite Sound Rig & DJ System',
      'category': 'Entertainment',
      'priceMinor': 65000000,
      'commission': '5%',
      'stock': 4,
      'status': 'Pending Approval',
      'visibility': 'Public',
      'seoTitle': 'Professional Wedding DJ Services Lagos',
      'damImage': 'dj_rig_setup.jpg',
      'variants': ['Full Outdoor Setup (₦650,000)', 'Indoor Compact (₦400,000)'],
      'version': 'v1.2',
    },
  ];

  final List<Map<String, dynamic>> _variants = [
    {
      'name': 'Deluxe Buffet Catering',
      'sku': 'CAT-DLX-01',
      'price': 1200000,
      'stock': 12,
      'status': 'Active',
      'updated': '2026-07-02',
    },
    {
      'name': 'Standard Buffet Catering',
      'sku': 'CAT-STD-02',
      'price': 850000,
      'stock': 8,
      'status': 'Active',
      'updated': '2026-07-02',
    },
  ];

  final List<String> _damGallery = ['wedding_feast_luxury.jpg', 'dj_rig_setup.jpg'];
  final List<String> _blackoutDates = ['2026-07-15', '2026-07-20'];
  final List<String> _versionHistory = [
    'v1.4 (Today) - Updated Luxury Wedding Catering Package SEO meta descriptions.',
    'v1.3 (Yesterday) - Adjusted variant prices for Deluxe Buffet.',
  ];

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _seoController = TextEditingController();

  final _varNameController = TextEditingController();
  final _varSkuController = TextEditingController();
  final _varPriceController = TextEditingController();
  final _varStockController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _seoController.dispose();
    _varNameController.dispose();
    _varSkuController.dispose();
    _varPriceController.dispose();
    _varStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      'Dashboard',
      'Products & Packages',
      'Inventory & Variants',
      'Availability Calendar',
      'Media (DAM)',
      'Bundles & Pricing',
      'Reviews & Feedback',
      'Tools & Versions',
    ];

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1333),
        cardColor: const Color(0xFF241B3F),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1333),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Marketplace Management System',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Horizontal tab switcher
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(tabs.length, (index) {
                    final isSelected = _activeTab == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(tabs[index]),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _activeTab = index),
                        selectedColor: const Color(0xFFF59E0B),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF1A1333) : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              _buildTabBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_activeTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildProductsTab();
      case 2:
        return _buildInventoryTab();
      case 3:
        return _buildCalendarTab();
      case 4:
        return _buildMediaTab();
      case 5:
        return _buildBundlesTab();
      case 6:
        return _buildReviewsTab();
      case 7:
        return _buildToolsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. Dashboard tab
  Widget _buildDashboardTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Marketplace Status', 'OPTIMAL', Icons.check_circle_outline, const Color(0xFF22C55E)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard('Platform Commission', '5% Fixed', Icons.percent, const Color(0xFFF59E0B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard('Active Items', '${_customProducts.length}', Icons.inventory_2_outlined, const Color(0xFF3B82F6)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.1),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Duplicate Detection Alert: "Elite Sound Rig & DJ System" shares similar SEO titles with an existing listing in Lagos. Modify title to improve discovery.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String val, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF241B3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. Products Tab
  Widget _buildProductsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('MARKETPLACE PRODUCT LISTINGS', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _showAddProductSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF1A1333)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final p in _customProducts)
          Card(
            color: const Color(0xFF241B3F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p['status'] == 'Approved' ? const Color(0xFF22C55E).withOpacity(0.2) : const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p['status'] as String,
                          style: TextStyle(color: p['status'] == 'Approved' ? const Color(0xFF22C55E) : const Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Category: ${p['category']} • SEO Title: ${p['seoTitle']}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  Text('DAM Image: ${p['damImage']} • Version: ${p['version']}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 12),
                  Text('Base Pricing: ₦${((p['priceMinor'] as int) / 100).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 3. Inventory & Variants
  Widget _buildInventoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('VARIANTS & STOCK LEVELS', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _showAddVariantSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Variant'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF1A1333)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF241B3F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF2F2351),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All variants loaded successfully.\nManage your product variants, inventory levels and stock availability.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              if (_variants.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_outlined, color: Colors.white30, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No variants found. Add variants to start managing your inventory.',
                          style: TextStyle(color: Colors.white30, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Variant Name', style: TextStyle(color: Color(0xFFF59E0B)))),
                      DataColumn(label: Text('SKU', style: TextStyle(color: Color(0xFFF59E0B)))),
                      DataColumn(label: Text('Price (₦)', style: TextStyle(color: Color(0xFFF59E0B)))),
                      DataColumn(label: Text('Stock', style: TextStyle(color: Color(0xFFF59E0B)))),
                      DataColumn(label: Text('Status', style: TextStyle(color: Color(0xFFF59E0B)))),
                      DataColumn(label: Text('Last Updated', style: TextStyle(color: Color(0xFFF59E0B)))),
                      DataColumn(label: Text('Actions', style: TextStyle(color: Color(0xFFF59E0B)))),
                    ],
                    rows: [
                      for (final v in _variants)
                        DataRow(
                          cells: [
                            DataCell(Text(v['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(v['sku'] as String)),
                            DataCell(Text('₦${((v['price'] as int)).toStringAsFixed(0)}')),
                            DataCell(Text('${v['stock']}')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Active', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10)),
                              ),
                            ),
                            DataCell(Text(v['updated'] as String)),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _variants.remove(v);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Calendar Tab
  Widget _buildCalendarTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BOOKING AVAILABILITY CALENDAR', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Configured Blackout Dates:', style: TextStyle(color: Colors.white70)),
        for (final d in _blackoutDates)
          ListTile(
            leading: const Icon(Icons.block, color: Colors.redAccent),
            title: Text(d),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _blackoutDates.remove(d);
                });
              },
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _blackoutDates.add('2026-07-${_blackoutDates.length + 21}');
            });
          },
          child: const Text('Add Blackout Date'),
        ),
      ],
    );
  }

  // 5. Media Tab
  Widget _buildMediaTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _damGallery.add('dam_img_${_damGallery.length + 1}.jpg');
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Media uploaded to secure DAM storage.')));
          },
          icon: const Icon(Icons.upload),
          label: const Text('Upload Image to Gallery (DAM)'),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          children: [
            for (final g in _damGallery)
              Card(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const Icon(Icons.image, size: 40),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(4),
                        width: double.infinity,
                        child: Text(g, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  // 6. Bundles Tab
  Widget _buildBundlesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: const Color(0xFF241B3F),
          child: const ListTile(
            leading: Icon(Icons.card_giftcard, color: Color(0xFFF59E0B)),
            title: Text('Wedding Gala Combo Bundle'),
            subtitle: Text('Luxury Catering + DJ System • 10% Bundle Discount'),
            trailing: Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // 7. Reviews Tab
  Widget _buildReviewsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: const Color(0xFF241B3F),
          child: const ListTile(
            leading: Icon(Icons.star, color: Colors.amber),
            title: Text('Kemi Ojo'),
            subtitle: Text('Incredible wedding feast. Everyone was happy.'),
          ),
        ),
      ],
    );
  }

  // 8. Tools Tab
  Widget _buildToolsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BULK OPERATIONS', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk CSV import completed.')));
                },
                icon: const Icon(Icons.download),
                label: const Text('Bulk Import CSV'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk JSON export completed.')));
                },
                icon: const Icon(Icons.upload),
                label: const Text('Bulk Export JSON'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('VERSION CONTROL HISTORY', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final v in _versionHistory)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(v, style: const TextStyle(color: Colors.white70, fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }

  void _showAddProductSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Marketplace Item', style: context.eosText.titleLarge),
            const SizedBox(height: 12),
            EosTextField(controller: _nameController, label: 'Name', hint: 'Party Catering Service'),
            const SizedBox(height: 8),
            EosTextField(controller: _priceController, label: 'Price (minor units)', hint: '35000000', keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            EosTextField(controller: _seoController, label: 'SEO Title Tag', hint: 'Best Lagos Party Catering'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final price = int.tryParse(_priceController.text.trim()) ?? 0;
                final seo = _seoController.text.trim();
                if (name.isEmpty || price <= 0) return;
                setState(() {
                  _customProducts.add({
                    'id': 'prod_${_customProducts.length + 1}',
                    'name': name,
                    'category': 'Catering',
                    'priceMinor': price,
                    'commission': '5%',
                    'stock': 10,
                    'status': 'Pending Approval',
                    'visibility': 'Public',
                    'seoTitle': seo,
                    'damImage': 'No image uploaded',
                    'variants': <String>[],
                    'version': 'v1.0',
                  });
                });
                _nameController.clear();
                _priceController.clear();
                _seoController.clear();
                Navigator.pop(ctx);
              },
              child: const Text('Publish Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVariantSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Variant Details', style: context.eosText.titleLarge),
            const SizedBox(height: 12),
            EosTextField(controller: _varNameController, label: 'Variant Name', hint: 'Deluxe Buffet Catering'),
            const SizedBox(height: 8),
            EosTextField(controller: _varSkuController, label: 'SKU', hint: 'CAT-DLX-01'),
            const SizedBox(height: 8),
            EosTextField(controller: _varPriceController, label: 'Price (₦)', hint: '1200000', keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            EosTextField(controller: _varStockController, label: 'Stock Amount', hint: '12', keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final name = _varNameController.text.trim();
                final sku = _varSkuController.text.trim();
                final price = int.tryParse(_varPriceController.text.trim()) ?? 0;
                final stock = int.tryParse(_varStockController.text.trim()) ?? 0;
                if (name.isEmpty || sku.isEmpty || price <= 0) return;
                setState(() {
                  _variants.add({
                    'name': name,
                    'sku': sku,
                    'price': price,
                    'stock': stock,
                    'status': 'Active',
                    'updated': '2026-07-02',
                  });
                });
                _varNameController.clear();
                _varSkuController.clear();
                _varPriceController.clear();
                _varStockController.clear();
                Navigator.pop(ctx);
              },
              child: const Text('Add Variant'),
            ),
          ],
        ),
      ),
    );
  }
}
