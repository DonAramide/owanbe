import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../eos/eos.dart';
import '../providers/vendor_providers.dart';
import '../providers/vendor_intelligence_engine.dart';
import '../widgets/vendor_shared.dart';

class VendorWalletScreen extends ConsumerStatefulWidget {
  const VendorWalletScreen({super.key});

  @override
  ConsumerState<VendorWalletScreen> createState() => _VendorWalletScreenState();
}

class _VendorWalletScreenState extends ConsumerState<VendorWalletScreen> {
  int _activeTab = 0;

  final List<Map<String, dynamic>> _mockLedger = [
    {
      'date': '2026-07-02',
      'ref': 'TXN-90214-OR',
      'desc': 'Escrow Release - Wale & Shade Wedding',
      'amountMinor': 85000000,
      'type': 'credit',
      'feeMinor': 4250000, // 5% fee
      'taxMinor': 850000,  // 1% tax
    },
    {
      'date': '2026-06-28',
      'ref': 'TXN-88124-CR',
      'desc': 'Refund Debit - Equipment Damage Claim',
      'amountMinor': -15000000,
      'type': 'debit',
      'feeMinor': 0,
      'taxMinor': 0,
    },
  ];

  Future<void> _downloadFile() async {
    final uri = Uri.parse('https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final intel = ref.watch(vendorIntelligenceProvider);
    final tabs = [
      'Balances',
      'Ledger & Transfers',
      'Virtual Accounts',
      'Invoices & Statements',
    ];

    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Wallet & Financial Center',
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
              _buildTabBody(intel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(IntelligenceState intel) {
    switch (_activeTab) {
      case 0:
        return _buildBalancesTab(intel);
      case 1:
        return _buildLedgerTab();
      case 2:
        return _buildVirtualAccountsTab();
      case 3:
        return _buildInvoicesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBalancesTab(IntelligenceState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBalanceCard('Available Balance', state.availableBalanceMinor, Colors.greenAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBalanceCard('Locked Escrow', state.escrowBalanceMinor, Colors.amberAccent),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBalanceCard('Released Funds', state.releasedFundsMinor, Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBalanceCard('Pending Payouts', 4500000, Colors.purpleAccent),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('REVENUE & COST SPLIT (COMMERCE360)', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 12,
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: Container(color: const Color(0xFF22C55E)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(color: const Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('70% Revenue', style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('30% Cost', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(String label, int amountMinor, Color accentColor) {
    return Card(
      color: Colors.white.withOpacity(0.02),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              '₦${(amountMinor / 100).toStringAsFixed(2)}',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLedgerTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TRANSACTION LEDGER', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () {
                _downloadFile();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Financial history CSV exported.')));
              },
              icon: const Icon(Icons.file_download),
              label: const Text('Export Ledger'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final item in _mockLedger)
          Card(
            color: Colors.white.withOpacity(0.02),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              title: Text(item['desc'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              subtitle: Text('Ref: ${item['ref']} • Date: ${item['date']}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item['amountMinor'] > 0 ? "+" : ""}₦${((item['amountMinor'] as int) / 100).toStringAsFixed(2)}',
                    style: TextStyle(color: item['amountMinor'] > 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  Text('Fee: ₦${((item['feeMinor'] as int) / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.white54)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVirtualAccountsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PLATFORM VIRTUAL ACCOUNTS', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          color: Colors.white.withOpacity(0.04),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: EosColors.champagne)),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wema Bank Virtual Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                SizedBox(height: 12),
                Text('Account Number: 9901824102', style: TextStyle(fontSize: 18, letterSpacing: 1.2, color: EosColors.champagne)),
                Text('Account Name: Owanbe Pay - Jollof & Co', style: TextStyle(color: Colors.white70)),
                SizedBox(height: 8),
                Text('Use this virtual account for settlement. Funds received lock automatically into Escrow.', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab() {
    final list = [
      {'id': 'INV-2026-001', 'date': '2026-07-01', 'amt': '₦850,000.00', 'status': 'Paid'},
      {'id': 'INV-2026-002', 'date': '2026-06-25', 'amt': '₦125,000.00', 'status': 'Paid'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SETTLED CLIENT INVOICES', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final inv in list)
          Card(
            color: Colors.white.withOpacity(0.02),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: EosColors.champagne),
              title: Text(inv['id']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Date: ${inv['date']} • Status: ${inv['status']}', style: const TextStyle(color: Colors.white70)),
              trailing: Text(inv['amt']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              onTap: () {
                _downloadFile();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading invoice PDF via secure DAM Framework...')));
              },
            ),
          ),
      ],
    );
  }
}
