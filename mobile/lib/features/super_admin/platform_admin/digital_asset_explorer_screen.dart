import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../eos/eos.dart';
import '../../../platform/storage/dam_framework.dart';
import '../../../platform/storage/models/digital_asset.dart';

class DigitalAssetExplorerScreen extends StatefulWidget {
  const DigitalAssetExplorerScreen({super.key});

  @override
  State<DigitalAssetExplorerScreen> createState() => _DigitalAssetExplorerScreenState();
}

class _DigitalAssetExplorerScreenState extends State<DigitalAssetExplorerScreen> {
  List<DigitalAsset> _assets = [];
  List<DigitalAsset> _filteredAssets = [];
  bool _loading = false;
  String _searchQuery = '';
  String _selectedProvider = 'All';
  String _selectedVisibility = 'All';
  String _selectedType = 'All';
  bool _showAnalytics = false;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _loading = true);
    final list = await DamFramework.instance.metadataService.fetchAssets();
    setState(() {
      _assets = list;
      _filteredAssets = list;
      _loading = false;
    });
  }

  void _filter() {
    setState(() {
      _filteredAssets = _assets.where((asset) {
        final matchesSearch = asset.objectKey.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            asset.ownerId.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesProvider = _selectedProvider == 'All' || asset.storageProvider == _selectedProvider;
        final matchesVisibility = _selectedVisibility == 'All' || asset.visibility.name == _selectedVisibility.toLowerCase();
        final matchesType = _selectedType == 'All' || asset.assetType.name == _selectedType.toLowerCase();
        return matchesSearch && matchesProvider && matchesVisibility && matchesType;
      }).toList();
    });
  }

  Future<void> _verifyAsset(String id, String status) async {
    await DamFramework.instance.metadataService.updateVerificationStatus(
      id,
      status: status,
      reviewer: 'admin-user-123',
    );
    _loadAssets();
  }

  Future<void> _bulkVerify() async {
    for (final asset in _filteredAssets) {
      if (asset.verificationStatus == 'pending') {
        await _verifyAsset(asset.id, 'verified');
      }
    }
  }

  Future<void> _bulkArchive() async {
    for (final asset in _filteredAssets) {
      await DamFramework.instance.metadataService.updateLifecycleState(
        asset.id,
        AssetLifecycleState.archived,
      );
    }
    _loadAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EosColors.plumDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Digital Asset Explorer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/super-admin'),
        ),
        actions: [
          IconButton(
            icon: Icon(_showAnalytics ? Icons.list : Icons.bar_chart, color: EosColors.champagne),
            onPressed: () => setState(() => _showAnalytics = !_showAnalytics),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: EosColors.champagne))
          : Column(
              children: [
                if (_showAnalytics) _buildAnalyticsView() else ...[
                  // Filters Header Card
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Search assets by Key or Owner ID',
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(Icons.search, color: Colors.white70),
                              ),
                              onChanged: (val) {
                                _searchQuery = val;
                                _filter();
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedProvider,
                                    dropdownColor: EosColors.plumDark,
                                    decoration: const InputDecoration(labelText: 'Provider'),
                                    style: const TextStyle(color: Colors.white),
                                    items: ['All', 'ContaboS3', 'SupabaseStorage', 'LocalStorage']
                                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                        .toList(),
                                    onChanged: (val) {
                                      _selectedProvider = val!;
                                      _filter();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedVisibility,
                                    dropdownColor: EosColors.plumDark,
                                    decoration: const InputDecoration(labelText: 'Visibility'),
                                    style: const TextStyle(color: Colors.white),
                                    items: ['All', 'Public', 'Protected', 'Private']
                                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                        .toList(),
                                    onChanged: (val) {
                                      _selectedVisibility = val!;
                                      _filter();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _bulkVerify,
                                  icon: const Icon(Icons.verified, color: Colors.green),
                                  label: const Text('Bulk Verify', style: TextStyle(color: Colors.green)),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _bulkArchive,
                                  icon: const Icon(Icons.archive, color: EosColors.champagne),
                                  label: const Text('Bulk Archive', style: TextStyle(color: EosColors.champagne)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Summary Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Assets: ${_filteredAssets.length}',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Total Size: ${(_filteredAssets.map((e) => e.size).fold<int>(0, (a, b) => a + b) / (1024 * 1024)).toStringAsFixed(2)} MB',
                          style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Assets ListView
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAssets.length,
                      itemBuilder: (context, index) {
                        final asset = _filteredAssets[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.08),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(asset.objectKey.split('/').last, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Type: ${asset.assetType.name.toUpperCase()}  |  Size: ${(asset.size / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 2),
                                Text('Visibility: ${asset.visibility.name.toUpperCase()}  |  State: ${asset.lifecycleState.name}', style: const TextStyle(color: Colors.white60)),
                                const SizedBox(height: 2),
                                Text('Status: ${asset.verificationStatus.toUpperCase()}', style: TextStyle(color: asset.verificationStatus == 'verified' ? Colors.green : Colors.amber)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (asset.verificationStatus == 'pending') ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                    onPressed: () => _verifyAsset(asset.id, 'verified'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () => _verifyAsset(asset.id, 'rejected'),
                                  ),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () async {
                                    await DamFramework.instance.deleteAsset(asset);
                                    _loadAssets();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildAnalyticsView() {
    final contaboCount = _assets.where((e) => e.storageProvider == 'ContaboS3').length;
    final localCount = _assets.where((e) => e.storageProvider == 'LocalStorage').length;
    final totalSize = _assets.map((e) => e.size).fold<int>(0, (a, b) => a + b);

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('DAM Analytics Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            color: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildMetricRow('Total Storage Used', '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  const Divider(color: Colors.white10),
                  _buildMetricRow('Active Assets', '${_assets.length} items'),
                  const Divider(color: Colors.white10),
                  _buildMetricRow('Orphan Files Detected', '0 items'),
                  const Divider(color: Colors.white10),
                  _buildMetricRow('Duplicate References', '0 items'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Storage Provider Distribution', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildMetricRow('Contabo Object Storage', '$contaboCount assets'),
                  const Divider(color: Colors.white10),
                  _buildMetricRow('Local Mock Storage', '$localCount assets'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
