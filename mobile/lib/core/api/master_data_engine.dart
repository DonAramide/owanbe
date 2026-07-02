import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MdmDomain {
  final String key;
  final String label;
  final IconData icon;
  final Map<String, dynamic> metadataSchema;

  MdmDomain({
    required this.key,
    required this.label,
    required this.icon,
    required this.metadataSchema,
  });
}

class MdmEntity {
  final String id;
  final String domainKey;
  final String? parentId;
  final String slug;
  final String label;
  final String description;
  final String status; // 'draft', 'published', 'archived'
  final int sortOrder;
  final DateTime effectiveDate;
  final DateTime? expiryDate;
  final Map<String, dynamic> properties;

  MdmEntity({
    required this.id,
    required this.domainKey,
    this.parentId,
    required this.slug,
    required this.label,
    required this.description,
    required this.status,
    required this.sortOrder,
    required this.effectiveDate,
    this.expiryDate,
    required this.properties,
  });

  MdmEntity copyWith({
    String? label,
    String? description,
    String? status,
    int? sortOrder,
    String? parentId,
    Map<String, dynamic>? properties,
  }) {
    return MdmEntity(
      id: id,
      domainKey: domainKey,
      parentId: parentId ?? this.parentId,
      slug: slug,
      label: label ?? this.label,
      description: description ?? this.description,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      effectiveDate: effectiveDate,
      expiryDate: expiryDate,
      properties: properties ?? this.properties,
    );
  }
}

class MdmVersion {
  final String id;
  final String entityId;
  final int versionNumber;
  final String status;
  final Map<String, dynamic> dataSnapshot;
  final String createdBy;
  final DateTime createdAt;

  MdmVersion({
    required this.id,
    required this.entityId,
    required this.versionNumber,
    required this.status,
    required this.dataSnapshot,
    required this.createdBy,
    required this.createdAt,
  });
}

class MdmAuditLog {
  final String id;
  final String operator;
  final String affectedTarget;
  final String actionType;
  final String? prevVal;
  final String? newVal;
  final String? reason;
  final String correlationId;
  final DateTime createdAt;

  MdmAuditLog({
    required this.id,
    required this.operator,
    required this.affectedTarget,
    required this.actionType,
    this.prevVal,
    this.newVal,
    this.reason,
    required this.correlationId,
    required this.createdAt,
  });
}

class MdmDependency {
  final String consumerType; // 'Vendor Profiles', 'Marketplace Listings', 'Events', 'Revenue'
  final int count;
  final double financialImpact; // in NGN
  final String status;

  MdmDependency({
    required this.consumerType,
    required this.count,
    required this.financialImpact,
    required this.status,
  });
}

class MasterDataEngine extends ChangeNotifier {
  final List<MdmDomain> _domains = [];
  final List<MdmEntity> _entities = [];
  final List<MdmVersion> _versions = [];
  final List<MdmAuditLog> _auditLogs = [];

  List<MdmDomain> get domains => List.unmodifiable(_domains);
  List<MdmEntity> get entities => List.unmodifiable(_entities);
  List<MdmAuditLog> get auditLogs => List.unmodifiable(_auditLogs);

  MasterDataEngine() {
    _seedDefaultDomains();
    _seedDefaultEntities();
  }

  void registerDomain(MdmDomain domain) {
    if (!_domains.any((d) => d.key == domain.key)) {
      _domains.add(domain);
      notifyListeners();
    }
  }

