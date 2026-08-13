import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../eos/eos.dart';
import '../providers/vendor_providers.dart';
import '../providers/vendor_intelligence_engine.dart';
import '../vendor_os_demo_mode.dart';
import '../widgets/vendor_shared.dart';
import '../widgets/vendor_empty_state.dart';

class VendorPayoutsScreen extends ConsumerStatefulWidget {
  const VendorPayoutsScreen({super.key});

  @override
  ConsumerState<VendorPayoutsScreen> createState() => _VendorPayoutsScreenState();
}

class _VendorPayoutsScreenState extends ConsumerState<VendorPayoutsScreen> {
  int _activeTab = 0;

  late final List<Map<String, dynamic>> _mockPayouts = VendorOsDemoMode.isEnabled
      ? [
          {'date': '2026-07-02', 'id': 'PAY-901', 'amountMinor': 45000000, 'status': 'Scheduled', 'bank': 'Wema Bank (****9901)'},
          {'date': '2026-06-25', 'id': 'PAY-882', 'amountMinor': 12000000, 'status': 'Released', 'bank': 'Zenith Bank (****2104)'},
          {'date': '2026-06-12', 'id': 'PAY-741', 'amountMinor': 8500000, 'status': 'Failed', 'bank': 'Access Bank (****0942)'},
        ]
      : <Map<String, dynamic>>[];

  Future<void> _downloadFile() async {
    final uri = Uri.parse('https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      'Overview & Request',
      'Settlement Calendar',
      'Payment Advice',
      'Bank & Tax Settings',
    ];

    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Enterprise Settlement Center',
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
                        selectedColor: EosColors.champagne,
                        labelStyle: TextStyle(
                          color: isSelected ? EosColors.plumDark : Colors.white,
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
        return _buildOverviewTab();
      case 1:
        return _buildCalendarTab();
      case 2:
        return _buildAdviceTab();
      case 3:
        return _buildSettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Colors.white.withOpacity(0.02),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available for Settlement: ₦0.00', style: const TextStyle(fontSize: 18, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settlement request submitted. Scheduled for next release.')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: EosColors.champagne, foregroundColor: EosColors.plumDark),
                  child: const Text('Request Payout Now'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('SETTLEMENT TIMELINE HISTORY', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_mockPayouts.isEmpty)
          const VendorEmptyState(
            message: 'No transactions yet.',
            icon: Icons.payments_outlined,
            compact: true,
          )
        else
        for (final pay in _mockPayouts)
          Card(
            color: const Color(0xFF241B3F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              leading: Icon(
                pay['status'] == 'Released'
                    ? Icons.check_circle_outlined
                    : pay['status'] == 'Scheduled'
                        ? Icons.watch_later_outlined
                        : Icons.cancel_outlined,
                color: pay['status'] == 'Released'
                    ? const Color(0xFF22C55E)
                    : pay['status'] == 'Scheduled'
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFEF4444),
              ),
              title: Text('Settlement ${pay['id']} • ${pay['bank']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Status: ${pay['status']} • Date: ${pay['date']}', style: const TextStyle(color: Colors.white70)),
              trailing: Text(
                '₦${((pay['amountMinor'] as int) / 100).toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pay['status'] == 'Failed' ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarTab() {
    return Card(
      color: Colors.white.withOpacity(0.02),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: const ListTile(
        leading: Icon(Icons.calendar_today, color: EosColors.champagne),
        title: Text('Next Scheduled Automatic Payout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('Date: July 5th, 2026 • Midnight UTC', style: TextStyle(color: Colors.white70)),
      ),
    );
  }

  Widget _buildAdviceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PAYMENT ADVICE STATEMENTS', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final pay in _mockPayouts.where((p) => p['status'] == 'Released'))
          Card(
            color: Colors.white.withOpacity(0.02),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              title: Text('Payment Advice - ${pay['id']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Export format: PDF Document', style: TextStyle(color: Colors.white70)),
              trailing: IconButton(
                icon: const Icon(Icons.download, color: EosColors.champagne),
                onPressed: () {
                  _downloadFile();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading Payment Advice statement PDF (via DAM Framework)...')));
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return Card(
      color: Colors.white.withOpacity(0.02),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KYC Settlement Verification', style: TextStyle(fontWeight: FontWeight.bold, color: EosColors.champagne)),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.verified, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text('Bank Verification Number (BVN): LINKED', style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.verified, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text('CAC Company Registration: VERIFIED', style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.verified, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text('TIN Tax Identification Number: VERIFIED', style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Edit KYC Details'),
            ),
          ],
        ),
      ),
    );
  }
}
