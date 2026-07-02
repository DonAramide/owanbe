import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/digital_asset.dart';

class AssetMetadataService {
  AssetMetadataService(this._supabase);

  final SupabaseClient? _supabase;
  final List<DigitalAsset> _cache = []; // Local cache representation

  Future<void> registerAsset(DigitalAsset asset) async {
    _cache.add(asset);
    final client = _supabase;
    if (client == null) return;
    try {
      await client.from('digital_assets').upsert(asset.toJson());
    } catch (_) {
      // Offline/Local cache fallback
    }
  }

  Future<void> updateLifecycleState(String assetId, AssetLifecycleState state) async {
    final idx = _cache.indexWhere((e) => e.id == assetId);
    if (idx != -1) {
      _cache[idx].lifecycleState = state;
    }
    final client = _supabase;
    if (client == null) return;
    try {
      await client
          .from('digital_assets')
          .update({'lifecycle_state': state.name})
          .eq('id', assetId);
    } catch (_) {}
  }

  Future<void> updateVerificationStatus(
    String assetId, {
    required String status,
    required String reviewer,
  }) async {
    final idx = _cache.indexWhere((e) => e.id == assetId);
    if (idx != -1) {
      _cache[idx].verificationStatus = status;
      _cache[idx].reviewedBy = reviewer;
      _cache[idx].reviewedAt = DateTime.now();
    }
    final client = _supabase;
    if (client == null) return;
    try {
      await client.from('digital_assets').update({
        'verification_status': status,
        'reviewed_by': reviewer,
        'reviewed_at': DateTime.now().toIso8601String(),
        'lifecycle_state': status == 'verified'
            ? AssetLifecycleState.verified.name
            : AssetLifecycleState.rejected.name,
      }).eq('id', assetId);
    } catch (_) {}
  }

  Future<List<DigitalAsset>> fetchAssets() async {
    final client = _supabase;
    if (client == null) return _cache;
    try {
      final List<dynamic> res = await client.from('digital_assets').select();
      final list = res.map((e) => DigitalAsset.fromJson(e as Map<String, dynamic>)).toList();
      _cache.clear();
      _cache.addAll(list);
      return list;
    } catch (_) {
      return _cache;
    }
  }
}