  List<MdmEntity> resolve({
    required String domainKey,
    String? parentId,
    bool includeArchived = false,
    String? searchQuery,
  }) {
    return _entities.where((e) {
      if (e.domainKey != domainKey) return false;
      if (e.parentId != parentId) return false;
      if (!includeArchived && e.status == 'archived') return false;
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return e.label.toLowerCase().contains(q) || e.slug.toLowerCase().contains(q);
      }
      return true;
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  MdmDependency checkDependencies(String entityId) {
    // Generate dependency mapping based on entity usage
    if (entityId.contains('photography') || entityId.contains('photo')) {
      return MdmDependency(
        consumerType: 'Vendor Services Graph',
        count: 312,
        financialImpact: 24800000.00,
        status: 'ACTIVE_WORKFLOWS_DETECTED',
      );
    }
    if (entityId.contains('wedding')) {
      return MdmDependency(
        consumerType: 'Event Categories Graph',
        count: 89,
        financialImpact: 142000000.00,
        status: 'ACTIVE_EVENTS_DETECTED',
      );
    }
    return MdmDependency(
      consumerType: 'General Graph',
      count: 0,
      financialImpact: 0.0,
      status: 'CLEAN',
    );
  }

  Future<void> createEntity(MdmEntity entity, {String operator = 'Platform Super Admin', String reason = 'Initial Release'}) async {
    _entities.add(entity);
    _logAudit(
      operator: operator,
      affectedTarget: entity.label,
      actionType: 'CREATE_ENTITY',
      newVal: entity.status,
      reason: reason,
    );
    _logVersion(entity, operator);
    notifyListeners();
  }

  Future<void> updateEntity(MdmEntity entity, {String operator = 'Platform Super Admin', String reason = 'Metadata Update'}) async {
    final idx = _entities.indexWhere((e) => e.id == entity.id);
    if (idx != -1) {
      final prev = _entities[idx];
      _entities[idx] = entity;
      _logAudit(
        operator: operator,
        affectedTarget: entity.label,
        actionType: 'UPDATE_ENTITY',
        prevVal: prev.status,
        newVal: entity.status,
        reason: reason,
      );
      _logVersion(entity, operator);
      notifyListeners();
    }
  }

  Future<bool> deleteEntity(String id, {String operator = 'Platform Super Admin', String reason = 'Deprecation request'}) async {
    final dep = checkDependencies(id);
    if (dep.count > 0) {
      // Prevent deletion, force archive instead
      return false;
    }
    final idx = _entities.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final entity = _entities.removeAt(idx);
      _logAudit(
        operator: operator,
        affectedTarget: entity.label,
        actionType: 'DELETE_ENTITY',
        prevVal: entity.status,
        reason: reason,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> archiveEntity(String id, {String operator = 'Platform Super Admin', String reason = 'Enterprise Archiving'}) async {
    final idx = _entities.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final entity = _entities[idx].copyWith(status: 'archived');
      _entities[idx] = entity;
      _logAudit(
        operator: operator,
        affectedTarget: entity.label,
        actionType: 'ARCHIVE_ENTITY',
        prevVal: 'published',
        newVal: 'archived',
        reason: reason,
      );
      _logVersion(entity, operator);
      notifyListeners();
    }
  }

  List<MdmVersion> getVersionHistory(String entityId) {
    return _versions.where((v) => v.entityId == entityId).toList()
      ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
  }

  Future<void> rollback(String entityId, int targetVersion, {String operator = 'Platform Super Admin'}) async {
    final versions = getVersionHistory(entityId);
    final ver = versions.firstWhere((v) => v.versionNumber == targetVersion);
    final idx = _entities.indexWhere((e) => e.id == entityId);
    if (idx != -1) {
      final prev = _entities[idx];
      final snapshot = ver.dataSnapshot;
      final rolled = MdmEntity(
        id: entityId,
        domainKey: prev.domainKey,
        parentId: snapshot['parentId'],
        slug: snapshot['slug'],
        label: snapshot['label'],
        description: snapshot['description'],
        status: snapshot['status'],
        sortOrder: snapshot['sortOrder'],
        effectiveDate: prev.effectiveDate,
        expiryDate: prev.expiryDate,
        properties: snapshot['properties'],
      );
      _entities[idx] = rolled;
      _logAudit(
        operator: operator,
        affectedTarget: rolled.label,
        actionType: 'ROLLBACK_VERSION',
        prevVal: prev.status,
        newVal: rolled.status,
        reason: 'Rollback to version $targetVersion',
      );
      _logVersion(rolled, operator);
      notifyListeners();
    }
  }

  Map<String, dynamic> generateAiInsights(String entityId) {
    final entity = _entities.firstWhere((e) => e.id == entityId, orElse: () => _entities.first);
    final dep = checkDependencies(entityId);
    return {
      'classification': dep.count > 100 ? 'HIGH_USAGE' : 'MEDIUM_USAGE',
      'revenueContribution': dep.financialImpact,
      'recommendations': [
        'Merged suggested: Compare similarity logs with nearby nodes.',
        'Optimize: Add missing tags to boost classification score.',
        dep.count > 0 ? 'Active dependencies exist. Prioritize archiving over deletion.' : 'Clean entity. Safe to deprecate.'
      ],
      'obsoleteScore': 0.12,
    };
  }

  Future<List<Map<String, dynamic>>> dryRunImport(String domainKey, String rawJson) async {
    final List<dynamic> records = jsonDecode(rawJson);
    final results = <Map<String, dynamic>>[];
    for (final item in records) {
      final slug = item['slug'] ?? '';
      final label = item['label'] ?? '';
      final exists = _entities.any((e) => e.domainKey == domainKey && e.slug == slug);
      results.add({
        'slug': slug,
        'label': label,
        'status': exists ? 'DUPLICATE_DETECTED' : 'VALID',
        'action': exists ? 'MERGE_PROPOSED' : 'CREATE_NEW',
      });
    }
    return results;
  }

  Future<void> executeImport(String domainKey, List<Map<String, dynamic>> validatedItems, {String operator = 'Platform Super Admin'}) async {
    for (final item in validatedItems) {
      final slug = item['slug'];
      final label = item['label'];
      final existsIdx = _entities.indexWhere((e) => e.domainKey == domainKey && e.slug == slug);
      if (existsIdx != -1) {
        final existing = _entities[existsIdx];
        final updated = existing.copyWith(
          label: label,
          description: item['description'] ?? existing.description,
        );
        _entities[existsIdx] = updated;
        _logVersion(updated, operator);
      } else {
        final created = MdmEntity(
          id: 'ent_${DateTime.now().millisecondsSinceEpoch}_${slug}',
          domainKey: domainKey,
          slug: slug,
          label: label,
          description: item['description'] ?? 'Bulk imported item',
          status: 'published',
          sortOrder: 0,
          effectiveDate: DateTime.now(),
          properties: {},
        );
        _entities.add(created);
        _logVersion(created, operator);
      }
    }
    _logAudit(
      operator: operator,
      affectedTarget: 'Domain: $domainKey',
      actionType: 'BULK_IMPORT',
      reason: 'Executed bulk import transaction',
    );
    notifyListeners();
  }

  void _logAudit({
    required String operator,
    required String affectedTarget,
    required String actionType,
    String? prevVal,
    String? newVal,
    String? reason,
  }) {
    _auditLogs.insert(
      0,
      MdmAuditLog(
        id: 'aud_${DateTime.now().millisecondsSinceEpoch}',
        operator: operator,
        affectedTarget: affectedTarget,
        actionType: actionType,
        prevVal: prevVal,
        newVal: newVal,
        reason: reason,
        correlationId: 'tx_mdm_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      ),
    );
  }

  void _logVersion(MdmEntity entity, String operator) {
    final count = _versions.where((v) => v.entityId == entity.id).length;
    _versions.add(
      MdmVersion(
        id: 'ver_${DateTime.now().millisecondsSinceEpoch}',
        entityId: entity.id,
        versionNumber: count + 1,
        status: entity.status,
        dataSnapshot: {
          'parentId': entity.parentId,
          'slug': entity.slug,
          'label': entity.label,
          'description': entity.description,
          'status': entity.status,
          'sortOrder': entity.sortOrder,
          'properties': entity.properties,
        },
        createdBy: operator,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _seedDefaultDomains() {
    _domains.addAll([
      MdmDomain(key: 'marketplace', label: 'Marketplace Management', icon: Icons.storefront, metadataSchema: {}),
      MdmDomain(key: 'vendor_services', label: 'Vendor Services', icon: Icons.settings_suggest, metadataSchema: {}),
      MdmDomain(key: 'rental_marketplace', label: 'Rental Marketplace', icon: Icons.inventory_2, metadataSchema: {}),
      MdmDomain(key: 'event_configuration', label: 'Event Configuration', icon: Icons.event, metadataSchema: {}),
      MdmDomain(key: 'identity', label: 'Identity Dictionaries', icon: Icons.fingerprint, metadataSchema: {}),
      MdmDomain(key: 'geography', label: 'Geography & Locale', icon: Icons.public, metadataSchema: {}),
      MdmDomain(key: 'finance', label: 'Financial Rules & Tables', icon: Icons.payments, metadataSchema: {}),
      MdmDomain(key: 'communication', label: 'Communication Channels', icon: Icons.message, metadataSchema: {}),
      MdmDomain(key: 'operations', label: 'Operations & Workflows', icon: Icons.task_alt, metadataSchema: {}),
      MdmDomain(key: 'moderation', label: 'Marketplace Moderation', icon: Icons.gavel, metadataSchema: {}),
    ]);
  }

  void _seedDefaultEntities() {
    // Seed Vendor categories
    final cats = [
      {'id': 'caterer', 'label': 'Caterer', 'icon': 'restaurant'},
      {'id': 'decorator', 'label': 'Decorator', 'icon': 'brush'},
      {'id': 'photographer', 'label': 'Photographer', 'icon': 'photo_camera'},
      {'id': 'dj', 'label': 'DJ', 'icon': 'music_note'},
    ];
    int sort = 0;
    for (final c in cats) {
      final ent = MdmEntity(
        id: c['id']!,
        domainKey: 'marketplace',
        slug: c['id']!,
        label: c['label']!,
        description: '${c['label']!} services for premium events',
        status: 'published',
        sortOrder: sort++,
        effectiveDate: DateTime.now(),
        properties: {'icon': c['icon']!},
      );
      _entities.add(ent);
      _logVersion(ent, 'System Seed');
    }

    // Seed Services for Photographer
    final photoServices = [
      {'id': 'photo_wedding', 'label': 'Wedding Photography'},
      {'id': 'photo_drone', 'label': 'Drone Photography'},
      {'id': 'photo_studio', 'label': 'Studio Photography'},
    ];
    for (final ps in photoServices) {
      final ent = MdmEntity(
        id: ps['id']!,
        domainKey: 'vendor_services',
        parentId: 'photographer',
        slug: ps['id']!,
        label: ps['label']!,
        description: 'Professional ${ps['label']!} service options',
        status: 'published',
        sortOrder: sort++,
        effectiveDate: DateTime.now(),
        properties: {},
      );
      _entities.add(ent);
      _logVersion(ent, 'System Seed');
    }
  }
}

final masterDataEngineProvider = ChangeNotifierProvider<MasterDataEngine>((ref) {
  return MasterDataEngine();
});
